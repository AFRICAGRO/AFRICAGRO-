'use strict';
// Plafonds réglementaires par niveau KYC (montants en centimes USD équivalents).
// Inspirés des approches graduées des régulateurs (BCEAO, BEAC, CBN…) : à ajuster
// avec votre conformité selon la licence et le partenaire émetteur.
const db = require('../db');
const fx = require('./fx');
const { AppError } = require('../lib/errors');

const TIERS = {
  0: { name: 'Basique (non vérifié)', perTx: 100_00, monthly: 300_00, maxCards: 0, withdrawals: false,
       description: 'Dépôts et conversions limités. Vérifiez votre identité pour créer des cartes.' },
  1: { name: 'Vérifié (pièce d’identité)', perTx: 1_000_00, monthly: 3_000_00, maxCards: 3, withdrawals: true,
       description: 'Cartes virtuelles, retraits et transferts.' },
  2: { name: 'Premium (vérification renforcée)', perTx: 10_000_00, monthly: 25_000_00, maxCards: 10, withdrawals: true,
       description: 'Plafonds élevés pour commerçants, freelances et importateurs.' },
};

const COUNTED_TYPES = ['deposit', 'withdrawal', 'p2p'];

function monthlyVolumeUsdCents(userId) {
  const start = new Date();
  start.setUTCDate(1); start.setUTCHours(0, 0, 0, 0);
  const rows = db.get().prepare(
    `SELECT amount, currency FROM transactions
     WHERE user_id=? AND status IN ('completed','pending') AND created_at >= ?
       AND type IN (${COUNTED_TYPES.map(() => '?').join(',')})
       AND NOT (type='p2p' AND json_extract(metadata,'$.direction')='in')`,
  ).all(userId, start.toISOString(), ...COUNTED_TYPES);
  return rows.reduce((s, r) => s + fx.toUsdCents(r.amount, r.currency), 0);
}

/** Lève une erreur si l'opération dépasse les plafonds du niveau KYC. */
function assertWithinLimits(user, amountMinor, currency, { kind } = {}) {
  const tier = TIERS[user.kyc_level] || TIERS[0];
  const usd = fx.toUsdCents(amountMinor, currency);
  if (kind === 'withdrawal' && !tier.withdrawals) {
    throw new AppError(403, 'KYC_REQUIRED', 'Vérifiez votre identité pour effectuer des retraits');
  }
  if (usd > tier.perTx) {
    throw new AppError(403, 'LIMIT_PER_TX', `Plafond par opération dépassé pour le niveau « ${tier.name} » (${(tier.perTx / 100).toFixed(0)} USD)`);
  }
  const used = monthlyVolumeUsdCents(user.id);
  if (used + usd > tier.monthly) {
    throw new AppError(403, 'LIMIT_MONTHLY', `Plafond mensuel atteint pour le niveau « ${tier.name} » (${(tier.monthly / 100).toFixed(0)} USD)`);
  }
}

function summary(user) {
  const tier = TIERS[user.kyc_level] || TIERS[0];
  const used = monthlyVolumeUsdCents(user.id);
  return { level: user.kyc_level, ...tier, monthlyUsedUsdCents: used, monthlyRemainingUsdCents: Math.max(0, tier.monthly - used) };
}

module.exports = { TIERS, assertWithinLimits, summary, monthlyVolumeUsdCents };
