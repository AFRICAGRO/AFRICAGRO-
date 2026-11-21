'use strict';
// AGENT DE FIABILITÉ — prévient et corrige les anomalies : contrôle comptable continu,
// auto-réparation des soldes, mode protégé, opérations bloquées, pics d'erreurs, nettoyage.
const config = require('../config');
const db = require('../db');
const mm = require('../services/mobileMoney');
const system = require('../services/system');
const { PROVIDERS } = require('../providers/mobileMoney');
const { alertAdmins } = require('../services/notify');

const ago = (min) => new Date(Date.now() - min * 60000).toISOString();
const hourBucket = () => new Date().toISOString().slice(0, 13);

/** 1. Grand livre : écritures déséquilibrées → mode protégé ; solde en cache divergent → auto-réparation. */
function ledger(d, out) {
  const unbalanced = d.prepare('SELECT currency, SUM(amount) AS total FROM ledger_entries GROUP BY currency HAVING total != 0').all();
  const negatives = d.prepare('SELECT id, currency, balance FROM accounts WHERE allow_negative=0 AND balance < 0').all();
  if (unbalanced.length || negatives.length) {
    if (!system.financialLock()) {
      system.setFlag('financial_lock', `Anomalie comptable détectée le ${db.now()}`);
      out.lockEngaged = true;
    }
    alertAdmins({ severity: 'critical', type: 'ledger_anomaly', message: 'Grand livre incohérent : mode protégé activé (mouvements de fonds suspendus)',
      details: { unbalanced, negatives }, dedupeKey: `ledger:${hourBucket()}` });
    return;
  }
  // Les écritures sont la source de vérité : on recalcule les soldes en cache divergents.
  const drift = d.prepare(`SELECT a.id, a.balance, COALESCE(SUM(e.amount),0) AS computed FROM accounts a
                           LEFT JOIN ledger_entries e ON e.account_id=a.id GROUP BY a.id HAVING a.balance != computed`).all();
  if (drift.length) {
    db.tx((dd) => { for (const r of drift) dd.prepare('UPDATE accounts SET balance=? WHERE id=?').run(r.computed, r.id); });
    out.balancesRepaired = drift.length;
    alertAdmins({ severity: 'warning', type: 'ledger_self_heal', message: `${drift.length} solde(s) en cache recalculé(s) depuis les écritures`, details: drift, dedupeKey: `heal:${hourBucket()}` });
  }
}

/** 2. Opérations Mobile Money restées en attente : re-vérification ou expiration. */
async function stuckOperations(d, out) {
  const expiry = config.agents.pendingDepositExpiryMin;
  const deps = d.prepare("SELECT * FROM mobile_money_ops WHERE direction='deposit' AND status='pending' AND created_at < ?").all(ago(expiry));
  for (const op of deps) {
    let status = 'failed';
    const provider = PROVIDERS[op.provider];
    if (provider?.checkStatus) {
      try { status = await provider.checkStatus(op.id); } catch { status = 'pending'; }
      if (status === 'pending' && op.created_at > ago(24 * 60)) continue; // on réessaiera
      if (status === 'pending') status = 'failed';
    }
    mm.finalize(op.id, status, status === 'failed' ? 'Délai de validation dépassé : aucun montant n’a été débité' : undefined);
    out.depositsResolved++;
  }
  const wds = d.prepare("SELECT id, user_id FROM mobile_money_ops WHERE direction='withdrawal' AND status='pending' AND created_at < ?").all(ago(120));
  for (const w of wds) {
    // Pas de restitution automatique : l'argent a peut-être été envoyé. Vérification humaine.
    alertAdmins({ severity: 'warning', type: 'stuck_withdrawal', userId: w.user_id, message: `Retrait ${w.id} en attente depuis plus de 2 h : rapprochement manuel requis`, dedupeKey: `stuck_wd:${w.id}` });
  }
  out.withdrawalsFlagged = wds.length;
}

/** 3. Pics d'erreurs serveur (bug en production). */
function errorSpikes(d, out) {
  const rows = d.prepare(`SELECT fingerprint, COUNT(*) AS n, MAX(message) AS message, MAX(route) AS route FROM error_events
                          WHERE created_at>=? GROUP BY fingerprint HAVING n>=5`).all(ago(10));
  for (const r of rows) {
    if (alertAdmins({ severity: 'critical', type: 'error_spike', message: `${r.n} erreurs identiques en 10 min sur ${r.route || '?'} : ${r.message}`, details: r, dedupeKey: `err:${r.fingerprint}:${hourBucket()}` })) out.errorAlerts++;
  }
  const failedOutbox = d.prepare("SELECT COUNT(*) AS n FROM notification_outbox WHERE status='failed' AND created_at>=?").get(ago(60)).n;
  if (failedOutbox >= 10) {
    alertAdmins({ severity: 'warning', type: 'notification_failures', message: `${failedOutbox} notifications n’ont pas pu être envoyées dans la dernière heure : vérifiez les fournisseurs e-mail/SMS`, dedupeKey: `outbox:${hourBucket()}` });
  }
}

/** 4. Hygiène des données : purge des données techniques expirées (minimisation RGPD/lois locales). */
function cleanup(d, out) {
  const day = ago(24 * 60);
  out.purged = [
    d.prepare('DELETE FROM idempotency_keys WHERE created_at < ?').run(day).changes,
    d.prepare('DELETE FROM fx_quotes WHERE expires_at < ?').run(day).changes,
    d.prepare('DELETE FROM refresh_tokens WHERE expires_at < ? OR (revoked_at IS NOT NULL AND revoked_at < ?)').run(db.now(), ago(30 * 24 * 60)).changes,
    d.prepare('DELETE FROM password_resets WHERE expires_at < ?').run(day).changes,
    d.prepare('DELETE FROM error_events WHERE created_at < ?').run(ago(30 * 24 * 60)).changes,
    d.prepare("DELETE FROM notification_outbox WHERE status='sent' AND created_at < ?").run(ago(30 * 24 * 60)).changes,
    d.prepare('DELETE FROM agent_runs WHERE finished_at < ?').run(ago(7 * 24 * 60)).changes,
  ].reduce((a, b) => a + b, 0);
}

async function run() {
  const d = db.get();
  const out = { lockEngaged: false, balancesRepaired: 0, depositsResolved: 0, withdrawalsFlagged: 0, errorAlerts: 0, purged: 0 };
  ledger(d, out);
  await stuckOperations(d, out);
  errorSpikes(d, out);
  cleanup(d, out);
  return out;
}

module.exports = { name: 'reliability', run };
