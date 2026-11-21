'use strict';
// Indicateurs système (mode protégé) et capture des erreurs pour l'agent de fiabilité.
const db = require('../db');
const { sha256 } = require('../lib/crypto');
const { AppError } = require('../lib/errors');

function getFlag(key) {
  return db.get().prepare('SELECT value FROM system_flags WHERE key=?').get(key)?.value ?? null;
}

function setFlag(key, value) {
  if (value === null) {
    db.get().prepare('DELETE FROM system_flags WHERE key=?').run(key);
    return;
  }
  db.get().prepare(`INSERT INTO system_flags (key, value, updated_at) VALUES (?,?,strftime('%Y-%m-%dT%H:%M:%fZ','now'))
                    ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at`).run(key, String(value));
}

/** Le « mode protégé » bloque tout mouvement d'argent sortant tant qu'une anomalie comptable n'est pas résolue. */
function financialLock() {
  return getFlag('financial_lock');
}

function assertOperational(_req, _res, next) {
  const lock = financialLock();
  if (lock) return next(new AppError(503, 'MAINTENANCE', 'Service momentanément indisponible pour vérification de sécurité. Vos fonds sont protégés.'));
  return next();
}

/** Enregistre une erreur serveur (regroupée par empreinte) pour détection d'anomalies. */
function recordError(err, route = null) {
  try {
    const frame = String(err?.stack || '').split('\n').find((l) => l.includes('/src/')) || '';
    const fingerprint = sha256(`${err?.name}:${err?.message}:${frame.trim()}`).slice(0, 16);
    db.get().prepare('INSERT INTO error_events (fingerprint, message, stack, route) VALUES (?,?,?,?)')
      .run(fingerprint, String(err?.message || err).slice(0, 500), String(err?.stack || '').slice(0, 4000), route);
  } catch { /* ne jamais planter en enregistrant une erreur */ }
}

module.exports = { getFlag, setFlag, financialLock, assertOperational, recordError };
