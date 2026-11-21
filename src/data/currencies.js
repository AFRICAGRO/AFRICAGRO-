'use strict';

// Devises prises en charge. `decimals` = nombre de décimales ISO 4217 (unités mineures).
// `usdRate` = cours de référence (unités de la devise pour 1 USD). Ces cours servent de
// repli hors-ligne ; en production activez FX_LIVE=true ou branchez votre fournisseur de cours.
// XOF et XAF sont arrimés à l'euro (1 EUR = 655,957 F CFA) : leur cours est dérivé de l'EUR.

const EUR_PER_USD = 0.92;
const CFA_PER_EUR = 655.957;

const CURRENCIES = {
  // --- Devises africaines ---
  XOF: { name: 'Franc CFA (UEMOA)', symbol: 'FCFA', decimals: 0, usdRate: EUR_PER_USD * CFA_PER_EUR, african: true, pegToEur: CFA_PER_EUR },
  XAF: { name: 'Franc CFA (CEMAC)', symbol: 'FCFA', decimals: 0, usdRate: EUR_PER_USD * CFA_PER_EUR, african: true, pegToEur: CFA_PER_EUR },
  NGN: { name: 'Naira nigérian', symbol: '₦', decimals: 2, usdRate: 1550, african: true },
  GHS: { name: 'Cedi ghanéen', symbol: 'GH₵', decimals: 2, usdRate: 15.5, african: true },
  KES: { name: 'Shilling kényan', symbol: 'KSh', decimals: 2, usdRate: 129, african: true },
  UGX: { name: 'Shilling ougandais', symbol: 'USh', decimals: 0, usdRate: 3700, african: true },
  TZS: { name: 'Shilling tanzanien', symbol: 'TSh', decimals: 2, usdRate: 2650, african: true },
  RWF: { name: 'Franc rwandais', symbol: 'FRw', decimals: 0, usdRate: 1400, african: true },
  GNF: { name: 'Franc guinéen', symbol: 'FG', decimals: 0, usdRate: 8600, african: true },
  CDF: { name: 'Franc congolais', symbol: 'FC', decimals: 2, usdRate: 2850, african: true },
  ZMW: { name: 'Kwacha zambien', symbol: 'ZK', decimals: 2, usdRate: 27, african: true },
  ZAR: { name: 'Rand sud-africain', symbol: 'R', decimals: 2, usdRate: 18.2, african: true },
  MAD: { name: 'Dirham marocain', symbol: 'DH', decimals: 2, usdRate: 9.9, african: true },
  EGP: { name: 'Livre égyptienne', symbol: 'E£', decimals: 2, usdRate: 49, african: true },
  ETB: { name: 'Birr éthiopien', symbol: 'Br', decimals: 2, usdRate: 140, african: true },

  // --- Devises internationales ---
  USD: { name: 'Dollar américain', symbol: '$', decimals: 2, usdRate: 1 },
  EUR: { name: 'Euro', symbol: '€', decimals: 2, usdRate: EUR_PER_USD },
  CNY: { name: 'Yuan chinois', symbol: '¥', decimals: 2, usdRate: 7.2 },
  GBP: { name: 'Livre sterling', symbol: '£', decimals: 2, usdRate: 0.79 },
  AED: { name: 'Dirham des É.A.U.', symbol: 'AED', decimals: 2, usdRate: 3.6725 },
  CAD: { name: 'Dollar canadien', symbol: 'C$', decimals: 2, usdRate: 1.38 },
  CHF: { name: 'Franc suisse', symbol: 'CHF', decimals: 2, usdRate: 0.88 },
  JPY: { name: 'Yen japonais', symbol: '¥', decimals: 0, usdRate: 150 },
  INR: { name: 'Roupie indienne', symbol: '₹', decimals: 2, usdRate: 84 },
  TRY: { name: 'Livre turque', symbol: '₺', decimals: 2, usdRate: 34 },
  SAR: { name: 'Riyal saoudien', symbol: 'SAR', decimals: 2, usdRate: 3.75 },
};

// Devises dans lesquelles une carte virtuelle peut être émise.
const CARD_CURRENCIES = ['USD', 'EUR', 'GBP'];

module.exports = { CURRENCIES, CARD_CURRENCIES, CFA_PER_EUR };
