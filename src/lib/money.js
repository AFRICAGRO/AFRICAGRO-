'use strict';
// Toutes les sommes sont manipulées en unités mineures entières (centimes, ou francs pour XOF).
// Aucun calcul monétaire ne passe par des flottants : conversions en BigInt.
const { CURRENCIES } = require('../data/currencies');
const { AppError } = require('./errors');

function currency(code) {
  const c = CURRENCIES[String(code || '').toUpperCase()];
  if (!c) throw new AppError(400, 'UNSUPPORTED_CURRENCY', `Devise non prise en charge : ${code}`);
  return c;
}

function isCurrency(code) {
  return Boolean(CURRENCIES[String(code || '').toUpperCase()]);
}

/** "1234.56" (unités majeures) -> 123456 (unités mineures). Refuse les décimales en trop. */
function toMinor(amount, code) {
  const { decimals } = currency(code);
  const s = String(amount).trim();
  if (!/^\d+(\.\d+)?$/.test(s)) throw new AppError(400, 'INVALID_AMOUNT', 'Montant invalide');
  const [intPart, frac = ''] = s.split('.');
  if (frac.length > decimals) {
    throw new AppError(400, 'INVALID_AMOUNT', `${code} accepte au plus ${decimals} décimale(s)`);
  }
  const minor = BigInt(intPart) * 10n ** BigInt(decimals) + BigInt((frac + '0'.repeat(decimals)).slice(0, decimals) || '0');
  if (minor > BigInt(Number.MAX_SAFE_INTEGER)) throw new AppError(400, 'INVALID_AMOUNT', 'Montant trop élevé');
  return Number(minor);
}

/** 123456 -> "1234.56" */
function toMajor(minor, code) {
  const { decimals } = currency(code);
  const neg = minor < 0;
  const abs = BigInt(Math.abs(minor));
  if (decimals === 0) return `${neg ? '-' : ''}${abs}`;
  const div = 10n ** BigInt(decimals);
  return `${neg ? '-' : ''}${abs / div}.${(abs % div).toString().padStart(decimals, '0')}`;
}

function format(minor, code) {
  const c = currency(code);
  const n = Number(toMajor(minor, code));
  return `${n.toLocaleString('fr-FR', { minimumFractionDigits: c.decimals, maximumFractionDigits: c.decimals })} ${c.symbol}`;
}

/** Frais en points de base, arrondis au supérieur (jamais de frais négatifs). */
function bpsFee(minor, bps) {
  if (bps <= 0) return 0;
  return Number((BigInt(minor) * BigInt(bps) + 9999n) / 10000n);
}

const RATE_SCALE = 10n ** 12n;
/** Convertit un cours décimal (nombre) en BigInt mis à l'échelle 1e12. */
function scaleRate(rate) {
  return BigInt(Math.round(rate * 1e6)) * 10n ** 6n;
}

/**
 * Convertit `minor` de `from` vers `to` selon des cours "unités par USD".
 * Arrondi à l'unité mineure inférieure (au bénéfice de la plateforme, plafonné à 1 unité).
 */
function convertMinor(minor, from, to, fromPerUsd, toPerUsd) {
  const dFrom = BigInt(currency(from).decimals);
  const dTo = BigInt(currency(to).decimals);
  const num = BigInt(minor) * scaleRate(toPerUsd) * 10n ** dTo;
  const den = scaleRate(fromPerUsd) * 10n ** dFrom;
  return Number(num / den);
}

module.exports = { currency, isCurrency, toMinor, toMajor, format, bpsFee, convertMinor, scaleRate, RATE_SCALE };
