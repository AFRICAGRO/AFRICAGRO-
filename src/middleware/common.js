'use strict';
const db = require('../db');
const { AppError } = require('../lib/errors');
const { sha256 } = require('../lib/crypto');

/** Valide req.body avec un schéma zod et remplace le corps par la version nettoyée. */
const validate = (schema, source = 'body') => (req, _res, next) => {
  const r = schema.safeParse(req[source] ?? {});
  if (!r.success) {
    const issue = r.error.issues[0];
    const field = issue.path.join('.');
    return next(new AppError(400, 'VALIDATION_ERROR', `${field ? `${field} : ` : ''}${issue.message}`, r.error.issues));
  }
  if (source === 'body') req.body = r.data; else req.validated = r.data;
  return next();
};

/**
 * Idempotence des opérations financières : un même en-tête Idempotency-Key renvoie
 * la même réponse et n'exécute jamais deux fois l'opération (anti double-débit).
 * Seules les réponses réussies sont mémorisées : une erreur peut être retentée avec la même clé.
 */
function idempotent(req, res, next) {
  const key = req.get('idempotency-key');
  if (!key) return next();
  if (!/^[\w-]{8,100}$/.test(key)) return next(new AppError(400, 'BAD_IDEMPOTENCY_KEY', 'Idempotency-Key invalide'));
  const d = db.get();
  const { pin, ...bodyWithoutPin } = req.body || {};
  const reqHash = sha256(`${req.method}:${req.originalUrl}:${JSON.stringify(bodyWithoutPin)}`);
  const existing = d.prepare('SELECT * FROM idempotency_keys WHERE key=? AND user_id=?').get(key, req.user.id);
  if (existing) {
    if (existing.request_hash !== reqHash) return next(new AppError(422, 'IDEMPOTENCY_MISMATCH', 'Clé déjà utilisée pour une autre requête'));
    if (existing.response_status == null) return next(new AppError(409, 'IN_PROGRESS', 'Requête identique en cours de traitement'));
    return res.status(existing.response_status).json(JSON.parse(existing.response_body));
  }
  d.prepare('INSERT INTO idempotency_keys (key, user_id, request_hash) VALUES (?,?,?)').run(key, req.user.id, reqHash);
  const json = res.json.bind(res);
  res.json = (body) => {
    if (res.statusCode >= 400) d.prepare('DELETE FROM idempotency_keys WHERE key=? AND user_id=?').run(key, req.user.id);
    else d.prepare('UPDATE idempotency_keys SET response_status=?, response_body=? WHERE key=? AND user_id=?')
      .run(res.statusCode, JSON.stringify(body), key, req.user.id);
    return json(body);
  };
  return next();
}

module.exports = { validate, idempotent };
