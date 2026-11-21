'use strict';

// Pays pris en charge, opérateurs de paiement locaux et fournisseur d'agrégation en mode "live".
// `phoneDigits` = longueurs acceptées du numéro national (sans indicatif).
// `min` / `max` = limites par opération, en unités majeures de la devise locale.
// `liveProvider` = agrégateur recommandé pour ce pays (CinetPay, Flutterwave, pawaPay…).

const op = (code, name, type = 'mobile_money', extra = {}) => ({ code, name, type, ...extra });

const COUNTRIES = {
  // ---------------- UEMOA (XOF) ----------------
  CI: { name: "Côte d'Ivoire", currency: 'XOF', dial: '225', phoneDigits: [10], min: 200, max: 2000000, liveProvider: 'cinetpay',
    operators: [op('ORANGE_CI', 'Orange Money'), op('MTN_CI', 'MTN MoMo'), op('MOOV_CI', 'Moov Money'), op('WAVE_CI', 'Wave')] },
  SN: { name: 'Sénégal', currency: 'XOF', dial: '221', phoneDigits: [9], min: 200, max: 2000000, liveProvider: 'cinetpay',
    operators: [op('ORANGE_SN', 'Orange Money'), op('WAVE_SN', 'Wave'), op('FREE_SN', 'Free Money / Mixx by Yas')] },
  ML: { name: 'Mali', currency: 'XOF', dial: '223', phoneDigits: [8], min: 200, max: 2000000, liveProvider: 'cinetpay',
    operators: [op('ORANGE_ML', 'Orange Money'), op('MOOV_ML', 'Moov Money'), op('WAVE_ML', 'Wave')] },
  BF: { name: 'Burkina Faso', currency: 'XOF', dial: '226', phoneDigits: [8], min: 200, max: 2000000, liveProvider: 'cinetpay',
    operators: [op('ORANGE_BF', 'Orange Money'), op('MOOV_BF', 'Moov Money')] },
  BJ: { name: 'Bénin', currency: 'XOF', dial: '229', phoneDigits: [8, 10], min: 200, max: 2000000, liveProvider: 'cinetpay',
    operators: [op('MTN_BJ', 'MTN MoMo'), op('MOOV_BJ', 'Moov Money'), op('CELTIIS_BJ', 'Celtiis Cash')] },
  TG: { name: 'Togo', currency: 'XOF', dial: '228', phoneDigits: [8], min: 200, max: 2000000, liveProvider: 'cinetpay',
    operators: [op('TMONEY_TG', 'T-Money / Mixx by Yas'), op('FLOOZ_TG', 'Flooz (Moov)')] },
  NE: { name: 'Niger', currency: 'XOF', dial: '227', phoneDigits: [8], min: 200, max: 2000000, liveProvider: 'cinetpay',
    operators: [op('AIRTEL_NE', 'Airtel Money'), op('MOOV_NE', 'Moov Money')] },

  // ---------------- CEMAC (XAF) ----------------
  CM: { name: 'Cameroun', currency: 'XAF', dial: '237', phoneDigits: [9], min: 200, max: 2000000, liveProvider: 'cinetpay',
    operators: [op('ORANGE_CM', 'Orange Money'), op('MTN_CM', 'MTN MoMo')] },
  GA: { name: 'Gabon', currency: 'XAF', dial: '241', phoneDigits: [8, 9], min: 200, max: 2000000, liveProvider: 'pawapay',
    operators: [op('AIRTEL_GA', 'Airtel Money'), op('MOOV_GA', 'Moov Money')] },
  CG: { name: 'Congo-Brazzaville', currency: 'XAF', dial: '242', phoneDigits: [9], min: 200, max: 2000000, liveProvider: 'pawapay',
    operators: [op('MTN_CG', 'MTN MoMo'), op('AIRTEL_CG', 'Airtel Money')] },
  TD: { name: 'Tchad', currency: 'XAF', dial: '235', phoneDigits: [8], min: 200, max: 2000000, liveProvider: 'pawapay',
    operators: [op('AIRTEL_TD', 'Airtel Money'), op('MOOV_TD', 'Moov Money')] },

  // ---------------- Autres pays francophones ----------------
  GN: { name: 'Guinée', currency: 'GNF', dial: '224', phoneDigits: [9], min: 5000, max: 50000000, liveProvider: 'cinetpay',
    operators: [op('ORANGE_GN', 'Orange Money'), op('MTN_GN', 'MTN MoMo')] },
  CD: { name: 'RD Congo', currency: 'CDF', dial: '243', phoneDigits: [9], min: 1000, max: 10000000, liveProvider: 'pawapay',
    operators: [op('MPESA_CD', 'M-Pesa (Vodacom)'), op('ORANGE_CD', 'Orange Money'), op('AIRTEL_CD', 'Airtel Money'), op('AFRIMONEY_CD', 'Afrimoney')] },
  MA: { name: 'Maroc', currency: 'MAD', dial: '212', phoneDigits: [9], min: 20, max: 50000, liveProvider: 'flutterwave',
    operators: [op('BANK_MA', 'Virement bancaire', 'bank_transfer')] },

  // ---------------- Afrique anglophone ----------------
  NG: { name: 'Nigeria', currency: 'NGN', dial: '234', phoneDigits: [10], min: 500, max: 5000000, liveProvider: 'flutterwave',
    operators: [op('OPAY_NG', 'OPay'), op('PALMPAY_NG', 'PalmPay'), op('MOMOPSB_NG', 'MTN MoMo PSB'), op('BANK_NG', 'Virement bancaire (NIP)', 'bank_transfer'), op('USSD_NG', 'USSD bancaire', 'ussd')] },
  GH: { name: 'Ghana', currency: 'GHS', dial: '233', phoneDigits: [9], min: 5, max: 50000, liveProvider: 'flutterwave',
    operators: [op('MTN_GH', 'MTN MoMo'), op('TELECEL_GH', 'Telecel Cash'), op('AT_GH', 'AT Money')] },
  KE: { name: 'Kenya', currency: 'KES', dial: '254', phoneDigits: [9], min: 50, max: 250000, liveProvider: 'flutterwave',
    operators: [op('MPESA_KE', 'M-Pesa (Safaricom)'), op('AIRTEL_KE', 'Airtel Money')] },
  UG: { name: 'Ouganda', currency: 'UGX', dial: '256', phoneDigits: [9], min: 1000, max: 5000000, liveProvider: 'flutterwave',
    operators: [op('MTN_UG', 'MTN MoMo'), op('AIRTEL_UG', 'Airtel Money')] },
  TZ: { name: 'Tanzanie', currency: 'TZS', dial: '255', phoneDigits: [9], min: 1000, max: 5000000, liveProvider: 'pawapay',
    operators: [op('MPESA_TZ', 'M-Pesa (Vodacom)'), op('MIXX_TZ', 'Mixx by Yas (Tigo Pesa)'), op('AIRTEL_TZ', 'Airtel Money'), op('HALOPESA_TZ', 'HaloPesa')] },
  RW: { name: 'Rwanda', currency: 'RWF', dial: '250', phoneDigits: [9], min: 500, max: 2000000, liveProvider: 'flutterwave',
    operators: [op('MTN_RW', 'MTN MoMo'), op('AIRTEL_RW', 'Airtel Money')] },
  ZM: { name: 'Zambie', currency: 'ZMW', dial: '260', phoneDigits: [9], min: 10, max: 50000, liveProvider: 'pawapay',
    operators: [op('MTN_ZM', 'MTN MoMo'), op('AIRTEL_ZM', 'Airtel Money')] },
  ZA: { name: 'Afrique du Sud', currency: 'ZAR', dial: '27', phoneDigits: [9], min: 20, max: 50000, liveProvider: 'flutterwave',
    operators: [op('EFT_ZA', 'Instant EFT', 'bank_transfer')] },
  EG: { name: 'Égypte', currency: 'EGP', dial: '20', phoneDigits: [10], min: 50, max: 100000, liveProvider: 'flutterwave',
    operators: [op('VODAFONE_EG', 'Vodafone Cash'), op('INSTAPAY_EG', 'InstaPay', 'bank_transfer')] },
  ET: { name: 'Éthiopie', currency: 'ETB', dial: '251', phoneDigits: [9], min: 50, max: 200000, liveProvider: 'pawapay',
    operators: [op('TELEBIRR_ET', 'telebirr'), op('MPESA_ET', 'M-Pesa (Safaricom)')] },
};

function getCountry(code) {
  return COUNTRIES[String(code || '').toUpperCase()] || null;
}

function getOperator(countryCode, operatorCode) {
  const c = getCountry(countryCode);
  if (!c) return null;
  return c.operators.find((o) => o.code === operatorCode) || null;
}

/** Normalise un numéro en E.164 (+indicatif + numéro national) ; renvoie null si invalide. */
function normalizePhone(countryCode, raw) {
  const c = getCountry(countryCode);
  if (!c) return null;
  let digits = String(raw || '').replace(/[^\d]/g, '');
  if (digits.startsWith('00')) digits = digits.slice(2);
  if (digits.startsWith(c.dial) && c.phoneDigits.includes(digits.length - c.dial.length)) {
    digits = digits.slice(c.dial.length);
  } else if (digits.startsWith('0') && c.phoneDigits.includes(digits.length - 1) && !c.phoneDigits.includes(digits.length)) {
    digits = digits.slice(1); // préfixe national "0"
  }
  if (!c.phoneDigits.includes(digits.length)) return null;
  return `+${c.dial}${digits}`;
}

function publicCountries() {
  return Object.entries(COUNTRIES).map(([code, c]) => ({
    code, name: c.name, currency: c.currency, dial: c.dial, phoneDigits: c.phoneDigits,
    min: c.min, max: c.max,
    operators: c.operators.map(({ code: oc, name, type }) => ({ code: oc, name, type })),
  }));
}

module.exports = { COUNTRIES, getCountry, getOperator, normalizePhone, publicCountries };
