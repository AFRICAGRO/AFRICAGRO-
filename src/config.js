'use strict';
const crypto = require('node:crypto');

function env(name, fallback) {
  const v = process.env[name];
  return v === undefined || v === '' ? fallback : v;
}

const NODE_ENV = env('NODE_ENV', 'development');
const isProd = NODE_ENV === 'production';

function secret(name, bytes = 32) {
  const v = process.env[name];
  if (v) return v;
  if (isProd) {
    throw new Error(`La variable d'environnement ${name} est obligatoire en production.`);
  }
  // En dev/test : secret éphémère (les sessions sont invalidées au redémarrage).
  return crypto.randomBytes(bytes).toString('hex');
}

const config = {
  env: NODE_ENV,
  isProd,
  port: Number(env('PORT', 3000)),
  dbPath: env('DB_PATH', 'data/africard.db'),
  publicUrl: env('PUBLIC_URL', 'http://localhost:3000'),

  jwtSecret: secret('JWT_SECRET'),
  accessTokenTtlSec: Number(env('ACCESS_TOKEN_TTL_SEC', 900)),
  refreshTokenTtlDays: Number(env('REFRESH_TOKEN_TTL_DAYS', 30)),

  // Clé maître AES-256-GCM (64 caractères hex) pour chiffrer PAN/CVV et secrets 2FA.
  dataKeyHex: secret('DATA_ENCRYPTION_KEY'),

  // Mode des fournisseurs : "sandbox" (simulation complète) ou "live".
  mobileMoneyMode: env('MOBILE_MONEY_MODE', 'sandbox'),
  cardIssuerMode: env('CARD_ISSUER_MODE', 'sandbox'),
  sandboxAutoApproveKyc: env('SANDBOX_AUTO_APPROVE_KYC', isProd ? 'false' : 'true') === 'true',

  // Tarification (points de base : 100 bps = 1 %)
  fees: {
    depositBps: Number(env('FEE_DEPOSIT_BPS', 100)),        // 1 %
    withdrawalBps: Number(env('FEE_WITHDRAWAL_BPS', 150)),  // 1,5 %
    fxSpreadBps: Number(env('FEE_FX_SPREAD_BPS', 150)),     // 1,5 %
    cardCreationUsdCents: Number(env('FEE_CARD_CREATION_USD_CENTS', 200)), // 2 USD
    cardCrossCurrencyBps: Number(env('FEE_CARD_CROSS_CCY_BPS', 100)),
    p2pBps: Number(env('FEE_P2P_BPS', 0)),                  // transferts entre membres gratuits
  },

  fxQuoteTtlSec: Number(env('FX_QUOTE_TTL_SEC', 60)),
  fxLive: env('FX_LIVE', 'false') === 'true',
  fxLiveUrl: env('FX_LIVE_URL', 'https://open.er-api.com/v6/latest/USD'),

  webhookSecrets: {
    sandbox: secret('MM_SANDBOX_WEBHOOK_SECRET'),
    cinetpay: env('CINETPAY_SECRET_KEY', ''),
    flutterwave: env('FLUTTERWAVE_WEBHOOK_HASH', ''),
    pawapay: env('PAWAPAY_WEBHOOK_SECRET', ''),
  },
  providers: {
    cinetpay: { apiKey: env('CINETPAY_API_KEY', ''), siteId: env('CINETPAY_SITE_ID', '') },
    flutterwave: { secretKey: env('FLUTTERWAVE_SECRET_KEY', '') },
    pawapay: { apiToken: env('PAWAPAY_API_TOKEN', ''), baseUrl: env('PAWAPAY_BASE_URL', 'https://api.sandbox.pawapay.io') },
  },

  security: {
    maxLoginAttempts: 5,
    loginLockMinutes: 15,
    maxPinAttempts: 5,
    pinLockMinutes: 30,
  },
};

module.exports = config;
