'use strict';
// Sécurité du compte, KYC, notifications, historique et relevés.
const express = require('express');
const { z } = require('zod');
const config = require('../config');
const db = require('../db');
const money = require('../lib/money');
const { validate } = require('../middleware/common');
const { requireAuth } = require('../middleware/auth');
const { hashSecret, verifySecret, generateTotpSecret, verifyTotp, encrypt, decrypt, uuid } = require('../lib/crypto');
const { AppError } = require('../lib/errors');
const { audit, notify } = require('../services/notify');
const { publicUser, passwordSchema } = require('./auth');

const router = express.Router();
router.use(requireAuth);

// ------------------------------------------------------------------ Code PIN de transaction
const WEAK_PINS = new Set(['0000', '1111', '1234', '4321', '2222', '9999', '000000', '123456', '111111', '654321']);
router.post('/security/pin', validate(z.object({
  pin: z.string().regex(/^\d{4,6}$/, 'le PIN doit contenir 4 à 6 chiffres'),
  password: z.string().min(1),
  currentPin: z.string().optional(),
})), (req, res) => {
  const { pin, password, currentPin } = req.body;
  if (!verifySecret(password, req.user.password_hash)) throw new AppError(401, 'INVALID_PASSWORD', 'Mot de passe incorrect');
  if (req.user.pin_hash && !verifySecret(currentPin || '', req.user.pin_hash)) throw new AppError(403, 'INVALID_PIN', 'PIN actuel incorrect');
  if (WEAK_PINS.has(pin)) throw new AppError(400, 'WEAK_PIN', 'Ce code PIN est trop simple');
  db.get().prepare('UPDATE users SET pin_hash=?, failed_pins=0, pin_locked_until=NULL WHERE id=?').run(hashSecret(pin), req.user.id);
  audit(req.user.id, 'security.pin_set', req.ip);
  res.json({ ok: true });
});

router.post('/security/password', validate(z.object({ currentPassword: z.string().min(1), newPassword: passwordSchema })), (req, res) => {
  if (!verifySecret(req.body.currentPassword, req.user.password_hash)) throw new AppError(401, 'INVALID_PASSWORD', 'Mot de passe incorrect');
  const d = db.get();
  d.prepare('UPDATE users SET password_hash=? WHERE id=?').run(hashSecret(req.body.newPassword), req.user.id);
  d.prepare('UPDATE refresh_tokens SET revoked_at=? WHERE user_id=? AND revoked_at IS NULL').run(db.now(), req.user.id);
  audit(req.user.id, 'security.password_changed', req.ip);
  notify(req.user.id, 'Mot de passe modifié', 'Toutes vos autres sessions ont été déconnectées.');
  res.json({ ok: true });
});

// ------------------------------------------------------------------ Double authentification (TOTP)
router.post('/security/2fa/setup', (req, res) => {
  if (req.user.totp_enabled) throw new AppError(409, 'TOTP_ALREADY_ENABLED', 'La double authentification est déjà active');
  const secret = generateTotpSecret();
  db.get().prepare('UPDATE users SET totp_secret_enc=? WHERE id=?').run(encrypt(secret, req.user.id), req.user.id);
  const label = encodeURIComponent(`AfriCard:${req.user.email}`);
  res.json({ secret, otpauthUrl: `otpauth://totp/${label}?secret=${secret}&issuer=AfriCard&digits=6&period=30` });
});

router.post('/security/2fa/enable', validate(z.object({ code: z.string().regex(/^\d{6}$/) })), (req, res) => {
  if (!req.user.totp_secret_enc) throw new AppError(400, 'TOTP_NOT_SETUP', 'Lancez d’abord la configuration');
  if (!verifyTotp(decrypt(req.user.totp_secret_enc, req.user.id), req.body.code)) throw new AppError(400, 'INVALID_TOTP', 'Code invalide');
  db.get().prepare('UPDATE users SET totp_enabled=1 WHERE id=?').run(req.user.id);
  audit(req.user.id, 'security.2fa_enabled', req.ip);
  res.json({ ok: true });
});

router.post('/security/2fa/disable', validate(z.object({ code: z.string().regex(/^\d{6}$/), password: z.string().min(1) })), (req, res) => {
  if (!req.user.totp_enabled) throw new AppError(400, 'TOTP_NOT_ENABLED', 'Double authentification inactive');
  if (!verifySecret(req.body.password, req.user.password_hash)) throw new AppError(401, 'INVALID_PASSWORD', 'Mot de passe incorrect');
  if (!verifyTotp(decrypt(req.user.totp_secret_enc, req.user.id), req.body.code)) throw new AppError(400, 'INVALID_TOTP', 'Code invalide');
  db.get().prepare('UPDATE users SET totp_enabled=0, totp_secret_enc=NULL WHERE id=?').run(req.user.id);
  audit(req.user.id, 'security.2fa_disabled', req.ip);
  res.json({ ok: true });
});

router.get('/security/sessions', (req, res) => {
  const rows = db.get().prepare(`SELECT id, user_agent, ip, created_at, expires_at FROM refresh_tokens
                                 WHERE user_id=? AND revoked_at IS NULL AND expires_at > ? ORDER BY created_at DESC`).all(req.user.id, db.now());
  res.json({ sessions: rows });
});

router.get('/security/activity', (req, res) => {
  const rows = db.get().prepare('SELECT action, ip, created_at FROM audit_logs WHERE user_id=? ORDER BY id DESC LIMIT 50').all(req.user.id);
  res.json({ activity: rows });
});

router.patch('/profile', validate(z.object({ preferredCurrency: z.string().length(3).toUpperCase() })), (req, res) => {
  money.currency(req.body.preferredCurrency);
  db.get().prepare('UPDATE users SET preferred_currency=? WHERE id=?').run(req.body.preferredCurrency, req.user.id);
  res.json({ user: publicUser(db.get().prepare('SELECT * FROM users WHERE id=?').get(req.user.id)) });
});

// ------------------------------------------------------------------ KYC
const ID_TYPES = ['cni', 'passport', 'driver_license', 'residence_permit', 'voter_card', 'nin'];
router.post('/kyc', validate(z.object({
  targetLevel: z.union([z.literal(1), z.literal(2)]),
  idType: z.enum(ID_TYPES),
  idNumber: z.string().trim().min(4).max(40),
  dateOfBirth: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  address: z.string().trim().min(5).max(300),
})), (req, res) => {
  const { targetLevel, idType, idNumber, dateOfBirth, address } = req.body;
  const age = (Date.now() - new Date(dateOfBirth).getTime()) / (365.25 * 86400000);
  if (!(age >= 18 && age < 120)) throw new AppError(400, 'UNDERAGE', 'Vous devez avoir au moins 18 ans');
  if (targetLevel <= req.user.kyc_level) throw new AppError(400, 'ALREADY_VERIFIED', 'Niveau déjà atteint');
  const d = db.get();
  if (d.prepare("SELECT 1 FROM kyc_submissions WHERE user_id=? AND status='pending'").get(req.user.id)) {
    throw new AppError(409, 'KYC_PENDING', 'Une vérification est déjà en cours');
  }
  const id = uuid();
  d.prepare(`INSERT INTO kyc_submissions (id, user_id, target_level, id_type, id_number_enc, date_of_birth, address)
             VALUES (?,?,?,?,?,?,?)`).run(id, req.user.id, targetLevel, idType, encrypt(idNumber, req.user.id), dateOfBirth, address);
  audit(req.user.id, 'kyc.submitted', req.ip, { targetLevel });

  // En sandbox, validation automatique pour faciliter les tests (désactivée en production).
  if (config.sandboxAutoApproveKyc) {
    d.prepare("UPDATE kyc_submissions SET status='approved', review_note='Validation automatique (sandbox)', reviewed_at=? WHERE id=?").run(db.now(), id);
    d.prepare('UPDATE users SET kyc_level=? WHERE id=?').run(targetLevel, req.user.id);
    notify(req.user.id, 'Identité vérifiée ✅', `Votre compte est passé au niveau ${targetLevel}.`);
  }
  res.status(201).json({ id, status: config.sandboxAutoApproveKyc ? 'approved' : 'pending' });
});

router.get('/kyc', (req, res) => {
  const rows = db.get().prepare('SELECT id, target_level, id_type, status, review_note, created_at, reviewed_at FROM kyc_submissions WHERE user_id=? ORDER BY created_at DESC').all(req.user.id);
  res.json({ level: req.user.kyc_level, submissions: rows });
});

// ------------------------------------------------------------------ Notifications
router.get('/notifications', (req, res) => {
  const d = db.get();
  const rows = d.prepare('SELECT * FROM notifications WHERE user_id=? ORDER BY created_at DESC LIMIT 50').all(req.user.id);
  const unread = d.prepare('SELECT COUNT(*) AS n FROM notifications WHERE user_id=? AND read_at IS NULL').get(req.user.id).n;
  res.json({ unread, notifications: rows });
});

router.post('/notifications/read', (req, res) => {
  db.get().prepare('UPDATE notifications SET read_at=? WHERE user_id=? AND read_at IS NULL').run(db.now(), req.user.id);
  res.json({ ok: true });
});

// ------------------------------------------------------------------ Historique & relevé
function txRows(userId, { type, limit = 100, from, to }) {
  const where = ['user_id=?']; const args = [userId];
  if (type) { where.push('type=?'); args.push(type); }
  if (from) { where.push('created_at>=?'); args.push(from); }
  if (to) { where.push('created_at<=?'); args.push(to); }
  return db.get().prepare(`SELECT * FROM transactions WHERE ${where.join(' AND ')} ORDER BY created_at DESC LIMIT ?`)
    .all(...args, Math.min(Number(limit) || 100, 1000));
}

const publicTx = (t) => ({ id: t.id, type: t.type, status: t.status, amount: money.toMajor(t.amount, t.currency), currency: t.currency,
  fee: money.toMajor(t.fee, t.currency), description: t.description, metadata: t.metadata ? JSON.parse(t.metadata) : null, createdAt: t.created_at });

router.get('/transactions', (req, res) => {
  res.json({ transactions: txRows(req.user.id, req.query).map(publicTx) });
});

router.get('/transactions/export.csv', (req, res) => {
  const rows = txRows(req.user.id, { ...req.query, limit: 1000 });
  const esc = (v) => `"${String(v ?? '').replace(/"/g, '""').replace(/^[=+\-@]/, "'$&")}"`;
  const lines = ['date;type;statut;montant;devise;frais;description;reference'];
  for (const t of rows) {
    lines.push([t.created_at, t.type, t.status, money.toMajor(t.amount, t.currency), t.currency, money.toMajor(t.fee, t.currency), t.description, t.id].map(esc).join(';'));
  }
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', 'attachment; filename="releve-africard.csv"');
  res.send('﻿' + lines.join('\n'));
});

module.exports = { router, publicTx };
