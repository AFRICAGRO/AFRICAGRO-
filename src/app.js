'use strict';
const path = require('node:path');
const express = require('express');
const helmet = require('helmet');
const cookieParser = require('cookie-parser');
const rateLimit = require('express-rate-limit');
const config = require('./config');
const { AppError } = require('./lib/errors');
const { recordError } = require('./services/system');
const { blockIps } = require('./middleware/auth');

function createApp() {
  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', config.isProd ? 1 : false);

  app.use(helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'"],
        styleSrc: ["'self'"],
        imgSrc: ["'self'", 'data:'],
        connectSrc: ["'self'"],
        frameAncestors: ["'none'"],
        formAction: ["'self'"],
        upgradeInsecureRequests: config.isProd ? [] : null,
      },
    },
    strictTransportSecurity: config.isProd ? { maxAge: 63072000, includeSubDomains: true, preload: true } : false,
    referrerPolicy: { policy: 'no-referrer' },
  }));

  app.use(express.json({
    limit: '100kb',
    verify: (req, _res, buf) => { req.rawBody = buf.toString('utf8'); }, // pour vérifier les signatures de webhooks
  }));
  app.use(express.urlencoded({ extended: false, limit: '50kb' }));
  app.use(cookieParser());

  const isTest = config.env === 'test';
  const api = express.Router();
  api.use(rateLimit({ windowMs: 60_000, limit: isTest ? 10_000 : 300, standardHeaders: 'draft-7', legacyHeaders: false }));
  const authLimiter = rateLimit({ windowMs: 15 * 60_000, limit: isTest ? 10_000 : 30, standardHeaders: 'draft-7', legacyHeaders: false,
    message: { error: { code: 'RATE_LIMITED', message: 'Trop de tentatives, réessayez plus tard' } } });

  api.get('/health', (_req, res) => res.json({ ok: true, service: 'africard', modes: { mobileMoney: config.mobileMoneyMode, cardIssuer: config.cardIssuerMode } }));
  api.use(['/auth/login', '/auth/register', '/auth/password'], blockIps, authLimiter);
  api.use('/auth', require('./routes/auth').router);
  const pub = require('./routes/public');
  api.use('/meta', pub.meta);
  api.use('/webhooks', pub.webhooks);
  api.use('/sandbox', pub.sandbox);
  api.use('/cards', require('./routes/cards').router);
  api.use('/admin', require('./routes/admin').router);
  api.use('/', require('./routes/privacy').router);
  api.use('/', require('./routes/money').router);
  api.use('/', require('./routes/account').router);
  app.use('/api', api);

  app.use(express.static(path.join(__dirname, '..', 'public'), { maxAge: config.isProd ? '1h' : 0, index: 'index.html' }));

  app.use('/api', (_req, _res, next) => next(new AppError(404, 'NOT_FOUND', 'Ressource introuvable')));

  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, _next) => {
    if (err.type === 'entity.parse.failed') err = new AppError(400, 'BAD_JSON', 'Corps JSON invalide');
    if (err.type === 'entity.too.large') err = new AppError(413, 'TOO_LARGE', 'Requête trop volumineuse');
    const status = err instanceof AppError ? err.status : 500;
    if (status >= 500) recordError(err, `${req.method} ${req.route?.path || req.originalUrl.split('?')[0]}`);
    if (status >= 500) console.error(`[${new Date().toISOString()}] ${req.method} ${req.originalUrl}`, err);
    const body = { code: err.code || 'INTERNAL_ERROR', message: status >= 500 ? 'Erreur interne, veuillez réessayer' : err.message };
    if (err.code === 'CONSENT_REQUIRED') body.details = err.details;
    res.status(status).json({ error: body });
  });

  return app;
}

module.exports = { createApp };
