'use strict';
const jwt = require('jsonwebtoken');
const config = require('../config');
const db = require('../db');
const { AppError } = require('../lib/errors');
const { verifySecret } = require('../lib/crypto');
const { audit } = require('../services/notify');

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
    return next();
  } catch {
    return next(new AppError(401, 'TOKEN_EXPIRED', 'Session expirée'));
  }
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
    const left = config.security.maxPinAttempts - attempts;
    return next(new AppError(403, 'INVALID_PIN', lock ? 'Code PIN bloqué pour 30 minutes' : `Code PIN incorrect (${left} essai(s) restant(s))`));
  }
  if (user.failed_pins) d.prepare('UPDATE users SET failed_pins=0, pin_locked_until=NULL WHERE id=?').run(user.id);
  return next();
}

module.exports = { signAccessToken, requireAuth, requireAdmin, requirePin };
