'use strict';
// Adaptateurs d'agrégateurs Mobile Money.
// - "sandbox" : simulation complète (USSD push, validation, échecs) pour développer et tester.
// - "cinetpay", "flutterwave", "pawapay" : intégrations "live". Elles suivent la structure publique
//   de ces API mais DOIVENT être validées avec vos identifiants marchands et la documentation
//   à jour de chaque fournisseur avant toute mise en production.
const config = require('../config');
const { hmacSha256, safeEqual, randomToken } = require('../lib/crypto');
const { getCountry } = require('../data/countries');
const { AppError } = require('../lib/errors');

// ---------------------------------------------------------------- Sandbox
const sandbox = {
  name: 'sandbox',
  async initiateCollection({ opId, phone, operatorName, amountMajor, currency }) {
    if (phone.endsWith('0000')) {
      return { providerRef: `SBX-${randomToken(9)}`, status: 'failed', reason: 'Numéro de test refusé par l’opérateur (se termine par 0000)' };
    }
    return {
      providerRef: `SBX-${opId.slice(0, 8).toUpperCase()}`,
      status: 'pending',
      instructions: `Une demande de paiement de ${amountMajor} ${currency} a été envoyée au ${phone} (${operatorName}). Validez-la avec votre code secret sur votre téléphone.`,
    };
  },
  async initiatePayout({ opId, phone }) {
    if (phone.endsWith('0000')) {
      return { providerRef: `SBX-${randomToken(9)}`, status: 'failed', reason: 'Compte Mobile Money du bénéficiaire introuvable' };
    }
    // En sandbox les retraits sont confirmés immédiatement.
    return { providerRef: `SBX-${opId.slice(0, 8).toUpperCase()}`, status: 'completed' };
  },
  sign(rawBody) {
    return hmacSha256(config.webhookSecrets.sandbox, rawBody);
  },
  verifyWebhook(req) {
    const sig = req.get('x-sandbox-signature') || '';
    return safeEqual(sig, hmacSha256(config.webhookSecrets.sandbox, req.rawBody || ''));
  },
  parseWebhook(body) {
    return { eventId: body.event_id, opId: body.op_id, status: body.status, reason: body.reason };
  },
};

// ---------------------------------------------------------------- CinetPay (UEMOA / CEMAC / Guinée / RDC)
const cinetpay = {
  name: 'cinetpay',
  async initiateCollection({ opId, amountMajor, currency, phone, customerName, description }) {
    const { apiKey, siteId } = config.providers.cinetpay;
    if (!apiKey || !siteId) throw new AppError(503, 'PROVIDER_NOT_CONFIGURED', 'CinetPay non configuré');
    const res = await fetch('https://api-checkout.cinetpay.com/v2/payment', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        apikey: apiKey, site_id: siteId, transaction_id: opId, amount: Number(amountMajor), currency,
        description, channels: 'MOBILE_MONEY', customer_name: customerName, customer_phone_number: phone,
        notify_url: `${config.publicUrl}/api/webhooks/mobile-money/cinetpay`,
        return_url: `${config.publicUrl}/#/transactions`,
      }),
      signal: AbortSignal.timeout(15000),
    });
    const json = await res.json();
    if (json.code !== '201') return { providerRef: null, status: 'failed', reason: json.message || 'Refus CinetPay' };
    return { providerRef: json.data.payment_token, status: 'pending', redirectUrl: json.data.payment_url,
      instructions: 'Finalisez le paiement sur la page sécurisée de l’opérateur.' };
  },
  async initiatePayout() {
    throw new AppError(501, 'NOT_IMPLEMENTED', 'Transferts CinetPay : activez l’API "Transfert" sur votre compte marchand');
  },
  verifyWebhook(req) {
    // CinetPay signe ses notifications (en-tête x-token, HMAC SHA-256 des champs cpm_*).
    const token = req.get('x-token') || '';
    const b = req.body || {};
    const data = [b.cpm_site_id, b.cpm_trans_id, b.cpm_trans_date, b.cpm_amount, b.cpm_currency, b.signature,
      b.payment_method, b.cel_phone_num, b.cpm_phone_prefixe, b.cpm_language, b.cpm_version, b.cpm_payment_config,
      b.cpm_page_action, b.cpm_custom, b.cpm_designation, b.cpm_error_message].map((v) => v ?? '').join('');
    return Boolean(config.webhookSecrets.cinetpay) && safeEqual(token, hmacSha256(config.webhookSecrets.cinetpay, data));
  },
  parseWebhook(body) {
    // Le statut final doit être confirmé via /v2/payment/check (fait dans le service).
    return { eventId: `${body.cpm_trans_id}:${body.cpm_trans_date}`, opId: body.cpm_trans_id, status: 'verify' };
  },
  async checkStatus(opId) {
    const { apiKey, siteId } = config.providers.cinetpay;
    const res = await fetch('https://api-checkout.cinetpay.com/v2/payment/check', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ apikey: apiKey, site_id: siteId, transaction_id: opId }),
      signal: AbortSignal.timeout(15000),
    });
    const json = await res.json();
    const st = json?.data?.status;
    if (st === 'ACCEPTED') return 'completed';
    if (st === 'REFUSED' || st === 'CANCELED') return 'failed';
    return 'pending';
  },
};

// ---------------------------------------------------------------- Flutterwave (Nigeria, Ghana, Kenya, Ouganda…)
const FLW_TYPES = { GH: 'mobile_money_ghana', KE: 'mpesa', UG: 'mobile_money_uganda', RW: 'mobile_money_rwanda', ZM: 'mobile_money_zambia' };
const flutterwave = {
  name: 'flutterwave',
  async initiateCollection({ opId, amountMajor, currency, phone, email, customerName, country, operatorCode }) {
    const key = config.providers.flutterwave.secretKey;
    if (!key) throw new AppError(503, 'PROVIDER_NOT_CONFIGURED', 'Flutterwave non configuré');
    const type = FLW_TYPES[country] || 'mobile_money_franco';
    const res = await fetch(`https://api.flutterwave.com/v3/charges?type=${type}`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ tx_ref: opId, amount: amountMajor, currency, phone_number: phone.replace('+', ''),
        email, fullname: customerName, network: operatorCode.split('_')[0], country }),
      signal: AbortSignal.timeout(15000),
    });
    const json = await res.json();
    if (json.status !== 'success') return { providerRef: null, status: 'failed', reason: json.message };
    return { providerRef: String(json.data?.id || ''), status: 'pending', redirectUrl: json.meta?.authorization?.redirect,
      instructions: json.meta?.authorization?.note || 'Validez le paiement sur votre téléphone.' };
  },
  async initiatePayout({ opId, amountMajor, currency, phone, operatorCode, customerName }) {
    const key = config.providers.flutterwave.secretKey;
    const res = await fetch('https://api.flutterwave.com/v3/transfers', {
      method: 'POST', headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ account_bank: operatorCode.split('_')[0], account_number: phone.replace('+', ''),
        amount: Number(amountMajor), currency, reference: opId, beneficiary_name: customerName,
        callback_url: `${config.publicUrl}/api/webhooks/mobile-money/flutterwave` }),
      signal: AbortSignal.timeout(15000),
    });
    const json = await res.json();
    return json.status === 'success' ? { providerRef: String(json.data.id), status: 'pending' } : { providerRef: null, status: 'failed', reason: json.message };
  },
  verifyWebhook(req) {
    const h = req.get('verif-hash') || '';
    return Boolean(config.webhookSecrets.flutterwave) && safeEqual(h, config.webhookSecrets.flutterwave);
  },
  parseWebhook(body) {
    const d = body.data || {};
    const st = String(d.status || '').toLowerCase();
    return { eventId: `${d.id}:${st}`, opId: d.tx_ref || d.reference,
      status: st === 'successful' ? 'completed' : (st === 'failed' ? 'failed' : 'pending'), reason: d.processor_response };
  },
};

// ---------------------------------------------------------------- pawaPay (CEMAC, RDC, Tanzanie, Zambie, Éthiopie…)
const PAWA = { MTN_CG: 'MTN_MOMO_COG', AIRTEL_CG: 'AIRTEL_COG', AIRTEL_GA: 'AIRTEL_GAB', MPESA_CD: 'VODACOM_MPESA_COD',
  ORANGE_CD: 'ORANGE_COD', AIRTEL_CD: 'AIRTEL_COD', MPESA_TZ: 'VODACOM_TZA', AIRTEL_TZ: 'AIRTEL_TZA', MIXX_TZ: 'TIGO_TZA',
  HALOPESA_TZ: 'HALOTEL_TZA', MTN_ZM: 'MTN_MOMO_ZMB', AIRTEL_ZM: 'AIRTEL_OAPI_ZMB' };
const pawapay = {
  name: 'pawapay',
  async request(pathName, body) {
    const { apiToken, baseUrl } = config.providers.pawapay;
    if (!apiToken) throw new AppError(503, 'PROVIDER_NOT_CONFIGURED', 'pawaPay non configuré');
    const res = await fetch(`${baseUrl}${pathName}`, {
      method: 'POST', headers: { Authorization: `Bearer ${apiToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(body), signal: AbortSignal.timeout(15000),
    });
    return res.json();
  },
  async initiateCollection({ opId, amountMajor, currency, phone, operatorCode, description }) {
    const json = await this.request('/deposits', {
      depositId: opId, amount: String(amountMajor), currency, correspondent: PAWA[operatorCode] || operatorCode,
      payer: { type: 'MSISDN', address: { value: phone.replace('+', '') } },
      customerTimestamp: new Date().toISOString(), statementDescription: description.slice(0, 22),
    });
    if (json.status !== 'ACCEPTED') return { providerRef: null, status: 'failed', reason: json.rejectionReason?.rejectionMessage };
    return { providerRef: opId, status: 'pending', instructions: 'Validez la demande de paiement sur votre téléphone.' };
  },
  async initiatePayout({ opId, amountMajor, currency, phone, operatorCode }) {
    const json = await this.request('/payouts', {
      payoutId: opId, amount: String(amountMajor), currency, correspondent: PAWA[operatorCode] || operatorCode,
      recipient: { type: 'MSISDN', address: { value: phone.replace('+', '') } },
      customerTimestamp: new Date().toISOString(), statementDescription: 'AfriCard retrait',
    });
    return json.status === 'ACCEPTED' ? { providerRef: opId, status: 'pending' } : { providerRef: null, status: 'failed', reason: json.rejectionReason?.rejectionMessage };
  },
  verifyWebhook(req) {
    // pawaPay : signature RFC 9421 optionnelle ; à défaut, protéger l'URL par un secret partagé.
    const s = req.get('x-africard-webhook-secret') || '';
    return Boolean(config.webhookSecrets.pawapay) && safeEqual(s, config.webhookSecrets.pawapay);
  },
  parseWebhook(body) {
    const id = body.depositId || body.payoutId;
    return { eventId: `${id}:${body.status}`, opId: id,
      status: body.status === 'COMPLETED' ? 'completed' : (body.status === 'FAILED' ? 'failed' : 'pending'),
      reason: body.failureReason?.failureMessage };
  },
};

const PROVIDERS = { sandbox, cinetpay, flutterwave, pawapay };

function providerFor(countryCode) {
  if (config.mobileMoneyMode !== 'live') return sandbox;
  const c = getCountry(countryCode);
  return PROVIDERS[c?.liveProvider] || sandbox;
}

module.exports = { providerFor, PROVIDERS };
