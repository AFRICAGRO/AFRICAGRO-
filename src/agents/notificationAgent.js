'use strict';
// AGENT DE NOTIFICATIONS — envoie les e-mails/SMS/alertes en file d'attente avec relances,
// et prévient les utilisateurs quand c'est utile (solde bas, carte qui expire, étapes manquantes).
const db = require('../db');
const fx = require('../services/fx');
const money = require('../lib/money');
const { deliver } = require('../services/channels');
const { notify, alertAdmins } = require('../services/notify');

const MAX_ATTEMPTS = 6;
const isoWeek = () => { const d = new Date(); return `${d.getUTCFullYear()}-${Math.ceil((((d - new Date(Date.UTC(d.getUTCFullYear(), 0, 1))) / 86400000) + 1) / 7)}`; };

async function dispatch(d, out) {
  const rows = d.prepare("SELECT * FROM notification_outbox WHERE status='pending' AND next_attempt_at <= ? ORDER BY created_at LIMIT 100").all(db.now());
  for (const row of rows) {
    try {
      await deliver(row);
      d.prepare("UPDATE notification_outbox SET status='sent', sent_at=?, attempts=attempts+1 WHERE id=?").run(db.now(), row.id);
      out.sent++;
    } catch (err) {
      const attempts = row.attempts + 1;
      const failed = attempts >= MAX_ATTEMPTS;
      const delayMin = Math.min(2 ** attempts, 60); // relance exponentielle : 2, 4, 8… 60 min
      d.prepare('UPDATE notification_outbox SET attempts=?, status=?, last_error=?, next_attempt_at=? WHERE id=?')
        .run(attempts, failed ? 'failed' : 'pending', String(err.message).slice(0, 300), new Date(Date.now() + delayMin * 60000).toISOString(), row.id);
      if (failed && row.channel !== 'admin') {
        alertAdmins({ severity: 'info', type: 'notification_failed', message: `Échec définitif d’envoi ${row.channel} : ${err.message}`, dedupeKey: `nf:${row.id}` });
      }
      out.failed++;
    }
  }
}

function proactive(d, out) {
  // Solde de carte bas (après au moins un achat ce mois-ci).
  const cards = d.prepare(`SELECT c.*, a.balance FROM cards c JOIN accounts a ON a.owner_type='card' AND a.owner_id=c.id AND a.currency=c.currency
                           WHERE c.status='active' AND EXISTS (SELECT 1 FROM card_authorizations x WHERE x.card_id=c.id AND x.status='approved' AND x.created_at>=?)`)
    .all(new Date(Date.now() - 30 * 86400000).toISOString());
  for (const c of cards) {
    if (fx.toUsdCents(c.balance, c.currency) < 200 && notify(c.user_id, 'Solde de carte bas',
      `Il reste ${money.format(c.balance, c.currency)} sur votre carte « ${c.label} » •••• ${c.last4}. Rechargez-la pour éviter un refus de paiement (abonnements…).`,
      { category: 'transaction', dedupeKey: `low_balance:${c.id}:${isoWeek()}` })) out.reminders++;
  }
  // Carte qui expire dans moins de 30 jours.
  const now = new Date();
  for (const c of d.prepare("SELECT * FROM cards WHERE status='active'").all()) {
    const exp = new Date(Date.UTC(c.exp_year, c.exp_month, 1));
    if (exp - now < 30 * 86400000 && notify(c.user_id, 'Votre carte expire bientôt',
      `La carte « ${c.label} » •••• ${c.last4} expire fin ${String(c.exp_month).padStart(2, '0')}/${c.exp_year}. Créez une nouvelle carte et mettez à jour vos abonnements.`,
      { category: 'account', dedupeKey: `card_expiry:${c.id}` })) out.reminders++;
  }
  // Étapes d'inscription non terminées.
  const old = new Date(Date.now() - 3 * 86400000).toISOString();
  for (const u of d.prepare(`SELECT id FROM users WHERE status='active' AND kyc_level=0 AND created_at < ?
                             AND NOT EXISTS (SELECT 1 FROM kyc_submissions k WHERE k.user_id=users.id)`).all(old)) {
    if (notify(u.id, 'Créez votre première carte virtuelle', 'Il ne vous reste qu’à vérifier votre identité pour créer votre carte Visa/Mastercard et payer en ligne.',
      { category: 'account', dedupeKey: `kyc_reminder:${u.id}` })) out.reminders++;
  }
  for (const u of d.prepare("SELECT id FROM users WHERE status='active' AND pin_hash IS NULL AND created_at < ?").all(new Date(Date.now() - 86400000).toISOString())) {
    if (notify(u.id, 'Sécurisez votre compte', 'Définissez votre code PIN de transaction dans « Sécurité & profil ».',
      { category: 'security', dedupeKey: `pin_reminder:${u.id}` })) out.reminders++;
  }
}

async function run() {
  const d = db.get();
  const out = { sent: 0, failed: 0, reminders: 0 };
  proactive(d, out);
  await dispatch(d, out);
  return out;
}

module.exports = { name: 'notification', run, dispatch };
