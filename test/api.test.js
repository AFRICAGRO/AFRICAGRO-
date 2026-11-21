'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { startServer } = require('./helpers');

let t;
test.before(async () => { t = await startServer(); });
test.after(async () => { await t.close(); });

test('inscription, connexion, rotation de session et détection de réutilisation', async () => {
  const { call } = t;
  const weak = await call('POST', '/auth/register', { body: { fullName: 'Awa Koné', email: 'awa@test.africa', country: 'CI', phone: '0505050505', password: 'faible' } });
  assert.equal(weak.status, 400);

  const r = await call('POST', '/auth/register', { body: { fullName: 'Awa Koné', email: 'awa@test.africa', country: 'CI', phone: '0505050505', password: 'MotDePasse123' } });
  assert.equal(r.status, 201);
  assert.equal(r.body.user.phone, '+2250505050505');

  const dup = await call('POST', '/auth/register', { body: { fullName: 'Awa', email: 'autre@test.africa', country: 'CI', phone: '+225 05 05 05 05 05', password: 'MotDePasse123' } });
  assert.equal(dup.status, 409);

  const bad = await call('POST', '/auth/login', { body: { login: 'awa@test.africa', password: 'mauvais' } });
  assert.equal(bad.status, 401);

  const byPhone = await call('POST', '/auth/login', { body: { login: '0505050505', country: 'CI', password: 'MotDePasse123' } });
  assert.equal(byPhone.status, 200);
  const cookie1 = byPhone.headers.get('set-cookie').split(';')[0];
  assert.match(byPhone.headers.get('set-cookie'), /HttpOnly/i);

  const ref = await call('POST', '/auth/refresh', { cookie: cookie1 });
  assert.equal(ref.status, 200);
  const cookie2 = ref.headers.get('set-cookie').split(';')[0];

  // Réutiliser l'ancien jeton révoque toute la famille, y compris le nouveau.
  const reuse = await call('POST', '/auth/refresh', { cookie: cookie1 });
  assert.equal(reuse.status, 401);
  const after = await call('POST', '/auth/refresh', { cookie: cookie2 });
  assert.equal(after.status, 401);

  const unauth = await call('GET', '/wallets');
  assert.equal(unauth.status, 401);
});

test('dépôt Orange Money → conversion USD → carte virtuelle → achat Netflix', async () => {
  const { call, newUser, deposit } = t;
  const u = await newUser();

  const prev = await call('POST', '/deposits/preview', { token: u.token, body: { country: 'CI', operator: 'ORANGE_CI', phone: '0701020304', amount: '100000' } });
  assert.equal(prev.body.fee, '1000');
  assert.equal(prev.body.net, '99000');

  const op = await deposit(u.token, { amount: '100000' });
  assert.equal(op.status, 'completed');
  let w = await call('GET', '/wallets', { token: u.token });
  assert.equal(w.body.wallets.find((x) => x.currency === 'XOF').balance, '99000');

  const q = await call('POST', '/fx/quote', { token: u.token, body: { from: 'XOF', to: 'USD', amount: '60000' } });
  assert.equal(q.status, 200);
  assert.ok(Number(q.body.toAmount) > 95 && Number(q.body.toAmount) < 100, q.body.toAmount);
  const ex = await call('POST', '/fx/execute', { token: u.token, body: { quoteId: q.body.id } });
  assert.equal(ex.status, 200);
  const again = await call('POST', '/fx/execute', { token: u.token, body: { quoteId: q.body.id } });
  assert.equal(again.status, 409, 'une cotation ne peut servir qu’une fois');

  const noPin = await call('POST', '/cards', { token: u.token, body: { label: 'Abonnements', currency: 'USD' } });
  assert.equal(noPin.status, 403);
  const c = await call('POST', '/cards', { token: u.token, body: { label: 'Abonnements', currency: 'USD', brand: 'visa', initialAmount: '50', pin: u.pin } });
  assert.equal(c.status, 201, JSON.stringify(c.body));
  assert.equal(c.body.card.balance, '50.00');
  const cardId = c.body.card.id;

  const rev = await call('POST', `/cards/${cardId}/reveal`, { token: u.token, body: { pin: u.pin } });
  assert.equal(rev.status, 200);
  const pan = rev.body.pan.replace(/\s/g, '');
  assert.equal(pan.slice(-4), c.body.card.last4);

  const buy = (extra = {}) => call('POST', '/sandbox/card-authorizations', { body: {
    pan, cvv: rev.body.cvv, expMonth: rev.body.expMonth, expYear: rev.body.expYear,
    amount: '15.49', currency: 'USD', merchantName: 'Netflix', merchantCategory: 'streaming', merchantCountry: 'US', ...extra } });

  const ok = await buy();
  assert.equal(ok.body.approved, true, JSON.stringify(ok.body));
  let card = (await call('GET', `/cards/${cardId}`, { token: u.token })).body.card;
  assert.equal(card.balance, '34.51');

  const badCvv = await buy({ cvv: rev.body.cvv === '000' ? '111' : '000' });
  assert.equal(badCvv.body.approved, false);
  assert.match(badCvv.body.reason, /CVV/);

  const gambling = await buy({ merchantName: 'BetPlus', merchantCategory: 'gambling' });
  assert.equal(gambling.body.approved, false);

  // Achat en euros sur une carte USD → conversion + frais transfrontaliers
  const eur = await buy({ amount: '10', currency: 'EUR', merchantName: 'Canva', merchantCategory: 'software', merchantCountry: 'FR' });
  assert.equal(eur.body.approved, true);
  assert.equal(eur.body.billedCurrency, 'USD');
  assert.ok(Number(eur.body.billedAmount) > 10.8);

  const tooMuch = await buy({ amount: '500' });
  assert.equal(tooMuch.body.approved, false);
  assert.match(tooMuch.body.reason, /insuffisant/);

  await call('POST', `/cards/${cardId}/freeze`, { token: u.token });
  const frozen = await buy();
  assert.equal(frozen.body.approved, false);
  assert.match(frozen.body.reason, /gelée/);
  const unf = await call('POST', `/cards/${cardId}/unfreeze`, { token: u.token, body: { pin: u.pin } });
  assert.equal(unf.body.card.status, 'active');

  // Remboursement marchand
  const ref = await call('POST', `/sandbox/card-authorizations/${ok.body.authorizationId}/refund`, {});
  assert.equal(ref.body.ok, true);
  card = (await call('GET', `/cards/${cardId}`, { token: u.token })).body.card;
  assert.ok(Number(card.balance) > 34.51);

  // Résiliation : le solde retourne au portefeuille USD
  const term = await call('POST', `/cards/${cardId}/terminate`, { token: u.token, body: { pin: u.pin } });
  assert.equal(term.body.card.status, 'terminated');
  assert.equal(term.body.card.balance, '0.00');

  const integrity = await call('GET', '/meta/fees');
  assert.equal(integrity.status, 200);
});

test('rechargement de carte directement depuis le solde XOF (conversion automatique)', async () => {
  const { call, newUser, deposit } = t;
  const u = await newUser();
  await deposit(u.token, { amount: '200000' });
  const c = await call('POST', '/cards', { token: u.token, body: { currency: 'EUR', fundingCurrency: 'XOF', initialAmount: '20', pin: u.pin } });
  assert.equal(c.status, 201, JSON.stringify(c.body));
  assert.ok(Number(c.body.card.balance) >= 20);
  const prev = await call('POST', `/cards/${c.body.card.id}/load/preview`, { token: u.token, body: { amount: '100', sourceCurrency: 'XOF' } });
  // 100 EUR ≈ 65 596 XOF + 1,5 % de marge
  assert.ok(Number(prev.body.debited) > 65596 && Number(prev.body.debited) < 67000, prev.body.debited);
  const l = await call('POST', `/cards/${c.body.card.id}/load`, { token: u.token, body: { amount: '100', sourceCurrency: 'XOF' } });
  assert.equal(l.status, 200);
  assert.ok(Number(l.body.card.balance) >= 120);
});

test('carte à usage unique et carte verrouillée sur le premier marchand', async () => {
  const { call, newUser, deposit } = t;
  const u = await newUser();
  await deposit(u.token, { amount: '300000' });
  const q = await call('POST', '/fx/quote', { token: u.token, body: { from: 'XOF', to: 'USD', amount: '200', mode: 'buy' } });
  assert.equal(q.body.toAmount, '200.00');
  await call('POST', '/fx/execute', { token: u.token, body: { quoteId: q.body.id } });

  const mk = async (opts) => {
    const c = await call('POST', '/cards', { token: u.token, body: { initialAmount: '40', pin: u.pin, ...opts } });
    const r = await call('POST', `/cards/${c.body.card.id}/reveal`, { token: u.token, body: { pin: u.pin } });
    return (extra) => call('POST', '/sandbox/card-authorizations', { body: { pan: r.body.pan, cvv: r.body.cvv, expMonth: r.body.expMonth,
      expYear: r.body.expYear, amount: '5', currency: 'USD', merchantName: 'Spotify', merchantCategory: 'streaming', ...extra } });
  };

  const single = await mk({ singleUse: true });
  assert.equal((await single()).body.approved, true);
  assert.equal((await single()).body.approved, false);

  const locked = await mk({ lockToFirstMerchant: true });
  assert.equal((await locked()).body.approved, true);
  assert.equal((await locked()).body.approved, true);
  const other = await locked({ merchantName: 'Inconnu Shop' });
  assert.equal(other.body.approved, false);
  assert.match(other.body.reason, /verrouillée/);

  const limited = await mk({ perTxLimit: '3' });
  assert.equal((await limited()).body.approved, false);
});

test('KYC requis pour les cartes, plafonds et PIN verrouillé après 5 erreurs', async () => {
  const { call, newUser, deposit } = t;
  const u = await newUser({ kyc: false });
  const c = await call('POST', '/cards', { token: u.token, body: { pin: u.pin } });
  assert.equal(c.status, 403);
  assert.equal(c.body.error.code, 'KYC_REQUIRED');

  // Niveau 0 : 100 USD max par opération (~60 000 XOF)
  const big = await call('POST', '/deposits', { token: u.token, body: { country: 'CI', operator: 'WAVE_CI', phone: '0101010101', amount: '500000' } });
  assert.equal(big.status, 403);
  assert.equal(big.body.error.code, 'LIMIT_PER_TX');

  await deposit(u.token, { amount: '50000', operator: 'WAVE_CI' });
  const wd = await call('POST', '/withdrawals', { token: u.token, body: { country: 'CI', operator: 'WAVE_CI', phone: '0101010101', amount: '1000', pin: u.pin } });
  assert.equal(wd.status, 403);
  assert.equal(wd.body.error.code, 'KYC_REQUIRED');

  for (let i = 0; i < 5; i++) {
    const r = await call('POST', '/security/pin', { token: u.token, body: { pin: '8642', password: 'MotDePasse123', currentPin: '0000' } });
    assert.equal(r.status, 403);
  }
  const u2 = await newUser();
  for (let i = 0; i < 5; i++) await call('POST', `/cards/x/reveal`, { token: u2.token, body: { pin: '9999' } });
  const locked = await call('POST', `/cards/x/reveal`, { token: u2.token, body: { pin: u2.pin } });
  assert.equal(locked.status, 423);
});

test('retrait Mobile Money, échec opérateur avec restitution, idempotence et transfert P2P', async () => {
  const { call, newUser, deposit } = t;
  const a = await newUser({ country: 'SN', phone: '771234567' });
  const b = await newUser({ country: 'SN', phone: '781234567' });
  await deposit(a.token, { country: 'SN', operator: 'WAVE_SN', phone: '771234567', amount: '100000' });

  const failDep = await call('POST', '/deposits', { token: a.token, body: { country: 'SN', operator: 'WAVE_SN', phone: '770000000', amount: '5000' } });
  assert.equal(failDep.status, 402);

  const wd = await call('POST', '/withdrawals', { token: a.token, body: { country: 'SN', operator: 'ORANGE_SN', phone: '771234567', amount: '10000', pin: a.pin } });
  assert.equal(wd.status, 201, JSON.stringify(wd.body));
  assert.equal(wd.body.status, 'completed');
  assert.equal(wd.body.received ?? wd.body.net, '9850');

  // Décaissement refusé (numéro test se terminant par 0000) → fonds restitués
  const before = (await call('GET', '/wallets', { token: a.token })).body.wallets.find((x) => x.currency === 'XOF').balance;
  const wf = await call('POST', '/withdrawals', { token: a.token, body: { country: 'SN', operator: 'ORANGE_SN', phone: '770000000', amount: '10000', pin: a.pin } });
  assert.equal(wf.status, 422);
  const afterFail = (await call('GET', '/wallets', { token: a.token })).body.wallets.find((x) => x.currency === 'XOF').balance;
  assert.equal(afterFail, before);

  // Idempotence : deux envois avec la même clé = un seul débit
  const key = 'p2p-test-key-0001';
  const body = { recipient: '781234567', recipientCountry: 'SN', currency: 'XOF', amount: '5000', note: 'Tontine', pin: a.pin };
  const t1 = await call('POST', '/transfers', { token: a.token, body, headers: { 'Idempotency-Key': key } });
  const t2 = await call('POST', '/transfers', { token: a.token, body, headers: { 'Idempotency-Key': key } });
  assert.equal(t1.status, 201);
  assert.deepEqual(t2.body, t1.body);
  const bw = (await call('GET', '/wallets', { token: b.token })).body.wallets.find((x) => x.currency === 'XOF');
  assert.equal(bw.balance, '5000');

  const csv = await call('GET', '/transactions/export.csv', { token: a.token });
  assert.equal(csv.status, 200);
  assert.match(csv.body, /Tontine/);
});

test('webhook avec signature invalide rejeté ; intégrité du grand livre', async () => {
  const { call } = t;
  const r = await call('POST', '/webhooks/mobile-money/sandbox', { body: { event_id: 'x', op_id: 'y', status: 'completed' }, headers: { 'x-sandbox-signature': 'faux' } });
  assert.equal(r.status, 401);
  const ledger = require('../src/services/ledger');
  const check = ledger.integrityCheck();
  assert.equal(check.ok, true, JSON.stringify(check));
});
