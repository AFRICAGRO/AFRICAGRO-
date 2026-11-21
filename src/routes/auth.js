'use strict';
const express = require('express');
const { z } = require('zod');
const config = require('../config');
const db = require('../db');
const { validate } = require('../middleware/common');
const { signAccessToken, requireAuth } = require('../middleware/auth');
const { hashSecret, verifySecret, randomToken, sha256, uuid, verifyTotp, decrypt } = require('../lib/crypto');
const { AppError, asyncHandler } = require('../lib/errors');
const { getCountry, normalizePhone } = require('../data/countries');
const { audit, notify } = require('../services/notify');
const limits = require('../services/limits');

const router = express.Router();
const COOKIE = 'africard_rt';

const passwordSchema = z.string().min(10, 'au moins 10 caractères').max(128)
  .regex(/[a-z]/, 'doit contenir une minuscule').regex(/[A-Z]/, 'doit contenir une majuscule').regex(/\d/, 'doit contenir un chiffre');

function publicUser(u) {
  return { id: u.id, email: u.email, phone: u.phone, fullName: u.full_name, country: u.country, role: u.role, status: u.status,
    kycLevel: u.kyc_level, totpEnabled: Boolean(u.totp_enabled), pinSet: Boolean(u.pin_hash), preferredCurrency: u.preferred_currency,
    createdAt: u.created_at };
}

function issueSession(req, res, user, family = uuid()) {
  const raw = randomToken(48);
  const expires = new Date(Date.now() + config.refreshTokenTtlDays * 86400000);
  db.get().prepare('INSERT INTO refresh_tokens (id, user_id, token_hash, family, expires_at, user_agent, ip) VALUES (?,?,?,?,?,?,?)')
    .run(uuid(), user.id, sha256(raw), family, expires.toISOString(), (req.get('user-agent') || '').slice(0, 200), req.ip);
  res.cookie(COOKIE, raw, { httpOnly: true, secure: config.isProd, sameSite: 'strict', path: '/api/auth', expires });
  return { accessToken: signAccessToken(user), expiresIn: config.accessTokenTtlSec, user: publicUser(user) };
}

const registerSchema = z.object({
  fullName: z.string().trim().min(3).max(100),
  email: z.string().trim().toLowerCase().email('e-mail invalide').max(200),
  country: z.string().length(2).toUpperCase(),
  phone: z.string().min(6).max(20),
  password: passwordSchema,
});

router.post('/register', validate(registerSchema), asyncHandler(async (req, res) => {
  const { fullName, email, country, phone, password } = req.body;
  const c = getCountry(country);
  if (!c) throw new AppError(400, 'UNSUPPORTED_COUNTRY', 'Pays non pris en charge');
  const e164 = normalizePhone(country, phone);
  if (!e164) throw new AppError(400, 'INVALID_PHONE', `Numéro invalide pour ${c.name}`);
  const d = db.get();
  if (d.prepare('SELECT 1 FROM users WHERE email=? OR phone=?').get(email, e164)) {
    throw new AppError(409, 'ACCOUNT_EXISTS', 'Un compte existe déjà avec cet e-mail ou ce numéro');
  }
  const id = uuid();
  d.prepare('INSERT INTO users (id, email, phone, full_name, country, password_hash) VALUES (?,?,?,?,?,?)')
    .run(id, email, e164, fullName, country, hashSecret(password));
  const user = d.prepare('SELECT * FROM users WHERE id=?').get(id);
  audit(id, 'auth.register', req.ip);
  notify(id, 'Bienvenue sur AfriCard 🎉', 'Définissez votre code PIN puis vérifiez votre identité pour créer votre première carte virtuelle.');
  res.status(201).json(issueSession(req, res, user));
}));

const loginSchema = z.object({
  login: z.string().trim().min(3).max(200),
  password: z.string().min(1).max(128),
  totp: z.string().regex(/^\d{6}$/).optional(),
  country: z.string().length(2).optional(),
});

router.post('/login', validate(loginSchema), asyncHandler(async (req, res) => {
  const { login, password, totp, country } = req.body;
  const d = db.get();
  let user = d.prepare('SELECT * FROM users WHERE email=?').get(login.toLowerCase());
  if (!user) {
    const e164 = login.startsWith('+') ? `+${login.replace(/\D/g, '')}` : (country ? normalizePhone(country, login) : null);
    if (e164) user = d.prepare('SELECT * FROM users WHERE phone=?').get(e164);
  }
  const fail = () => new AppError(401, 'INVALID_CREDENTIALS', 'Identifiants incorrects');
  if (!user) { verifySecret(password, hashSecret('x')); throw fail(); } // temps constant approximatif
  if (user.locked_until && new Date(user.locked_until) > new Date()) {
    throw new AppError(423, 'ACCOUNT_LOCKED', 'Trop de tentatives : réessayez dans quelques minutes');
  }
  if (!verifySecret(password, user.password_hash)) {
    const attempts = user.failed_logins + 1;
    const lock = attempts >= config.security.maxLoginAttempts ? new Date(Date.now() + config.security.loginLockMinutes * 60000).toISOString() : null;
    d.prepare('UPDATE users SET failed_logins=?, locked_until=? WHERE id=?').run(lock ? 0 : attempts, lock, user.id);
    audit(user.id, 'auth.login_failed', req.ip);
    throw fail();
  }
  if (user.totp_enabled) {
    if (!totp) throw new AppError(401, 'TOTP_REQUIRED', 'Code de double authentification requis');
    if (!verifyTotp(decrypt(user.totp_secret_enc, user.id), totp)) throw new AppError(401, 'INVALID_TOTP', 'Code de double authentification invalide');
  }
  if (user.status === 'closed') throw fail();
  d.prepare('UPDATE users SET failed_logins=0, locked_until=NULL WHERE id=?').run(user.id);
  audit(user.id, 'auth.login', req.ip, { ua: req.get('user-agent') });
  res.json(issueSession(req, res, user));
}));

router.post('/refresh', asyncHandler(async (req, res) => {
  const raw = req.cookies?.[COOKIE];
  if (!raw) throw new AppError(401, 'NO_SESSION', 'Session absente');
  const d = db.get();
  const row = d.prepare('SELECT * FROM refresh_tokens WHERE token_hash=?').get(sha256(raw));
  if (!row) throw new AppError(401, 'NO_SESSION', 'Session invalide');
  if (row.revoked_at) {
    // Réutilisation d'un jeton déjà consommé : vol probable → révocation de toute la famille.
    d.prepare('UPDATE refresh_tokens SET revoked_at=? WHERE family=? AND revoked_at IS NULL').run(db.now(), row.family);
    audit(row.user_id, 'auth.refresh_reuse_detected', req.ip);
    throw new AppError(401, 'SESSION_REVOKED', 'Session révoquée pour des raisons de sécurité');
  }
  if (new Date(row.expires_at) < new Date()) throw new AppError(401, 'SESSION_EXPIRED', 'Session expirée');
  const user = d.prepare('SELECT * FROM users WHERE id=?').get(row.user_id);
  if (!user || user.status === 'closed') throw new AppError(401, 'NO_SESSION', 'Session invalide');
  d.prepare('UPDATE refresh_tokens SET revoked_at=? WHERE id=?').run(db.now(), row.id);
  res.json(issueSession(req, res, user, row.family));
}));

router.post('/logout', (req, res) => {
  const raw = req.cookies?.[COOKIE];
  if (raw) db.get().prepare('UPDATE refresh_tokens SET revoked_at=? WHERE token_hash=? AND revoked_at IS NULL').run(db.now(), sha256(raw));
  res.clearCookie(COOKIE, { path: '/api/auth' });
  res.json({ ok: true });
});

router.post('/logout-all', requireAuth, (req, res) => {
  db.get().prepare('UPDATE refresh_tokens SET revoked_at=? WHERE user_id=? AND revoked_at IS NULL').run(db.now(), req.user.id);
  audit(req.user.id, 'auth.logout_all', req.ip);
  res.clearCookie(COOKIE, { path: '/api/auth' });
  res.json({ ok: true });
});

router.get('/me', requireAuth, (req, res) => {
  res.json({ user: publicUser(req.user), limits: limits.summary(req.user) });
});

module.exports = { router, publicUser, passwordSchema };
