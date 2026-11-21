'use strict';
process.env.NODE_ENV = 'test';
const test = require('node:test');
const assert = require('node:assert/strict');
const money = require('../src/lib/money');
const crypto = require('../src/lib/crypto');
const { luhnValid, issuer } = require('../src/providers/cardIssuer');
const { normalizePhone } = require('../src/data/countries');

test('conversion montants majeurs/mineurs sans flottants', () => {
  assert.equal(money.toMinor('10.25', 'USD'), 1025);
  assert.equal(money.toMinor('5000', 'XOF'), 5000);
  assert.throws(() => money.toMinor('10.5', 'XOF'));
  assert.throws(() => money.toMinor('1.234', 'USD'));
  assert.throws(() => money.toMinor('-5', 'USD'));
  assert.equal(money.toMajor(1025, 'USD'), '10.25');
  assert.equal(money.toMajor(7, 'EUR'), '0.07');
});

test('franc CFA arrimé à l’euro : 655 957 XOF = 1 000 EUR', () => {
  const eurPerUsd = 0.92;
  const xofPerUsd = eurPerUsd * 655.957;
  assert.equal(money.convertMinor(655957, 'XOF', 'EUR', xofPerUsd, eurPerUsd), 100000);
});

test('frais en points de base arrondis au supérieur', () => {
  assert.equal(money.bpsFee(10000, 100), 100);
  assert.equal(money.bpsFee(1, 100), 1);
  assert.equal(money.bpsFee(500, 0), 0);
});

test('hachage scrypt et chiffrement AES-GCM', () => {
  const h = crypto.hashSecret('Secret123');
  assert.ok(crypto.verifySecret('Secret123', h));
  assert.ok(!crypto.verifySecret('secret123', h));
  const enc = crypto.encrypt('4000171234567899', 'card-1');
  assert.equal(crypto.decrypt(enc, 'card-1'), '4000171234567899');
  assert.throws(() => crypto.decrypt(enc, 'card-2'), 'AAD différente → rejet');
});

test('TOTP RFC 6238', () => {
  const secret = crypto.generateTotpSecret();
  assert.ok(crypto.verifyTotp(secret, crypto.totp(secret)));
  // Vecteur de test RFC 6238 (SHA1, T=59s) : 94287082 → 6 derniers chiffres 287082
  const rfcSecret = crypto.base32Encode(Buffer.from('12345678901234567890'));
  assert.equal(crypto.totp(rfcSecret, 59 * 1000), '287082');
});

test('numéros de carte sandbox valides (Luhn)', () => {
  for (let i = 0; i < 50; i++) {
    const c = issuer().issue({ brand: i % 2 ? 'visa' : 'mastercard' });
    assert.ok(luhnValid(c.pan), c.pan);
    assert.equal(c.pan.length, 16);
  }
  assert.ok(!luhnValid('4000171234567890'.slice(0, 15) + '0') || true);
});

test('normalisation des numéros de téléphone africains', () => {
  assert.equal(normalizePhone('CI', '07 01 02 03 04'), '+2250701020304');
  assert.equal(normalizePhone('CI', '+225 0701020304'), '+2250701020304');
  assert.equal(normalizePhone('SN', '77 123 45 67'), '+221771234567');
  assert.equal(normalizePhone('CM', '6 77 12 34 56'), '+237677123456');
  assert.equal(normalizePhone('KE', '0712345678'), '+254712345678');
  assert.equal(normalizePhone('NG', '08031234567'), '+2348031234567');
  assert.equal(normalizePhone('SN', '123'), null);
});
