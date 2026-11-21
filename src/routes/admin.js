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

router.get('/ledger/integrity', (_req, res) => res.json(ledger.integrityCheck()));

router.get('/audit', (_req, res) => {
  res.json({ logs: db.get().prepare('SELECT * FROM audit_logs ORDER BY id DESC LIMIT 200').all() });
});

module.exports = { router };
