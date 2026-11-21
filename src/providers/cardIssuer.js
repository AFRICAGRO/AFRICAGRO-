'use strict';
// Adaptateur d'émission de cartes.
// "sandbox" génère des numéros de test valides (algorithme de Luhn) sur des BIN de test.
// En production, une carte réelle est émise par un partenaire titulaire d'une licence
// Visa/Mastercard (BIN sponsor) — remplacer `issue()` par l'appel à son API
// (ex. Marqeta, Union54, Bridgecard, Sudo Africa, Maplerad, Stripe Issuing selon les pays).
const crypto = require('node:crypto');
const config = require('../config');
const { AppError } = require('../lib/errors');

const TEST_BINS = { visa: '400017', mastercard: '520082' };

function luhnCheckDigit(partial) {
  let sum = 0;
  for (let i = 0; i < partial.length; i++) {
    let d = Number(partial[partial.length - 1 - i]);
    if (i % 2 === 0) { d *= 2; if (d > 9) d -= 9; }
    sum += d;
  }
  return String((10 - (sum % 10)) % 10);
}

function luhnValid(pan) {
  return /^\d{12,19}$/.test(pan) && luhnCheckDigit(pan.slice(0, -1)) === pan.slice(-1);
}

const sandbox = {
  name: 'sandbox',
  issue({ brand }) {
    const bin = TEST_BINS[brand];
    if (!bin) throw new AppError(400, 'INVALID_BRAND', 'Réseau de carte non pris en charge');
    let body = bin;
    while (body.length < 15) body += crypto.randomInt(0, 10);
    const pan = body + luhnCheckDigit(body);
    const cvv = String(crypto.randomInt(0, 1000)).padStart(3, '0');
    const now = new Date();
    return { pan, cvv, expMonth: now.getUTCMonth() + 1, expYear: now.getUTCFullYear() + 3, providerRef: `SBX-CARD-${crypto.randomUUID()}` };
  },
};

function issuer() {
  if (config.cardIssuerMode !== 'sandbox') {
    throw new AppError(503, 'ISSUER_NOT_CONFIGURED', 'Aucun émetteur de cartes "live" configuré : branchez l’API de votre BIN sponsor dans src/providers/cardIssuer.js');
  }
  return sandbox;
}

module.exports = { issuer, luhnValid, luhnCheckDigit };
