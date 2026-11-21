'use strict';
const express = require('express');
const { z } = require('zod');
const cards = require('../services/cards');
const { CARD_CURRENCIES } = require('../data/currencies');
const { validate, idempotent } = require('../middleware/common');
const { requireAuth, requirePin } = require('../middleware/auth');
const { audit } = require('../services/notify');
const { assertOperational } = require('../services/system');

const router = express.Router();
router.use(requireAuth);

const amountStr = z.union([z.string(), z.number()]).transform(String).refine((s) => /^\d+(\.\d+)?$/.test(s) && Number(s) > 0, 'montant invalide');
const optAmount = z.union([amountStr, z.null()]).optional();

router.get('/', (req, res) => res.json({ cards: cards.list(req.user) }));

router.post('/', assertOperational, idempotent, requirePin, validate(z.object({
  label: z.string().trim().min(1).max(40).default('Ma carte'),
  brand: z.enum(['visa', 'mastercard']).default('visa'),
  currency: z.enum(CARD_CURRENCIES).default('USD'),
  singleUse: z.boolean().default(false),
  lockToFirstMerchant: z.boolean().default(false),
  perTxLimit: optAmount,
  monthlyLimit: optAmount,
  initialAmount: optAmount,
  fundingCurrency: z.string().length(3).toUpperCase().optional(),
})), (req, res) => {
  const card = cards.createCard(req.user, req.body);
  audit(req.user.id, 'card.created', req.ip, { card: card.id });
  res.status(201).json({ card });
});

router.get('/:id', (req, res) => res.json({ card: cards.publicCard(cards.getCard(req.user.id, req.params.id)) }));

router.get('/:id/authorizations', (req, res) => res.json({ authorizations: cards.authorizations(req.user, req.params.id) }));

const loadSchema = z.object({ amount: amountStr, sourceCurrency: z.string().length(3).toUpperCase().optional() });

router.post('/:id/load/preview', validate(loadSchema), (req, res) => {
  res.json(cards.previewLoad(req.user, req.params.id, req.body.amount, req.body.sourceCurrency));
});

router.post('/:id/load', assertOperational, idempotent, validate(loadSchema), (req, res) => {
  res.json({ card: cards.loadCard(req.user, req.params.id, req.body.amount, req.body.sourceCurrency) });
});

router.post('/:id/unload', assertOperational, idempotent, validate(z.object({ amount: amountStr })), (req, res) => {
  res.json({ card: cards.unloadCard(req.user, req.params.id, req.body.amount) });
});

router.post('/:id/freeze', (req, res) => {
  audit(req.user.id, 'card.frozen', req.ip, { card: req.params.id });
  res.json({ card: cards.setStatus(req.user, req.params.id, 'frozen') });
});

router.post('/:id/unfreeze', requirePin, (req, res) => {
  audit(req.user.id, 'card.unfrozen', req.ip, { card: req.params.id });
  res.json({ card: cards.setStatus(req.user, req.params.id, 'active') });
});

router.post('/:id/terminate', requirePin, (req, res) => {
  audit(req.user.id, 'card.terminated', req.ip, { card: req.params.id });
  res.json({ card: cards.setStatus(req.user, req.params.id, 'terminated') });
});

router.patch('/:id/controls', validate(z.object({
  label: z.string().trim().min(1).max(40).optional(),
  perTxLimit: optAmount,
  monthlyLimit: optAmount,
  blockedCategories: z.array(z.string()).max(20).optional(),
  allowedCountries: z.union([z.array(z.string().length(2)).max(250), z.null()]).optional(),
  merchantLock: z.union([z.string().trim().toLowerCase().max(80), z.null()]).optional(),
})), (req, res) => {
  res.json({ card: cards.updateControls(req.user, req.params.id, req.body) });
});

router.post('/:id/reveal', requirePin, (req, res) => {
  audit(req.user.id, 'card.revealed', req.ip, { card: req.params.id });
  res.set('Cache-Control', 'no-store');
  res.json(cards.reveal(req.user, req.params.id));
});

module.exports = { router };
