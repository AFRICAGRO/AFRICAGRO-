'use strict';
// Données personnelles (droits d'accès, de rectification, d'opposition, de suppression),
// consentements et service client / réclamations.
const express = require('express');
const { z } = require('zod');
const config = require('../config');
const db = require('../db');
const money = require('../lib/money');
const ledger = require('../services/ledger');
const { validate } = require('../middleware/common');
const { requireAuth, requirePin } = require('../middleware/auth');
const { verifySecret, decrypt, uuid, randomToken, hashSecret } = require('../lib/crypto');
const { AppError } = require('../lib/errors');
const { audit, notify, alertAdmins } = require('../services/notify');
const { recordConsent, publicUser } = require('./auth');

const router = express.Router();
router.use(requireAuth);

// ------------------------------------------------------------------ Consentements
router.post('/consents', validate(z.object({ documents: z.array(z.enum(['privacy', 'terms'])).min(1) })), (req, res) => {
  for (const doc of req.body.documents) {
    recordConsent(req, req.user.id, doc, doc === 'privacy' ? config.legal.privacyVersion : config.legal.termsVersion);
  }
  audit(req.user.id, 'privacy.consent_given', req.ip, { documents: req.body.documents });
  res.json({ ok: true });
});

router.get('/privacy/consents', (req, res) => {
  const rows = db.get().prepare('SELECT document, version, granted, ip, created_at FROM consents WHERE user_id=? ORDER BY created_at DESC').all(req.user.id);
  res.json({ consents: rows, current: { privacy: config.legal.privacyVersion, terms: config.legal.termsVersion } });
});

router.patch('/privacy/preferences', validate(z.object({
  notifyEmail: z.boolean().optional(), notifySms: z.boolean().optional(), marketingOptIn: z.boolean().optional(),
})), (req, res) => {
  const d = db.get();
  const b = req.body;
  if (b.notifyEmail !== undefined) d.prepare('UPDATE users SET notify_email=? WHERE id=?').run(b.notifyEmail ? 1 : 0, req.user.id);
  if (b.notifySms !== undefined) d.prepare('UPDATE users SET notify_sms=? WHERE id=?').run(b.notifySms ? 1 : 0, req.user.id);
  if (b.marketingOptIn !== undefined) {
    d.prepare('UPDATE users SET marketing_opt_in=? WHERE id=?').run(b.marketingOptIn ? 1 : 0, req.user.id);
    recordConsent(req, req.user.id, 'marketing', 'v1', b.marketingOptIn);
  }
  audit(req.user.id, 'privacy.preferences_updated', req.ip, b);
  res.json({ user: publicUser(d.prepare('SELECT * FROM users WHERE id=?').get(req.user.id)) });
});

/** Droit d'accès et de portabilité : export complet des données au format JSON. */
router.get('/privacy/export', (req, res) => {
  const d = db.get();
  const uid = req.user.id;
  const mask = (s) => (s && s.length > 4 ? `${'•'.repeat(s.length - 4)}${s.slice(-4)}` : s);
  const data = {
    exportedAt: db.now(),
    controller: { name: config.legal.companyName, dpo: config.legal.dpoEmail },
    profile: publicUser(req.user),
    consents: d.prepare('SELECT document, version, granted, ip, created_at FROM consents WHERE user_id=?').all(uid),
    kyc: d.prepare('SELECT target_level, id_type, id_number_enc, date_of_birth, address, status, created_at, reviewed_at FROM kyc_submissions WHERE user_id=?').all(uid)
      .map(({ id_number_enc: enc, ...k }) => ({ ...k, id_number: mask(decrypt(enc, uid)) })),
    wallets: ledger.userWallets(uid).map((w) => ({ currency: w.currency, balance: money.toMajor(w.balance, w.currency) })),
    cards: d.prepare('SELECT id, label, brand, currency, last4, exp_month, exp_year, status, created_at, terminated_at FROM cards WHERE user_id=?').all(uid),
    cardPayments: d.prepare(`SELECT a.merchant_name, a.merchant_category, a.merchant_country, a.amount, a.currency, a.status, a.decline_reason, a.created_at
                             FROM card_authorizations a JOIN cards c ON c.id=a.card_id WHERE c.user_id=?`).all(uid),
    transactions: d.prepare('SELECT id, type, status, amount, currency, fee, description, created_at FROM transactions WHERE user_id=?').all(uid)
      .map((t) => ({ ...t, amount: money.toMajor(t.amount, t.currency), fee: money.toMajor(t.fee, t.currency) })),
    mobileMoney: d.prepare('SELECT direction, country, operator, phone, amount, currency, status, created_at FROM mobile_money_ops WHERE user_id=?').all(uid),
    notifications: d.prepare('SELECT title, body, category, created_at FROM notifications WHERE user_id=?').all(uid),
    securityLog: d.prepare('SELECT action, ip, created_at FROM audit_logs WHERE user_id=?').all(uid),
    supportTickets: d.prepare('SELECT category, subject, message, status, reply, created_at FROM support_tickets WHERE user_id=?').all(uid),
  };
  audit(uid, 'privacy.export', req.ip);
  res.setHeader('Content-Disposition', 'attachment; filename="mes-donnees-africard.json"');
  res.setHeader('Cache-Control', 'no-store');
  res.json(data);
});

/**
 * Droit à l'effacement : clôture du compte et anonymisation des données d'identification.
 * Les enregistrements financiers sont conservés (obligation légale LBC/FT, 10 ans) mais détachés de l'identité.
 */
router.post('/privacy/close-account', requirePin, validate(z.object({ password: z.string().min(1), reason: z.string().max(300).optional() })), (req, res) => {
  const u = req.user;
  if (!verifySecret(req.body.password, u.password_hash)) throw new AppError(401, 'INVALID_PASSWORD', 'Mot de passe incorrect');
  const d = db.get();
  const nonZero = d.prepare(`SELECT a.currency, a.balance FROM accounts a LEFT JOIN cards c ON a.owner_type='card' AND c.id=a.owner_id
                             WHERE a.balance != 0 AND ((a.owner_type='user' AND a.owner_id=?) OR (a.owner_type='card' AND c.user_id=?))`).all(u.id, u.id);
  if (nonZero.length) {
    throw new AppError(409, 'BALANCE_NOT_ZERO', `Retirez ou transférez d’abord vos soldes restants (${nonZero.map((x) => money.format(x.balance, x.currency)).join(', ')})`);
  }
  if (d.prepare("SELECT 1 FROM mobile_money_ops WHERE user_id=? AND status='pending'").get(u.id)) {
    throw new AppError(409, 'PENDING_OPERATIONS', 'Une opération Mobile Money est encore en cours');
  }
  db.tx((dd) => {
    dd.prepare("UPDATE cards SET status='terminated', terminated_at=? WHERE user_id=? AND status!='terminated'").run(db.now(), u.id);
    dd.prepare('UPDATE refresh_tokens SET revoked_at=? WHERE user_id=? AND revoked_at IS NULL').run(db.now(), u.id);
    dd.prepare(`UPDATE users SET status='closed', closed_at=?, email=?, phone=?, full_name='Compte clôturé', password_hash=?, pin_hash=NULL,
                totp_secret_enc=NULL, totp_enabled=0, notify_email=0, notify_sms=0, marketing_opt_in=0 WHERE id=?`)
      .run(db.now(), `closed+${u.id}@africard.invalid`, `closed:${u.id}`, hashSecret(randomToken()), u.id);
    dd.prepare('DELETE FROM notifications WHERE user_id=?').run(u.id);
    audit(u.id, 'privacy.account_closed', req.ip, { reason: req.body.reason || null });
  });
  res.clearCookie('africard_rt', { path: '/api/auth' });
  res.json({ ok: true, message: 'Compte clôturé. Vos données d’identification ont été anonymisées ; les justificatifs financiers sont conservés le temps exigé par la loi.' });
});

// ------------------------------------------------------------------ Support / réclamations
const CATEGORIES = ['reclamation', 'fraude', 'carte', 'mobile_money', 'compte', 'donnees_personnelles', 'autre'];

router.post('/support/tickets', validate(z.object({
  category: z.enum(CATEGORIES), subject: z.string().trim().min(3).max(120), message: z.string().trim().min(10).max(3000),
})), (req, res) => {
  const id = uuid();
  db.get().prepare('INSERT INTO support_tickets (id, user_id, category, subject, message) VALUES (?,?,?,?,?)')
    .run(id, req.user.id, req.body.category, req.body.subject, req.body.message);
  notify(req.user.id, 'Demande reçue', `Votre demande « ${req.body.subject} » (réf. ${id.slice(0, 8).toUpperCase()}) a bien été enregistrée. Réponse sous 48 h ouvrées.`);
  if (['fraude', 'donnees_personnelles', 'reclamation'].includes(req.body.category)) {
    alertAdmins({ severity: req.body.category === 'fraude' ? 'critical' : 'warning', type: `ticket_${req.body.category}`, userId: req.user.id,
      message: `Nouvelle demande « ${req.body.subject} »`, dedupeKey: `ticket:${id}` });
  }
  res.status(201).json({ id, reference: id.slice(0, 8).toUpperCase() });
});

router.get('/support/tickets', (req, res) => {
  res.json({ tickets: db.get().prepare('SELECT * FROM support_tickets WHERE user_id=? ORDER BY created_at DESC').all(req.user.id) });
});

module.exports = { router, TICKET_CATEGORIES: CATEGORIES };
