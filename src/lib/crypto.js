'use strict';
const crypto = require('node:crypto');
const config = require('../config');

// ---------- Hachage des mots de passe / PIN (scrypt, sel unique) ----------
const SCRYPT = { N: 16384, r: 8, p: 1, keylen: 64 };

function hashSecret(plain) {
  const salt = crypto.randomBytes(16);
  const hash = crypto.scryptSync(String(plain), salt, SCRYPT.keylen, { N: SCRYPT.N, r: SCRYPT.r, p: SCRYPT.p });
  return ['scrypt', SCRYPT.N, salt.toString('base64'), hash.toString('base64')].join('$');
}

function verifySecret(plain, stored) {
  if (!stored || typeof stored !== 'string') return false;
  const [algo, n, saltB64, hashB64] = stored.split('$');
  if (algo !== 'scrypt') return false;
  const expected = Buffer.from(hashB64, 'base64');
  const actual = crypto.scryptSync(String(plain), Buffer.from(saltB64, 'base64'), expected.length, {
    N: Number(n), r: SCRYPT.r, p: SCRYPT.p,
  });
  return crypto.timingSafeEqual(expected, actual);
}

// ---------- Chiffrement des données sensibles (AES-256-GCM) ----------
let cachedKey = null;
function dataKey() {
  if (cachedKey) return cachedKey;
  const raw = config.dataKeyHex;
  // Clé hex de 64 caractères attendue ; sinon dérivation SHA-256.
  cachedKey = /^[0-9a-f]{64}$/i.test(raw)
    ? Buffer.from(raw, 'hex')
    : crypto.createHash('sha256').update(raw).digest();
  return cachedKey;
}

function encrypt(plaintext, aad = '') {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', dataKey(), iv);
  if (aad) cipher.setAAD(Buffer.from(aad));
  const ct = Buffer.concat([cipher.update(String(plaintext), 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return ['v1', iv.toString('base64'), tag.toString('base64'), ct.toString('base64')].join('.');
}

function decrypt(payload, aad = '') {
  const [v, ivB64, tagB64, ctB64] = String(payload).split('.');
  if (v !== 'v1') throw new Error('Format de chiffrement inconnu');
  const decipher = crypto.createDecipheriv('aes-256-gcm', dataKey(), Buffer.from(ivB64, 'base64'));
  if (aad) decipher.setAAD(Buffer.from(aad));
  decipher.setAuthTag(Buffer.from(tagB64, 'base64'));
  return Buffer.concat([decipher.update(Buffer.from(ctB64, 'base64')), decipher.final()]).toString('utf8');
}

// ---------- Utilitaires ----------
const sha256 = (s) => crypto.createHash('sha256').update(String(s)).digest('hex');
const hmacSha256 = (key, s) => crypto.createHmac('sha256', key).update(s).digest('hex');
const randomToken = (bytes = 32) => crypto.randomBytes(bytes).toString('base64url');
const uuid = () => crypto.randomUUID();

function safeEqual(a, b) {
  const ba = Buffer.from(String(a));
  const bb = Buffer.from(String(b));
  if (ba.length !== bb.length) return false;
  return crypto.timingSafeEqual(ba, bb);
}

function randomDigits(n) {
  let s = '';
  for (let i = 0; i < n; i++) s += crypto.randomInt(0, 10);
  return s;
}

// ---------- TOTP (RFC 6238) pour la double authentification ----------
const B32 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

function base32Encode(buf) {
  let bits = 0, value = 0, out = '';
  for (const byte of buf) {
    value = (value << 8) | byte; bits += 8;
    while (bits >= 5) { out += B32[(value >>> (bits - 5)) & 31]; bits -= 5; }
  }
  if (bits > 0) out += B32[(value << (5 - bits)) & 31];
  return out;
}

function base32Decode(str) {
  const clean = String(str).replace(/=+$/, '').toUpperCase().replace(/\s/g, '');
  let bits = 0, value = 0; const out = [];
  for (const c of clean) {
    const idx = B32.indexOf(c);
    if (idx === -1) throw new Error('base32 invalide');
    value = (value << 5) | idx; bits += 5;
    if (bits >= 8) { out.push((value >>> (bits - 8)) & 255); bits -= 8; }
  }
  return Buffer.from(out);
}

function generateTotpSecret() {
  return base32Encode(crypto.randomBytes(20));
}

function totp(secretB32, time = Date.now(), step = 30, digits = 6) {
  const counter = Math.floor(time / 1000 / step);
  const buf = Buffer.alloc(8);
  buf.writeBigUInt64BE(BigInt(counter));
  const h = crypto.createHmac('sha1', base32Decode(secretB32)).update(buf).digest();
  const offset = h[h.length - 1] & 0xf;
  const code = ((h.readUInt32BE(offset) & 0x7fffffff) % 10 ** digits).toString();
  return code.padStart(digits, '0');
}

function verifyTotp(secretB32, code, window = 1) {
  if (!/^\d{6}$/.test(String(code))) return false;
  const now = Date.now();
  for (let w = -window; w <= window; w++) {
    if (safeEqual(totp(secretB32, now + w * 30000), String(code))) return true;
  }
  return false;
}

module.exports = {
  hashSecret, verifySecret, encrypt, decrypt, sha256, hmacSha256, randomToken, uuid,
  safeEqual, randomDigits, generateTotpSecret, totp, verifyTotp, base32Encode, base32Decode,
};
