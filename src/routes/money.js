'use strict';
// Portefeuilles multi-devises, change, dépôts/retraits Mobile Money et transferts entre membres.
const express = require('express');
const { z } = require('zod');
const config = require('../config');
const db = require('../db');
const money = require('../lib/money');
const ledger = require('../services/ledger');
const fx = require('../services/fx');
const limits = require('../services/limits');
const mm = require('../services/mobileMoney');
const { validate, idempotent } = require('../middleware/common');
const { requireAuth, requirePin } = require('../middleware/auth');
const { assertOperational } = require('../services/system');
const { AppError, asyncHandler } = require('../lib/errors');
const { notify, audit } = require('../services/notify');
const { normalizePhone } = require('../data/countries');

const router = express.Router();
router.use(requireAuth);

const amountStr = z.union([z.string(), z.number()]).transform(String).refine((s) => /^\d+(\.\d+)?$/.test(s) && Number(s) > 0, 'montant invalide');
const ccy = z.string().length(3).toUpperCase().refine(money.isCurrency, 'devise non prise en charge');

// ------------------------------------------------------------------ Portefeuilles
router.get('/wallets', (req, res) => {
  const pref = req.user.preferred_currency;
  const wallets = ledger.userWallets(req.user.id);
  let total = 0;
  const out = wallets.map((w) => {
    const eq = fx.midConvert(w.balance, w.currency, pref);
    total += eq;
    return { currency: w.currency, balance: money.toMajor(w.balance, w.currency), formatted: money.format(w.balance, w.currency),
      equivalent: money.toMajor(eq, pref) };
  });
  const cards = db.get().prepare(`SELECT a.balance, a.currency FROM accounts a JOIN cards c ON c.id=a.owner_id
                                  WHERE a.owner_type='card' AND c.user_id=? AND c.status!='terminated'`).all(req.user.id);
  const cardsTotal = cards.reduce((s, c) => s + fx.midConvert(c.balance, c.currency, pref), 0);
  res.json({ preferredCurrency: pref, wallets: out, totalWallets: money.toMajor(total, pref),
    totalCards: money.toMajor(cardsTotal, pref), total: money.toMajor(total + cardsTotal, pref) });
});

// ------------------------------------------------------------------ Change
const quoteSchema = z.object({ from: ccy, to: ccy, amount: amountStr, mode: z.enum(['sell', 'buy']).default('sell') });

router.post('/fx/quote', validate(quoteSchema), (req, res) => {
  const { from, to, amount, mode } = req.body;
  const amountMinor = money.toMinor(amount, mode === 'sell' ? from : to);
  const q = fx.createQuote(req.user.id, { from, to, amountMinor, mode });
  res.json({ id: q.id, from, to, fromAmount: money.toMajor(q.fromMinor, from), toAmount: money.toMajor(q.toMinor, to),
    fee: money.toMajor(q.fee, from), rate: q.rate, midRate: q.midRate, expiresAt: q.expiresAt,
    available: money.toMajor(ledger.wallet(req.user.id, from).balance, from) });
});

router.post('/fx/execute', assertOperational, idempotent, validate(z.object({ quoteId: z.string().uuid() })), (req, res) => {
  const tx = fx.executeQuote(req.user.id, req.body.quoteId);
  audit(req.user.id, 'fx.execute', req.ip, { tx: tx.id });
  res.json({ ok: true, transactionId: tx.id });
});

// ------------------------------------------------------------------ Mobile Money
const mmSchema = z.object({
  country: z.string().length(2).toUpperCase(),
  operator: z.string().min(2).max(40),
  phone: z.string().min(6).max(20),
  amount: amountStr,
});

router.post('/deposits/preview', validate(mmSchema), (req, res) => {
  const { minor, currency } = mm.validate(req.body);
  const fee = mm.quoteFee('deposit', minor);
  res.json({ amount: money.toMajor(minor, currency), fee: money.toMajor(fee, currency), net: money.toMajor(minor - fee, currency), currency,
    usdEquivalent: money.toMajor(fx.midConvert(minor - fee, currency, 'USD'), 'USD') });
});

router.post('/deposits', assertOperational, idempotent, validate(mmSchema), asyncHandler(async (req, res) => {
  const r = await mm.initiateDeposit(req.user, req.body);
  audit(req.user.id, 'deposit.initiated', req.ip, { op: r.id });
  res.status(201).json(r);
}));

router.get('/mobile-money', (req, res) => {
  const rows = db.get().prepare('SELECT * FROM mobile_money_ops WHERE user_id=? ORDER BY created_at DESC LIMIT 50').all(req.user.id);
  res.json({ operations: rows.map(mm.publicOp) });
});

router.get('/mobile-money/:id', (req, res) => {
  const op = mm.getOp(req.params.id);
  if (!op || op.user_id !== req.user.id) throw new AppError(404, 'OP_NOT_FOUND', 'Opération introuvable');
  res.json(mm.publicOp(op));
});

router.post('/withdrawals/preview', validate(mmSchema), (req, res) => {
  const { minor, currency } = mm.validate(req.body);
  const fee = mm.quoteFee('withdrawal', minor);
  res.json({ amount: money.toMajor(minor, currency), fee: money.toMajor(fee, currency), received: money.toMajor(minor - fee, currency), currency,
    available: money.toMajor(ledger.wallet(req.user.id, currency).balance, currency) });
});

router.post('/withdrawals', assertOperational, idempotent, requirePin, validate(mmSchema), asyncHandler(async (req, res) => {
  const r = await mm.initiateWithdrawal(req.user, req.body);
  audit(req.user.id, 'withdrawal.initiated', req.ip, { op: r.id });
  res.status(201).json(r);
}));

// ------------------------------------------------------------------ Transferts entre membres (P2P)
router.post('/transfers', assertOperational, idempotent, requirePin, validate(z.object({
  recipient: z.string().trim().min(3).max(200),         // e-mail ou numéro (+225…)
  recipientCountry: z.string().length(2).toUpperCase().optional(),
  currency: ccy,
  amount: amountStr,
  note: z.string().trim().max(140).optional(),
})), (req, res) => {
  const { recipient, recipientCountry, currency, amount, note } = req.body;
  const d = db.get();
  let to = d.prepare('SELECT * FROM users WHERE email=?').get(recipient.toLowerCase());
  if (!to) {
    const phone = recipient.startsWith('+') ? `+${recipient.replace(/\D/g, '')}` : normalizePhone(recipientCountry || req.user.country, recipient);
    if (phone) to = d.prepare('SELECT * FROM users WHERE phone=?').get(phone);
  }
  if (!to || to.status !== 'active') throw new AppError(404, 'RECIPIENT_NOT_FOUND', 'Destinataire introuvable sur AfriCard');
  if (to.id === req.user.id) throw new AppError(400, 'SELF_TRANSFER', 'Impossible de vous envoyer de l’argent à vous-même');
  const minor = money.toMinor(amount, currency);
  limits.assertWithinLimits(req.user, minor, currency, { kind: 'p2p' });
  const fee = money.bpsFee(minor, config.fees.p2pBps);

  const result = db.tx(() => {
    const out = ledger.post({ userId: req.user.id, type: 'p2p', amount: minor, currency, fee,
      description: `Envoi à ${to.full_name}${note ? ` — ${note}` : ''}`, metadata: { direction: 'out', counterparty: to.id },
      entries: [
        { account: ledger.wallet(req.user.id, currency), amount: -(minor + fee) },
        { account: ledger.system('fees', currency), amount: fee },
        { account: ledger.wallet(to.id, currency), amount: minor },
      ] });
    ledger.post({ userId: to.id, type: 'p2p', amount: minor, currency, description: `Reçu de ${req.user.full_name}${note ? ` — ${note}` : ''}`,
      reference: out.id, metadata: { direction: 'in', counterparty: req.user.id } });
    return out;
  });
  notify(to.id, 'Argent reçu 💸', `${req.user.full_name} vous a envoyé ${money.format(minor, currency)}.`);
  audit(req.user.id, 'p2p.sent', req.ip, { to: to.id, tx: result.id });
  res.status(201).json({ ok: true, transactionId: result.id, recipient: to.full_name });
});

module.exports = { router };
