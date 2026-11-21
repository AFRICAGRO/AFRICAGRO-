'use strict';
// Notifications utilisateurs (in-app + e-mail/SMS via file d'envoi) et alertes administrateurs.
const db = require('../db');
const config = require('../config');
const { uuid } = require('../lib/crypto');

function enqueue(channel, recipient, subject, body) {
  db.get().prepare('INSERT INTO notification_outbox (id, channel, recipient, subject, body) VALUES (?,?,?,?,?)')
    .run(uuid(), channel, recipient || null, subject || null, body);
}

/**
 * Notifie un utilisateur.
 * category : security (toujours e-mail + SMS), transaction, account, marketing (seulement si consentement).
 * dedupeKey : évite d'envoyer deux fois la même notification (ex. rappel hebdomadaire).
 * sms : force aussi l'envoi par SMS (si l'utilisateur ne l'a pas désactivé).
 * Retourne false si la notification était déjà envoyée (dédoublonnée).
 */
function notify(userId, title, body, { category = 'account', dedupeKey = null, sms = false } = {}) {
  const d = db.get();
  const r = d.prepare('INSERT OR IGNORE INTO notifications (id, user_id, title, body, category, dedupe_key) VALUES (?,?,?,?,?,?)')
    .run(uuid(), userId, title, body, category, dedupeKey);
  if (!r.changes) return false;

  const u = d.prepare('SELECT email, phone, status, notify_email, notify_sms, marketing_opt_in FROM users WHERE id=?').get(userId);
  if (!u || u.status === 'closed') return true;
  if (category === 'marketing' && !u.marketing_opt_in) return true;

  const text = `${title}\n\n${body}\n\n— AfriCard. Nous ne vous demanderons jamais votre code PIN, mot de passe ou code SMS.`;
  if (category === 'security' || u.notify_email) enqueue('email', u.email, `AfriCard — ${title}`, text);
  if (category === 'security' || (sms && u.notify_sms)) enqueue('sms', u.phone, null, `AfriCard: ${title}. ${body}`.slice(0, 300));
  return true;
}

function audit(userId, action, ip, details) {
  db.get().prepare('INSERT INTO audit_logs (user_id, action, ip, details) VALUES (?,?,?,?)')
    .run(userId || null, action, ip || null, details ? JSON.stringify(details) : null);
}

/**
 * Crée une alerte de sécurité/fiabilité pour l'équipe (dédoublonnée) et la diffuse
 * sur les canaux admin (webhook Slack/Discord/Teams, Telegram, e-mail).
 */
function alertAdmins({ severity = 'warning', type, message, userId = null, details = null, dedupeKey = null }) {
  const id = uuid();
  const r = db.get().prepare(`INSERT OR IGNORE INTO security_alerts (id, severity, type, user_id, message, details, dedupe_key)
                              VALUES (?,?,?,?,?,?,?)`)
    .run(id, severity, type, userId, message, details ? JSON.stringify(details) : null, dedupeKey);
  if (!r.changes) return null;
  if (severity !== 'info') {
    const icon = severity === 'critical' ? '🚨' : '⚠️';
    enqueue('admin', null, `${icon} [${severity.toUpperCase()}] ${type}`, `${icon} AfriCard [${severity}] ${type} : ${message}`);
    if (severity === 'critical') {
      for (const email of config.notifications.adminEmails) enqueue('email', email, `🚨 AfriCard — ${type}`, `${message}\n\nDétails : ${JSON.stringify(details || {})}`);
    }
  }
  return id;
}

module.exports = { notify, audit, alertAdmins, enqueue };
