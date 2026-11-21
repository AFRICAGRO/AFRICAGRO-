'use strict';
// AGENT DE SÉCURITÉ — surveille en continu les signaux de fraude et d'attaque, réagit
// automatiquement (blocage d'IP, gel de carte) et prévient l'utilisateur et l'équipe.
const config = require('../config');
const db = require('../db');
const fx = require('../services/fx');
const limits = require('../services/limits');
const { notify, alertAdmins, audit } = require('../services/notify');

const ago = (min) => new Date(Date.now() - min * 60000).toISOString();
const hourBucket = () => new Date().toISOString().slice(0, 13);
const today = () => new Date().toISOString().slice(0, 10);

/** 1. Attaques par force brute : blocage temporaire de l'IP. */
function bruteForce(d, out) {
  const ips = d.prepare(`SELECT ip, COUNT(*) AS n FROM audit_logs WHERE action='auth.login_failed' AND created_at>=? AND ip IS NOT NULL
                         GROUP BY ip HAVING n>=10`).all(ago(15));
  for (const { ip, n } of ips) {
    const r = d.prepare(`INSERT OR IGNORE INTO ip_blocks (ip, reason, expires_at) VALUES (?,?,?)`)
      .run(ip, `${n} échecs de connexion en 15 min`, new Date(Date.now() + 3600000).toISOString());
    if (r.changes) {
      out.ipBlocked++;
      alertAdmins({ severity: 'warning', type: 'brute_force', message: `IP ${ip} bloquée 1 h (${n} échecs de connexion en 15 min)`, details: { ip, n }, dedupeKey: `bf:${ip}:${hourBucket()}` });
    }
  }
  // Compte ciblé : on prévient le titulaire.
  const users = d.prepare(`SELECT user_id, COUNT(*) AS n FROM audit_logs WHERE action='auth.login_failed' AND created_at>=? AND user_id IS NOT NULL
                           GROUP BY user_id HAVING n>=5`).all(ago(15));
  for (const { user_id: uid, n } of users) {
    if (notify(uid, 'Tentatives de connexion suspectes', `${n} tentatives de connexion échouées sur votre compte. Si ce n’est pas vous, changez votre mot de passe et activez la double authentification.`,
      { category: 'security', dedupeKey: `login_attack:${uid}:${hourBucket()}` })) out.usersWarned++;
  }
  d.prepare('DELETE FROM ip_blocks WHERE expires_at < ?').run(db.now());
}

/** 2. Test de cartes volées (CVV/date au hasard) : gel automatique de la carte. */
function cardTesting(d, out) {
  const rows = d.prepare(`SELECT card_id, COUNT(*) AS n FROM card_authorizations
                          WHERE status='declined' AND created_at>=? AND card_id!='unknown'
                            AND (decline_reason LIKE 'CVV%' OR decline_reason LIKE 'Date d%')
                          GROUP BY card_id HAVING n>=3`).all(ago(30));
  for (const { card_id: cardId, n } of rows) {
    const card = d.prepare("SELECT * FROM cards WHERE id=? AND status='active'").get(cardId);
    if (!card) continue;
    d.prepare("UPDATE cards SET status='frozen' WHERE id=?").run(card.id);
    audit(card.user_id, 'agent.card_frozen', null, { card: card.id, reason: 'card_testing', attempts: n });
    notify(card.user_id, 'Carte gelée par sécurité ❄️', `Nous avons détecté ${n} tentatives de paiement avec un CVV ou une date erronés sur votre carte •••• ${card.last4}. Elle a été gelée. Si vous êtes à l’origine de ces essais, dégelez-la dans l’application ; sinon, résiliez-la et créez-en une nouvelle.`,
      { category: 'security' });
    alertAdmins({ severity: 'warning', type: 'card_testing', userId: card.user_id, message: `Carte •••• ${card.last4} gelée automatiquement (${n} essais CVV/date)`, dedupeKey: `ct:${card.id}:${hourBucket()}` });
    out.cardsFrozen++;
  }
  const unknown = d.prepare(`SELECT COUNT(*) AS n FROM card_authorizations WHERE card_id='unknown' AND created_at>=?`).get(ago(10)).n;
  if (unknown >= 20) {
    alertAdmins({ severity: 'critical', type: 'bin_attack', message: `${unknown} tentatives avec des numéros de carte inconnus en 10 min (attaque par énumération possible)`, dedupeKey: `bin:${hourBucket()}` });
  }
}

/** 3. Code PIN : plusieurs erreurs → l'utilisateur est prévenu. */
function pinAbuse(d, out) {
  const rows = d.prepare(`SELECT user_id, COUNT(*) AS n FROM audit_logs WHERE action='pin.failed' AND created_at>=? GROUP BY user_id HAVING n>=3`).all(ago(60));
  for (const { user_id: uid, n } of rows) {
    if (notify(uid, 'Code PIN erroné plusieurs fois', `${n} saisies de PIN erronées dans la dernière heure. Si ce n’est pas vous, changez immédiatement votre mot de passe.`,
      { category: 'security', dedupeKey: `pin_abuse:${uid}:${hourBucket()}` })) out.usersWarned++;
  }
}

/** 4. Lutte anti-blanchiment (LBC/FT) : gros montants, cumul journalier, fractionnement, entrées-sorties rapides. */
function aml(d, out) {
  const txs = d.prepare(`SELECT * FROM transactions WHERE created_at>=? AND status IN ('completed','pending')
                         AND type IN ('deposit','withdrawal','p2p','card_purchase')
                         AND NOT (type='p2p' AND json_extract(metadata,'$.direction')='in')`).all(ago(24 * 60));
  const perUser = {};
  for (const t of txs) {
    const usd = fx.toUsdCents(t.amount, t.currency);
    perUser[t.user_id] = perUser[t.user_id] || { total: 0, deposits: [] };
    perUser[t.user_id].total += usd;
    if (t.type === 'deposit') perUser[t.user_id].deposits.push(usd);
    if (usd >= config.agents.amlSingleTxUsdCents) {
      if (alertAdmins({ severity: 'warning', type: 'aml_large_tx', userId: t.user_id, message: `Opération importante : ${t.type} ≈ ${(usd / 100).toFixed(0)} USD`, details: { tx: t.id }, dedupeKey: `aml_tx:${t.id}` })) out.amlAlerts++;
    }
  }
  for (const [uid, s] of Object.entries(perUser)) {
    if (s.total >= config.agents.amlDailyUsdCents) {
      if (alertAdmins({ severity: 'warning', type: 'aml_daily_volume', userId: uid, message: `Volume sur 24 h ≈ ${(s.total / 100).toFixed(0)} USD`, dedupeKey: `aml_day:${uid}:${today()}` })) out.amlAlerts++;
    }
    const user = d.prepare('SELECT kyc_level FROM users WHERE id=?').get(uid);
    const perTx = (limits.TIERS[user?.kyc_level] || limits.TIERS[0]).perTx;
    const nearLimit = s.deposits.filter((u) => u >= perTx * 0.8).length;
    if (nearLimit >= 5) {
      if (alertAdmins({ severity: 'warning', type: 'aml_structuring', userId: uid, message: `${nearLimit} dépôts proches du plafond en 24 h (fractionnement possible)`, dedupeKey: `aml_struct:${uid}:${today()}` })) out.amlAlerts++;
    }
  }
  // Entrée puis sortie quasi immédiate sur un compte récent (compte « mule »).
  const wds = d.prepare(`SELECT t.*, u.created_at AS user_created FROM transactions t JOIN users u ON u.id=t.user_id
                         WHERE t.type='withdrawal' AND t.status='completed' AND t.created_at>=?`).all(ago(120));
  for (const w of wds) {
    if (Date.now() - new Date(w.user_created).getTime() > 7 * 86400000) continue;
    const dep = d.prepare(`SELECT COALESCE(SUM(amount),0) AS s FROM transactions WHERE user_id=? AND type='deposit' AND status='completed'
                           AND currency=? AND created_at BETWEEN ? AND ?`).get(w.user_id, w.currency, new Date(new Date(w.created_at).getTime() - 3600000).toISOString(), w.created_at).s;
    if (dep > 0 && w.amount >= dep * 0.9) {
      if (alertAdmins({ severity: 'warning', type: 'aml_rapid_in_out', userId: w.user_id, message: 'Dépôt puis retrait quasi total en moins d’une heure sur un compte de moins de 7 jours', details: { withdrawal: w.id }, dedupeKey: `aml_rio:${w.id}` })) out.amlAlerts++;
    }
  }
}

function run() {
  const d = db.get();
  const out = { ipBlocked: 0, cardsFrozen: 0, usersWarned: 0, amlAlerts: 0 };
  bruteForce(d, out);
  cardTesting(d, out);
  pinAbuse(d, out);
  aml(d, out);
  return out;
}

module.exports = { name: 'security', run };
