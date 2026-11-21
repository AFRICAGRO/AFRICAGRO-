'use strict';
// Back-office : conformité KYC, supervision, gel de comptes, intégrité comptable.
const express = require('express');
const { z } = require('zod');
const db = require('../db');
const money = require('../lib/money');
const ledger = require('../services/ledger');
const fx = require('../services/fx');
const { validate } = require('../middleware/common');
const { requireAuth, requireAdmin } = require('../middleware/auth');
const { AppError } = require('../lib/errors');
const { decrypt } = require('../lib/crypto');
const { audit, notify } = require('../services/notify');
const agents = require('../agents');
const system = require('../services/system');
const { asyncHandler } = require('../lib/errors');

const router = express.Router();
router.use(requireAuth, requireAdmin);

router.get('/stats', (_req, res) => {
  const d = db.get();
  const users = d.prepare('SELECT COUNT(*) AS n, SUM(kyc_level>=1) AS verified FROM users').get();
  const cards = d.prepare("SELECT COUNT(*) AS n, SUM(status='active') AS active FROM cards").get();
  const volumes = d.prepare("SELECT type, currency, SUM(amount) AS total, COUNT(*) AS n FROM transactions WHERE status='completed' GROUP BY type, currency").all();
  const fees = d.prepare("SELECT currency, balance FROM accounts WHERE owner_type='system' AND kind='fees'").all();
  const feesUsd = fees.reduce((s, f) => s + fx.toUsdCents(f.balance, f.currency), 0);
  const declines = d.prepare("SELECT decline_reason, COUNT(*) AS n FROM card_authorizations WHERE status='declined' GROUP BY decline_reason ORDER BY n DESC LIMIT 10").all();
  res.json({
    users: { total: users.n, verified: users.verified || 0 },
    cards: { total: cards.n, active: cards.active || 0 },
    volumes: volumes.map((v) => ({ ...v, total: money.toMajor(v.total, v.currency) })),
    revenue: { byCurrency: fees.map((f) => ({ currency: f.currency, amount: money.toMajor(f.balance, f.currency) })), usdEquivalent: money.toMajor(feesUsd, 'USD') },
    topDeclineReasons: declines,
    pendingKyc: d.prepare("SELECT COUNT(*) AS n FROM kyc_submissions WHERE status='pending'").get().n,
  });
});

router.get('/users', (req, res) => {
  const q = `%${String(req.query.q || '').toLowerCase()}%`;
  const rows = db.get().prepare(`SELECT id, email, phone, full_name, country, role, status, kyc_level, created_at FROM users
                                 WHERE lower(email) LIKE ? OR phone LIKE ? OR lower(full_name) LIKE ? ORDER BY created_at DESC LIMIT 100`).all(q, q, q);
  res.json({ users: rows });
});

router.post('/users/:id/status', validate(z.object({ status: z.enum(['active', 'frozen']), reason: z.string().min(3).max(300) })), (req, res) => {
  const d = db.get();
  const u = d.prepare('SELECT * FROM users WHERE id=?').get(req.params.id);
  if (!u) throw new AppError(404, 'USER_NOT_FOUND', 'Utilisateur introuvable');
  if (u.id === req.user.id) throw new AppError(400, 'SELF', 'Action impossible sur votre propre compte');
  d.prepare('UPDATE users SET status=? WHERE id=?').run(req.body.status, u.id);
  if (req.body.status === 'frozen') d.prepare('UPDATE refresh_tokens SET revoked_at=? WHERE user_id=? AND revoked_at IS NULL').run(db.now(), u.id);
  audit(req.user.id, `admin.user_${req.body.status}`, req.ip, { target: u.id, reason: req.body.reason });
  res.json({ ok: true });
});

router.get('/kyc', (_req, res) => {
  const rows = db.get().prepare(`SELECT k.*, u.full_name, u.email, u.country FROM kyc_submissions k JOIN users u ON u.id=k.user_id
                                 WHERE k.status='pending' ORDER BY k.created_at`).all();
  res.json({ submissions: rows.map((r) => ({ id: r.id, userId: r.user_id, fullName: r.full_name, email: r.email, country: r.country,
    targetLevel: r.target_level, idType: r.id_type, idNumber: decrypt(r.id_number_enc, r.user_id), dateOfBirth: r.date_of_birth,
    address: r.address, createdAt: r.created_at })) });
});

router.post('/kyc/:id/review', validate(z.object({ decision: z.enum(['approved', 'rejected']), note: z.string().max(300).optional() })), (req, res) => {
  db.tx((d) => {
    const k = d.prepare("SELECT * FROM kyc_submissions WHERE id=? AND status='pending'").get(req.params.id);
    if (!k) throw new AppError(404, 'KYC_NOT_FOUND', 'Dossier introuvable ou déjà traité');
    d.prepare('UPDATE kyc_submissions SET status=?, reviewer_id=?, review_note=?, reviewed_at=? WHERE id=?')
      .run(req.body.decision, req.user.id, req.body.note || null, db.now(), k.id);
    if (req.body.decision === 'approved') d.prepare('UPDATE users SET kyc_level=MAX(kyc_level, ?) WHERE id=?').run(k.target_level, k.user_id);
    notify(k.user_id, req.body.decision === 'approved' ? 'Identité vérifiée ✅' : 'Vérification refusée',
      req.body.decision === 'approved' ? `Votre compte est passé au niveau ${k.target_level}.` : (req.body.note || 'Merci de soumettre des informations valides.'));
    audit(req.user.id, `admin.kyc_${req.body.decision}`, req.ip, { submission: k.id });
  });
  res.json({ ok: true });
});

// ------------------------------------------------------------------ Agents & alertes
router.get('/agents', (_req, res) => res.json({ agents: agents.status(), financialLock: system.financialLock() }));

router.post('/agents/:name/run', asyncHandler(async (req, res) => {
  if (!agents.AGENTS[req.params.name]) throw new AppError(404, 'AGENT_NOT_FOUND', 'Agent inconnu');
  audit(req.user.id, 'admin.agent_run', req.ip, { agent: req.params.name });
  res.json({ summary: await agents.runAgent(req.params.name) });
}));

router.get('/alerts', (req, res) => {
  const status = req.query.status === 'resolved' ? 'resolved' : 'open';
  const rows = db.get().prepare(`SELECT a.*, u.full_name, u.email FROM security_alerts a LEFT JOIN users u ON u.id=a.user_id
                                 WHERE a.status=? ORDER BY CASE a.severity WHEN 'critical' THEN 0 WHEN 'warning' THEN 1 ELSE 2 END, a.created_at DESC LIMIT 200`).all(status);
  res.json({ alerts: rows.map((r) => ({ ...r, details: r.details ? JSON.parse(r.details) : null })) });
});

router.post('/alerts/:id/resolve', validate(z.object({ note: z.string().max(300).optional() })), (req, res) => {
  const r = db.get().prepare("UPDATE security_alerts SET status='resolved', resolved_by=?, resolved_at=? WHERE id=? AND status='open'").run(req.user.id, db.now(), req.params.id);
  if (!r.changes) throw new AppError(404, 'ALERT_NOT_FOUND', 'Alerte introuvable ou déjà traitée');
  audit(req.user.id, 'admin.alert_resolved', req.ip, { alert: req.params.id, note: req.body.note });
  res.json({ ok: true });
});

/** Levée du mode protégé, après vérification humaine du grand livre. */
router.post('/financial-lock/clear', validate(z.object({ reason: z.string().min(5).max(300) })), (req, res) => {
  const check = ledger.integrityCheck();
  if (!check.ok) throw new AppError(409, 'LEDGER_STILL_UNBALANCED', 'Le grand livre est toujours incohérent : corrigez l’anomalie avant de lever le mode protégé');
  system.setFlag('financial_lock', null);
  audit(req.user.id, 'admin.financial_lock_cleared', req.ip, { reason: req.body.reason });
  res.json({ ok: true });
});

router.get('/ip-blocks', (_req, res) => res.json({ blocks: db.get().prepare('SELECT * FROM ip_blocks ORDER BY created_at DESC').all() }));
router.delete('/ip-blocks/:ip', (req, res) => {
  db.get().prepare('DELETE FROM ip_blocks WHERE ip=?').run(req.params.ip);
  audit(req.user.id, 'admin.ip_unblocked', req.ip, { ip: req.params.ip });
  res.json({ ok: true });
});

router.get('/errors', (_req, res) => {
  res.json({ errors: db.get().prepare(`SELECT fingerprint, COUNT(*) AS n, MAX(message) AS message, MAX(route) AS route, MAX(created_at) AS last
                                       FROM error_events GROUP BY fingerprint ORDER BY last DESC LIMIT 50`).all() });
});

router.get('/notifications/outbox', (_req, res) => {
  const d = db.get();
  res.json({ stats: d.prepare('SELECT channel, status, COUNT(*) AS n FROM notification_outbox GROUP BY channel, status').all(),
    failed: d.prepare("SELECT id, channel, recipient, subject, last_error, attempts, created_at FROM notification_outbox WHERE status='failed' ORDER BY created_at DESC LIMIT 50").all() });
});

// ------------------------------------------------------------------ Support
router.get('/tickets', (_req, res) => {
  res.json({ tickets: db.get().prepare(`SELECT t.*, u.full_name, u.email FROM support_tickets t JOIN users u ON u.id=t.user_id
                                        ORDER BY CASE t.status WHEN 'open' THEN 0 ELSE 1 END, t.created_at DESC LIMIT 200`).all() });
});

router.post('/tickets/:id/reply', validate(z.object({ reply: z.string().trim().min(2).max(3000), close: z.boolean().default(false) })), (req, res) => {
  const d = db.get();
  const t = d.prepare('SELECT * FROM support_tickets WHERE id=?').get(req.params.id);
  if (!t) throw new AppError(404, 'TICKET_NOT_FOUND', 'Demande introuvable');
  d.prepare('UPDATE support_tickets SET reply=?, replied_by=?, status=?, updated_at=? WHERE id=?')
    .run(req.body.reply, req.user.id, req.body.close ? 'closed' : 'answered', db.now(), t.id);
  notify(t.user_id, 'Réponse du support', `« ${t.subject} » : ${req.body.reply}`);
  audit(req.user.id, 'admin.ticket_replied', req.ip, { ticket: t.id });
  res.json({ ok: true });
});

router.get('/ledger/integrity', (_req, res) => res.json(ledger.integrityCheck()));

router.get('/audit', (_req, res) => {
  res.json({ logs: db.get().prepare('SELECT * FROM audit_logs ORDER BY id DESC LIMIT 200').all() });
});

module.exports = { router };
