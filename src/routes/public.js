'use strict';
// Endpoints publics (référentiels), webhooks fournisseurs et outils sandbox.
const express = require('express');
const { z } = require('zod');
const config = require('../config');
const fx = require('../services/fx');
const mm = require('../services/mobileMoney');
const cards = require('../services/cards');
const limits = require('../services/limits');
const { CURRENCIES, CARD_CURRENCIES } = require('../data/currencies');
const { publicCountries } = require('../data/countries');
const { PROVIDERS } = require('../providers/mobileMoney');
const { validate } = require('../middleware/common');
const { requireAuth } = require('../middleware/auth');
const { AppError, asyncHandler } = require('../lib/errors');
const { uuid } = require('../lib/crypto');

const meta = express.Router();
meta.get('/countries', (_req, res) => res.json({ countries: publicCountries() }));
meta.get('/currencies', (_req, res) => res.json({
  currencies: Object.entries(CURRENCIES).map(([code, c]) => ({ code, name: c.name, symbol: c.symbol, decimals: c.decimals, african: Boolean(c.african) })),
  cardCurrencies: CARD_CURRENCIES,
}));
meta.get('/rates', (_req, res) => res.json(fx.getRates()));
meta.get('/card-categories', (_req, res) => res.json({ categories: cards.CATEGORIES }));
meta.get('/tiers', (_req, res) => res.json({ tiers: limits.TIERS }));
meta.get('/fees', (_req, res) => res.json({ ...config.fees, modes: { mobileMoney: config.mobileMoneyMode, cardIssuer: config.cardIssuerMode } }));

// ------------------------------------------------------------------ Webhooks
const webhooks = express.Router();
webhooks.post('/mobile-money/:provider', asyncHandler(async (req, res) => {
  const r = await mm.handleWebhook(req.params.provider, req);
  res.json(r);
}));

// ------------------------------------------------------------------ Sandbox (désactivé dès qu'un fournisseur réel est branché)
const sandbox = express.Router();
sandbox.use((_req, _res, next) => {
  if (config.mobileMoneyMode === 'live' || config.cardIssuerMode !== 'sandbox') return next(new AppError(404, 'NOT_FOUND', 'Introuvable'));
  return next();
});

/** Simule la validation (ou le refus) du paiement par le client sur son téléphone → webhook signé. */
sandbox.post('/mobile-money/:id/confirm', requireAuth, validate(z.object({ success: z.boolean().default(true) })), asyncHandler(async (req, res) => {
  const op = mm.getOp(req.params.id);
  if (!op || op.user_id !== req.user.id || op.provider !== 'sandbox') throw new AppError(404, 'OP_NOT_FOUND', 'Opération introuvable');
  const payload = JSON.stringify({ event_id: uuid(), op_id: op.id, status: req.body.success ? 'completed' : 'failed',
    reason: req.body.success ? undefined : 'Paiement annulé par le client' });
  // Passe par le même chemin de vérification que les vrais webhooks.
  const fakeReq = { rawBody: payload, body: JSON.parse(payload), get: (h) => (h.toLowerCase() === 'x-sandbox-signature' ? PROVIDERS.sandbox.sign(payload) : undefined) };
  await mm.handleWebhook('sandbox', fakeReq);
  res.json(mm.publicOp(mm.getOp(op.id)));
}));

/** Simule un paiement marchand (le réseau Visa/Mastercard demande une autorisation). */
sandbox.post('/card-authorizations', validate(z.object({
  pan: z.string().min(12).max(23),
  cvv: z.string().regex(/^\d{3,4}$/),
  expMonth: z.coerce.number().int().min(1).max(12),
  expYear: z.coerce.number().int().min(2000).max(2100),
  amount: z.union([z.string(), z.number()]).transform(String),
  currency: z.string().length(3),
  merchantName: z.string().trim().min(2).max(80),
  merchantCategory: z.string().max(30).default('other'),
  merchantCountry: z.string().length(2).default('US'),
})), (req, res) => {
  res.json(cards.authorize({ ...req.body }));
});

sandbox.post('/card-authorizations/:id/refund', (req, res) => res.json(cards.refund(req.params.id)));

module.exports = { meta, webhooks, sandbox };
