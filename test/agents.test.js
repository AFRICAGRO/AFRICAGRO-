'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { startServer } = require('./helpers');

let t;
let db;
let agents;
test.before(async () => {
  t = await startServer();
  db = require('../src/db');
  agents = require('../src/agents');
});
test.after(async () => { await t.close(); });

async function cardBuyer(u, opts = {}) {
  const { call } = t;
  const q = await call('POST', '/fx/quote', { token: u.token, body: { from: 'XOF', to: 'USD', amount: '60', mode: 'buy' } });
  await call('POST', '/fx/execute', { token: u.token, body: { quoteId: q.body.id } });
  const c = await call('POST', '/cards', { token: u.token, body: { initialAmount: '30', pin: u.pin, ...opts } });
  const r = await call('POST', `/cards/${c.body.card.id}/reveal`, { token: u.token, body: { pin: u.pin } });
  const buy = (extra = {}) => call('POST', '/sandbox/card-authorizations', { body: { pan: r.body.pan, cvv: r.body.cvv, expMonth: r.body.expMonth,
    expYear: r.body.expYear, amount: '5', currency: 'USD', merchantName: 'Netflix', merchantCategory: 'streaming', ...extra } });
  return { cardId: c.body.card.id, buy, cvv: r.body.cvv };
}

test('consentement obligatoire : inscription refusée sans acceptation, ré-acceptation exigée après mise à jour', async () => {
  const { call, newUser } = t;
  const r = await call('POST', '/auth/register', { body: { fullName: 'Sans Consentement', email: 'nc@test.africa', country: 'CI', phone: '0102030405', password: 'MotDePasse123' } });
  assert.equal(r.status, 400);
  assert.match(r.body.error.message, /confidentialité|accepter/);

  const u = await newUser();
  const ok = await call('GET', '/wallets', { token: u.token });
  assert.equal(ok.status, 200);
  // Nouvelle version de la politique → accès bloqué jusqu'à ré-acceptation.
  db.get().prepare("UPDATE consents SET version='ancienne' WHERE user_id=? AND document='privacy'").run(u.user.id);
  const blocked = await call('GET', '/wallets', { token: u.token });
  assert.equal(blocked.status, 428);
  assert.deepEqual(blocked.body.error.details.missing, ['privacy']);
  const me = await call('GET', '/auth/me', { token: u.token });
  assert.deepEqual(me.body.missingConsents, ['privacy']);
  await call('POST', '/consents', { token: u.token, body: { documents: ['privacy'] } });
  assert.equal((await call('GET', '/wallets', { token: u.token })).status, 200);
});

test('agent de sécurité : gèle une carte victime de test CVV et prévient le titulaire', async () => {
  const { newUser, deposit, call } = t;
  const u = await newUser();
  await deposit(u.token, { amount: '100000' });
  const { cardId, buy, cvv } = await cardBuyer(u);
  const wrong = cvv === '000' ? '111' : '000';
  for (let i = 0; i < 3; i++) await buy({ cvv: wrong });
  const out = await agents.runAgent('security');
  assert.ok(out.cardsFrozen >= 1, JSON.stringify(out));
  const card = (await call('GET', `/cards/${cardId}`, { token: u.token })).body.card;
  assert.equal(card.status, 'frozen');
  const notifs = (await call('GET', '/notifications', { token: u.token })).body.notifications;
  assert.ok(notifs.some((n) => /gelée par sécurité/.test(n.title)));
  const outbox = db.get().prepare("SELECT channel FROM notification_outbox WHERE recipient IN (?,?)").all(u.user.email, u.user.phone).map((r) => r.channel);
  assert.ok(outbox.includes('sms') && outbox.includes('email'), 'alerte sécurité envoyée par SMS et e-mail');
});

test('agent de sécurité : blocage d’IP après une attaque par force brute', async () => {
  const { call, newUser } = t;
  const u = await newUser();
  for (let i = 0; i < 10; i++) await call('POST', '/auth/login', { body: { login: u.user.email, password: 'Mauvais' + i } });
  await agents.runAgent('security');
  const blocked = await call('POST', '/auth/login', { body: { login: u.user.email, password: 'MotDePasse123' } });
  assert.equal(blocked.status, 429);
  assert.equal(blocked.body.error.code, 'IP_BLOCKED');
  db.get().prepare('DELETE FROM ip_blocks').run(); // débloque pour les tests suivants
  db.get().prepare("DELETE FROM audit_logs WHERE action='auth.login_failed'").run();
  const alert = db.get().prepare("SELECT * FROM security_alerts WHERE type='brute_force'").get();
  assert.ok(alert);
});

test('agent de sécurité : alerte anti-blanchiment sur entrée/sortie rapide', async () => {
  const { newUser, deposit, call } = t;
  const u = await newUser();
  await deposit(u.token, { amount: '50000' });
  const w = await call('POST', '/withdrawals', { token: u.token, body: { country: 'CI', operator: 'ORANGE_CI', phone: '0701020304', amount: '48000', pin: u.pin } });
  assert.equal(w.status, 201);
  await agents.runAgent('security');
  assert.ok(db.get().prepare("SELECT 1 FROM security_alerts WHERE type='aml_rapid_in_out' AND user_id=?").get(u.user.id));
});

test('agent de fiabilité : auto-réparation d’un solde corrompu, mode protégé si le grand livre est déséquilibré', async () => {
  const { newUser, deposit, call } = t;
  const u = await newUser();
  await deposit(u.token, { amount: '20000' });
  const d = db.get();
  const acc = d.prepare("SELECT * FROM accounts WHERE owner_id=? AND kind='wallet'").get(u.user.id);

  // Bug simulé : le solde en cache diverge des écritures → recalculé automatiquement.
  d.prepare('UPDATE accounts SET balance=balance+999999 WHERE id=?').run(acc.id);
  let out = await agents.runAgent('reliability');
  assert.equal(out.balancesRepaired, 1);
  assert.equal(d.prepare('SELECT balance FROM accounts WHERE id=?').get(acc.id).balance, acc.balance);

  // Écriture déséquilibrée → mode protégé : plus aucun mouvement de fonds.
  const txId = d.prepare('SELECT transaction_id FROM ledger_entries WHERE account_id=? LIMIT 1').get(acc.id).transaction_id;
  d.prepare('INSERT INTO ledger_entries (transaction_id, account_id, amount, currency, balance_after) VALUES (?,?,?,?,?)').run(txId, acc.id, 5, 'XOF', 0);
  out = await agents.runAgent('reliability');
  assert.equal(out.lockEngaged, true);
  const dep = await call('POST', '/deposits', { token: u.token, body: { country: 'CI', operator: 'ORANGE_CI', phone: '0701020304', amount: '1000' } });
  assert.equal(dep.status, 503);
  assert.ok(d.prepare("SELECT 1 FROM security_alerts WHERE type='ledger_anomaly' AND severity='critical'").get());

  // Correction, puis levée du mode protégé par un administrateur.
  d.prepare('DELETE FROM ledger_entries WHERE amount=5 AND account_id=? AND balance_after=0').run(acc.id);
  d.prepare("UPDATE users SET role='admin' WHERE id=?").run(u.user.id);
  const clear = await call('POST', '/admin/financial-lock/clear', { token: u.token, body: { reason: 'Écriture parasite supprimée après enquête' } });
  assert.equal(clear.status, 200);
  const ok = await call('POST', '/deposits', { token: u.token, body: { country: 'CI', operator: 'ORANGE_CI', phone: '0701020304', amount: '1000' } });
  assert.equal(ok.status, 201);
  d.prepare("UPDATE users SET role='user' WHERE id=?").run(u.user.id);
});

test('agent de fiabilité : expire les dépôts bloqués et détecte les pics d’erreurs', async () => {
  const { newUser, call } = t;
  const u = await newUser();
  const dep = await call('POST', '/deposits', { token: u.token, body: { country: 'CI', operator: 'MTN_CI', phone: '0501020304', amount: '5000' } });
  const d = db.get();
  d.prepare("UPDATE mobile_money_ops SET created_at='2020-01-01T00:00:00.000Z' WHERE id=?").run(dep.body.id);
  const system = require('../src/services/system');
  for (let i = 0; i < 5; i++) system.recordError(new Error('Bug de test répété'), 'GET /test');
  const out = await agents.runAgent('reliability');
  assert.ok(out.depositsResolved >= 1);
  assert.equal(d.prepare('SELECT status FROM mobile_money_ops WHERE id=?').get(dep.body.id).status, 'failed');
  assert.ok(out.errorAlerts >= 1);
});

test('agent de notifications : envoi de la file avec relance en cas d’échec', async () => {
  const d = db.get();
  const before = d.prepare("SELECT COUNT(*) AS n FROM notification_outbox WHERE status='pending'").get().n;
  assert.ok(before > 0);
  let out = await agents.runAgent('notification');
  assert.ok(out.sent >= before, JSON.stringify(out));
  // Échec d'envoi (canal invalide simulant un fournisseur en panne) → relance programmée.
  const { enqueue } = require('../src/services/notify');
  enqueue('sms', '+2250700000000', null, 'test');
  d.prepare("UPDATE notification_outbox SET channel='pigeon' WHERE status='pending'").run();
  out = await agents.runAgent('notification');
  assert.ok(out.failed >= 1);
  const row = d.prepare("SELECT * FROM notification_outbox WHERE channel='pigeon'").get();
  assert.equal(row.status, 'pending');
  assert.equal(row.attempts, 1);
  assert.ok(row.next_attempt_at > db.now());
  const status = agents.status();
  assert.equal(status.length, 3);
});

test('mot de passe oublié : code à usage unique, sessions révoquées', async () => {
  const { call, newUser } = t;
  const u = await newUser();
  const unknown = await call('POST', '/auth/password/forgot', { body: { login: 'inconnu@test.africa' } });
  assert.equal(unknown.status, 200);
  assert.equal(unknown.body.devCode, undefined);
  const f = await call('POST', '/auth/password/forgot', { body: { login: u.user.email } });
  assert.match(f.body.devCode, /^\d{6}$/);
  const bad = await call('POST', '/auth/password/reset', { body: { login: u.user.email, code: '000000', newPassword: 'NouveauPass456' } });
  assert.equal(bad.status, 400);
  const ok = await call('POST', '/auth/password/reset', { body: { login: u.user.email, code: f.body.devCode, newPassword: 'NouveauPass456' } });
  assert.equal(ok.status, 200);
  const reuse = await call('POST', '/auth/password/reset', { body: { login: u.user.email, code: f.body.devCode, newPassword: 'AutrePass789' } });
  assert.equal(reuse.status, 400);
  assert.equal((await call('POST', '/auth/refresh', { cookie: u.cookie })).status, 401);
  assert.equal((await call('POST', '/auth/login', { body: { login: u.user.email, password: 'NouveauPass456' } })).status, 200);
});

test('données personnelles : export, réclamation, clôture et anonymisation', async () => {
  const { call, newUser, deposit } = t;
  const u = await newUser();
  await deposit(u.token, { amount: '10000' });
  const tk = await call('POST', '/support/tickets', { token: u.token, body: { category: 'reclamation', subject: 'Frais contestés', message: 'Je conteste les frais de mon dernier dépôt.' } });
  assert.equal(tk.status, 201);

  const exp = await call('GET', '/privacy/export', { token: u.token });
  assert.equal(exp.status, 200);
  assert.equal(exp.body.profile.email, u.user.email);
  assert.ok(exp.body.consents.length >= 2);
  assert.match(exp.body.kyc[0].id_number, /^•+3456$/);
  assert.equal(exp.body.supportTickets.length, 1);

  const pref = await call('PATCH', '/privacy/preferences', { token: u.token, body: { notifySms: false, marketingOptIn: true } });
  assert.equal(pref.body.user.notifySms, false);
  assert.equal(pref.body.user.marketingOptIn, true);

  const refused = await call('POST', '/privacy/close-account', { token: u.token, body: { password: 'MotDePasse123', pin: u.pin } });
  assert.equal(refused.status, 409, 'solde non nul');
  await call('POST', '/withdrawals', { token: u.token, body: { country: 'CI', operator: 'ORANGE_CI', phone: '0701020304', amount: '9900', pin: u.pin } });
  const closed = await call('POST', '/privacy/close-account', { token: u.token, body: { password: 'MotDePasse123', pin: u.pin } });
  assert.equal(closed.status, 200, JSON.stringify(closed.body));
  const row = db.get().prepare('SELECT * FROM users WHERE id=?').get(u.user.id);
  assert.equal(row.status, 'closed');
  assert.match(row.email, /africard\.invalid$/);
  assert.equal(row.full_name, 'Compte clôturé');
  assert.ok(db.get().prepare('SELECT COUNT(*) AS n FROM transactions WHERE user_id=?').get(u.user.id).n > 0, 'historique financier conservé (LBC/FT)');
  assert.equal((await call('GET', '/wallets', { token: u.token })).status, 401);
});
