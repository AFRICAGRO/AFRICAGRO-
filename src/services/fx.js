'use strict';
// Service de change : cotations verrouillées (quote) puis exécution atomique.
const config = require('../config');
const db = require('../db');
const ledger = require('./ledger');
const money = require('../lib/money');
const { CURRENCIES, CFA_PER_EUR } = require('../data/currencies');
const { uuid } = require('../lib/crypto');
const { AppError } = require('../lib/errors');

const rates = Object.fromEntries(Object.entries(CURRENCIES).map(([k, v]) => [k, v.usdRate]));
let ratesUpdatedAt = new Date().toISOString();
let ratesSource = 'reference';

/** Rafraîchit les cours depuis une API publique (optionnel, FX_LIVE=true). */
async function refreshLiveRates() {
  if (!config.fxLive) return false;
  try {
    const res = await fetch(config.fxLiveUrl, { signal: AbortSignal.timeout(8000) });
    const json = await res.json();
    const live = json.rates || json.conversion_rates;
    if (!live || !live.EUR) return false;
    for (const code of Object.keys(rates)) {
      if (typeof live[code] === 'number' && live[code] > 0) rates[code] = live[code];
    }
    // Les francs CFA restent arrimés à l'euro.
    rates.XOF = rates.EUR * CFA_PER_EUR;
    rates.XAF = rates.EUR * CFA_PER_EUR;
    ratesUpdatedAt = new Date().toISOString();
    ratesSource = 'live';
    return true;
  } catch {
    return false;
  }
}

function getRates() {
  return { base: 'USD', updatedAt: ratesUpdatedAt, source: ratesSource, rates: { ...rates } };
}

function midConvert(minor, from, to) {
  if (from === to) return minor;
  return money.convertMinor(minor, from, to, rates[from], rates[to]);
}

/** Équivalent USD (en centimes) — utilisé pour les plafonds KYC et le scoring de risque. */
function toUsdCents(minor, ccy) {
  return midConvert(minor, ccy, 'USD');
}

function computeForward(fromMinor, from, to, spreadBps) {
  const fee = money.bpsFee(fromMinor, spreadBps);
  const toMinor = midConvert(fromMinor - fee, from, to);
  return { fromMinor, fee, toMinor };
}

/** Calcule une cotation. mode "sell" : montant source fixé ; "buy" : montant cible fixé. */
function price({ from, to, amountMinor, mode = 'sell', spreadBps = config.fees.fxSpreadBps }) {
  from = from.toUpperCase(); to = to.toUpperCase();
  money.currency(from); money.currency(to);
  if (from === to) throw new AppError(400, 'SAME_CURRENCY', 'Les devises source et cible doivent être différentes');
  if (amountMinor <= 0) throw new AppError(400, 'INVALID_AMOUNT', 'Montant invalide');

  let q;
  if (mode === 'sell') {
    q = computeForward(amountMinor, from, to, spreadBps);
  } else {
    // Recherche du plus petit montant source qui fournit au moins `amountMinor` en cible.
    const netNeeded = midConvert(amountMinor, to, from) + 1;
    let fromMinor = Math.ceil((netNeeded * 10000) / (10000 - spreadBps));
    q = computeForward(fromMinor, from, to, spreadBps);
    while (q.toMinor < amountMinor) { fromMinor += 1; q = computeForward(fromMinor, from, to, spreadBps); }
  }
  if (q.toMinor <= 0) throw new AppError(400, 'AMOUNT_TOO_SMALL', 'Montant trop faible pour être converti');

  const effective = Number(money.toMajor(q.toMinor, to)) / Number(money.toMajor(q.fromMinor, from));
  return { from, to, ...q, rate: effective.toPrecision(8), midRate: (rates[to] / rates[from]).toPrecision(8) };
}

function createQuote(userId, params) {
  const p = price(params);
  const id = uuid();
  const expiresAt = new Date(Date.now() + config.fxQuoteTtlSec * 1000).toISOString();
  db.get().prepare(`INSERT INTO fx_quotes (id, user_id, from_currency, to_currency, from_amount, to_amount, fee, rate, expires_at)
                    VALUES (?,?,?,?,?,?,?,?,?)`)
    .run(id, userId, p.from, p.to, p.fromMinor, p.toMinor, p.fee, p.rate, expiresAt);
  return { id, ...p, expiresAt };
}

/** Écritures comptables d'un change (réutilisées par d'autres services). */
function fxEntries(sourceAccount, targetAccount, fromMinor, fee, toMinor, from, to) {
  return [
    { account: sourceAccount, amount: -fromMinor },
    { account: ledger.system('fees', from), amount: fee },
    { account: ledger.system('fx_pool', from), amount: fromMinor - fee },
    { account: ledger.system('fx_pool', to), amount: -toMinor },
    { account: targetAccount, amount: toMinor },
  ];
}

function executeQuote(userId, quoteId) {
  return db.tx((d) => {
    const q = d.prepare('SELECT * FROM fx_quotes WHERE id=? AND user_id=?').get(quoteId, userId);
    if (!q) throw new AppError(404, 'QUOTE_NOT_FOUND', 'Cotation introuvable');
    if (q.used_at) throw new AppError(409, 'QUOTE_USED', 'Cotation déjà utilisée');
    if (new Date(q.expires_at) < new Date()) throw new AppError(410, 'QUOTE_EXPIRED', 'Cotation expirée, veuillez en demander une nouvelle');
    d.prepare('UPDATE fx_quotes SET used_at=? WHERE id=?').run(db.now(), q.id);

    return ledger.post({
      userId, type: 'fx', amount: q.from_amount, currency: q.from_currency, fee: q.fee,
      description: `Conversion ${money.format(q.from_amount, q.from_currency)} → ${money.format(q.to_amount, q.to_currency)}`,
      reference: q.id,
      metadata: { to_amount: q.to_amount, to_currency: q.to_currency, rate: q.rate },
      entries: fxEntries(ledger.wallet(userId, q.from_currency), ledger.wallet(userId, q.to_currency),
        q.from_amount, q.fee, q.to_amount, q.from_currency, q.to_currency),
    });
  });
}

module.exports = { getRates, refreshLiveRates, midConvert, toUsdCents, price, createQuote, executeQuote, fxEntries };
