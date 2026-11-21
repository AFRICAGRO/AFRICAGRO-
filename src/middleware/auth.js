'use strict';
const jwt = require('jsonwebtoken');
const config = require('../config');
const db = require('../db');
const { AppError } = require('../lib/errors');
const { verifySecret } = require('../lib/crypto');
const { audit, notify } = require('../services/notify');

const CONSENT_EXEMPT = /^\/api\/(auth|privacy|consents|meta)(\/|$)/;

/** L'utilisateur a-t-il accepté les versions en vigueur de la politique de confidentialité et des CGU ? */
function missingConsents(userId) {
  const d = db.get();
  const has = (doc, version) => d.prepare('SELECT 1 FROM consents WHERE user_id=? AND document=? AND version=? AND granted=1').get(userId, doc, version);
  const missing = [];
  if (!has('privacy', config.legal.privacyVersion)) missing.push('privacy');
  if (!has('terms', config.legal.termsVersion)) missing.push('terms');
  return missing;
}

function signAccessToken(user) {
  return jwt.sign({ sub: user.id, role: user.role }, config.jwtSecret, {
    algorithm: 'HS256', expiresIn: config.accessTokenTtlSec, issuer: 'africard', audience: 'africard-api',
  });
}

function requireAuth(req, _res, next) {
  const h = req.get('authorization') || '';
  const token = h.startsWith('Bearer ') ? h.slice(7) : null;
  if (!token) return next(new AppError(401, 'UNAUTHENTICATED', 'Authentification requise'));
  try {
    const payload = jwt.verify(token, config.jwtSecret, { algorithms: ['HS256'], issuer: 'africard', audience: 'africard-api' });
    const user = db.get().prepare('SELECT * FROM users WHERE id=?').get(payload.sub);
    if (!user || user.status === 'closed') return next(new AppError(401, 'UNAUTHENTICATED', 'Session invalide'));
    if (user.status === 'frozen') return next(new AppError(403, 'ACCOUNT_FROZEN', 'Compte suspendu : contactez le support'));
    req.user = user;
  } catch {
    return next(new AppError(401, 'TOKEN_EXPIRED', 'Session expirée'));
  }
  // Acceptation obligatoire des documents juridiques en vigueur avant toute opération.
  if (!CONSENT_EXEMPT.test(req.originalUrl)) {
    const missing = missingConsents(req.user.id);
    if (missing.length) return next(new AppError(428, 'CONSENT_REQUIRED', 'Veuillez accepter la politique de confidentialité et les conditions d’utilisation en vigueur', { missing }));
  }
  return next();
}

function requireAdmin(req, _res, next) {
  if (req.user?.role !== 'admin') return next(new AppError(403, 'FORBIDDEN', 'Accès réservé aux administrateurs'));
  return next();
}

/** Exige le code PIN de transaction (corps `pin` ou en-tête X-Transaction-Pin), avec verrouillage. */
function requirePin(req, _res, next) {
  const user = req.user;
  if (!user.pin_hash) return next(new AppError(403, 'PIN_NOT_SET', 'Définissez d’abord votre code PIN de transaction'));
  if (user.pin_locked_until && new Date(user.pin_locked_until) > new Date()) {
    return next(new AppError(423, 'PIN_LOCKED', 'Code PIN bloqué temporairement après plusieurs erreurs'));
  }
  const pin = req.body?.pin ?? req.get('x-transaction-pin');
  const d = db.get();
  if (!pin || !verifySecret(String(pin), user.pin_hash)) {
    const attempts = user.failed_pins + 1;
    const lock = attempts >= config.security.maxPinAttempts
      ? new Date(Date.now() + config.security.pinLockMinutes * 60000).toISOString() : null;
    d.prepare('UPDATE users SET failed_pins=?, pin_locked_until=? WHERE id=?').run(lock ? 0 : attempts, lock, user.id);
    audit(user.id, 'pin.failed', req.ip, { attempts });
    if (lock) notify(user.id, 'Code PIN bloqué', 'Votre code PIN a été bloqué 30 minutes après 5 erreurs. Si ce n’est pas vous, changez votre mot de passe immédiatement.', { category: 'security' });
    const left = config.security.maxPinAttempts - attempts;
    return next(new AppError(403, 'INVALID_PIN', lock ? 'Code PIN bloqué pour 30 minutes' : `Code PIN incorrect (${left} essai(s) restant(s))`));
  }
  if (user.failed_pins) d.prepare('UPDATE users SET failed_pins=0, pin_locked_until=NULL WHERE id=?').run(user.id);
  return next();
}

/** Refuse les requêtes provenant d'une IP bloquée par l'agent de sécurité. */
function blockIps(req, _res, next) {
  const b = db.get().prepare('SELECT expires_at FROM ip_blocks WHERE ip=? AND expires_at > ?').get(req.ip, db.now());
  if (b) return next(new AppError(429, 'IP_BLOCKED', 'Trop de tentatives depuis votre réseau. Réessayez dans une heure.'));
  return next();
}

module.exports = { signAccessToken, requireAuth, requireAdmin, requirePin, blockIps, missingConsents };
