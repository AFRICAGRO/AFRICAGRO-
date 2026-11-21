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

  // Documents juridiques : changer la version oblige chaque utilisateur à ré-accepter.
  legal: {
    privacyVersion: env('PRIVACY_POLICY_VERSION', '2026-11-21'),
    termsVersion: env('TERMS_VERSION', '2026-11-21'),
    companyName: env('COMPANY_NAME', 'AFRICAGRO'),
    dpoEmail: env('DPO_EMAIL', 'dpo@africard.example'),
    supportEmail: env('SUPPORT_EMAIL', 'support@africard.example'),
  },

  // Canaux de notification. "console" = affichage dans les journaux (dev/sandbox).
  notifications: {
    emailProvider: env('NOTIFY_EMAIL_PROVIDER', 'console'),   // console | resend | brevo
    emailFrom: env('EMAIL_FROM', 'AfriCard <no-reply@africard.example>'),
    resendApiKey: env('RESEND_API_KEY', ''),
    brevoApiKey: env('BREVO_API_KEY', ''),
    smsProvider: env('NOTIFY_SMS_PROVIDER', 'console'),       // console | africastalking | twilio
    smsSender: env('SMS_SENDER_ID', 'AfriCard'),
    africasTalking: { username: env('AT_USERNAME', ''), apiKey: env('AT_API_KEY', '') },
    twilio: { sid: env('TWILIO_ACCOUNT_SID', ''), token: env('TWILIO_AUTH_TOKEN', ''), from: env('TWILIO_FROM', '') },
    adminWebhookUrl: env('ADMIN_ALERT_WEBHOOK_URL', ''),        // Slack / Discord / Teams (JSON)
    telegramBotToken: env('TELEGRAM_BOT_TOKEN', ''),
    telegramChatId: env('TELEGRAM_CHAT_ID', ''),
    adminEmails: env('ADMIN_ALERT_EMAILS', '').split(',').map((s) => s.trim()).filter(Boolean),
  },

  agents: {
    enabled: env('AGENTS_ENABLED', 'true') === 'true',
    securityIntervalSec: Number(env('AGENT_SECURITY_INTERVAL_SEC', 60)),
    reliabilityIntervalSec: Number(env('AGENT_RELIABILITY_INTERVAL_SEC', 300)),
    notificationIntervalSec: Number(env('AGENT_NOTIFICATION_INTERVAL_SEC', 30)),
    amlSingleTxUsdCents: Number(env('AML_SINGLE_TX_USD_CENTS', 5_000_00)),
    amlDailyUsdCents: Number(env('AML_DAILY_USD_CENTS', 10_000_00)),
    pendingDepositExpiryMin: Number(env('PENDING_DEPOSIT_EXPIRY_MIN', 30)),
  },

  // Codes à usage unique renvoyés dans la réponse API hors production (tests uniquement).
  exposeDevCodes: !isProd && env('MOBILE_MONEY_MODE', 'sandbox') === 'sandbox',

  security: {
    maxLoginAttempts: 5,
    loginLockMinutes: 15,
    maxPinAttempts: 5,
    pinLockMinutes: 30,
  },
};

module.exports = config;
