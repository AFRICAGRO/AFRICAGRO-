'use strict';
// Cartes virtuelles prépayées : création, rechargement (avec conversion automatique),
// contrôles de dépenses, gel, révélation sécurisée et autorisations marchands.
const config = require('../config');
const db = require('../db');
const ledger = require('./ledger');
const fx = require('./fx');
const limits = require('./limits');
const money = require('../lib/money');
const { notify } = require('./notify');
const { encrypt, decrypt, hmacSha256, uuid, safeEqual } = require('../lib/crypto');
const { AppError } = require('../lib/errors');
const { issuer } = require('../providers/cardIssuer');
const { CARD_CURRENCIES } = require('../data/currencies');

const CATEGORIES = {
  streaming: 'Streaming & musique (Netflix, Spotify, YouTube…)',
  ecommerce: 'E-commerce (Amazon, AliExpress, Jumia, Temu…)',
  ads: 'Publicité en ligne (Meta, Google, TikTok Ads)',
  software: 'Logiciels & IA (Canva, ChatGPT, hébergement, domaines)',
  education: 'Formation & examens (Coursera, TOEFL, IELTS, frais de visa)',
  travel: 'Voyages (compagnies aériennes, hôtels, Booking)',
  gaming: 'Jeux vidéo (PlayStation, Steam, Xbox)',
  transport: 'Transport (Uber, Bolt…)',
  marketplace: 'Plateformes freelance (Upwork, Fiverr)',
  gambling: 'Jeux d’argent et paris',
  crypto: 'Plateformes crypto',
  other: 'Autres',
};

const cardKey = () => config.dataKeyHex;
const panHash = (pan) => hmacSha256(cardKey(), `pan:${pan}`);

function getCard(userId, cardId) {
  const card = db.get().prepare('SELECT * FROM cards WHERE id=? AND user_id=?').get(cardId, userId);
  if (!card) throw new AppError(404, 'CARD_NOT_FOUND', 'Carte introuvable');
  return card;
}

function publicCard(card) {
  const acc = ledger.cardAccount(card.id, card.currency);
  return {
    id: card.id, label: card.label, brand: card.brand, currency: card.currency, last4: card.last4,
    maskedPan: `•••• •••• •••• ${card.last4}`, expMonth: card.exp_month, expYear: card.exp_year, status: card.status,
    balance: money.toMajor(acc.balance, card.currency), singleUse: Boolean(card.single_use), usedOnce: Boolean(card.used_once),
    merchantLock: card.merchant_lock, lockToFirstMerchant: Boolean(card.lock_to_first_merchant),
    perTxLimit: card.per_tx_limit != null ? money.toMajor(card.per_tx_limit, card.currency) : null,
    monthlyLimit: card.monthly_limit != null ? money.toMajor(card.monthly_limit, card.currency) : null,
    monthlySpent: money.toMajor(monthlySpent(card.id), card.currency),
    blockedCategories: JSON.parse(card.blocked_categories || '[]'),
    allowedCountries: card.allowed_countries ? JSON.parse(card.allowed_countries) : null,
    createdAt: card.created_at,
  };
}

function monthlySpent(cardId) {
  const start = new Date(); start.setUTCDate(1); start.setUTCHours(0, 0, 0, 0);
  return db.get().prepare(`SELECT COALESCE(SUM(billed_amount),0) AS s FROM card_authorizations
                           WHERE card_id=? AND status='approved' AND created_at>=?`).get(cardId, start.toISOString()).s;
}

/**
 * Prépare les écritures pour prélever `targetMinor` (devise de `targetAccount`) depuis le
 * portefeuille `sourceCurrency` de l'utilisateur, avec conversion automatique si nécessaire.
 */
function fundingPlan(userId, sourceCurrency, targetAccount, targetMinor) {
  const to = targetAccount.currency;
  if (sourceCurrency === to) {
    return { entries: [{ account: ledger.wallet(userId, to), amount: -targetMinor }, { account: targetAccount, amount: targetMinor }],
      debited: targetMinor, debitedCurrency: to, fxFee: 0 };
  }
  const q = fx.price({ from: sourceCurrency, to, amountMinor: targetMinor, mode: 'buy' });
  const entries = fx.fxEntries(ledger.wallet(userId, sourceCurrency), targetAccount, q.fromMinor, q.fee, q.toMinor, sourceCurrency, to);
  // Le léger surplus d'arrondi (q.toMinor >= targetMinor) reste sur le compte cible.
  return { entries, debited: q.fromMinor, debitedCurrency: sourceCurrency, fxFee: q.fee, rate: q.rate, credited: q.toMinor };
}

function previewLoad(user, cardId, amount, sourceCurrency) {
  const card = getCard(user.id, cardId);
  const minor = money.toMinor(amount, card.currency);
  const src = (sourceCurrency || card.currency).toUpperCase();
  const acc = ledger.cardAccount(card.id, card.currency);
  const plan = fundingPlan(user.id, src, acc, minor);
  return { cardCurrency: card.currency, amount: money.toMajor(minor, card.currency),
    debited: money.toMajor(plan.debited, plan.debitedCurrency), debitedCurrency: plan.debitedCurrency,
    fxFee: money.toMajor(plan.fxFee, plan.debitedCurrency), rate: plan.rate || '1' };
}

function createCard(user, { label, brand = 'visa', currency = 'USD', singleUse = false, lockToFirstMerchant = false,
  perTxLimit = null, monthlyLimit = null, initialAmount = null, fundingCurrency = null }) {
  currency = currency.toUpperCase();
  if (!CARD_CURRENCIES.includes(currency)) throw new AppError(400, 'INVALID_CARD_CURRENCY', `Devises de carte disponibles : ${CARD_CURRENCIES.join(', ')}`);
  const tier = limits.TIERS[user.kyc_level] || limits.TIERS[0];
  if (tier.maxCards === 0) throw new AppError(403, 'KYC_REQUIRED', 'Vérifiez votre identité (KYC) pour créer une carte virtuelle');
  const active = db.get().prepare("SELECT COUNT(*) AS n FROM cards WHERE user_id=? AND status!='terminated'").get(user.id).n;
  if (active >= tier.maxCards) throw new AppError(403, 'CARD_LIMIT', `Nombre maximal de cartes atteint (${tier.maxCards}) pour votre niveau`);

  const src = (fundingCurrency || currency).toUpperCase();
  const feeMinor = fx.midConvert(config.fees.cardCreationUsdCents, 'USD', currency);
  const initialMinor = initialAmount ? money.toMinor(initialAmount, currency) : 0;

  const issued = issuer().issue({ brand, currency });
  const id = uuid();

  return db.tx((d) => {
    d.prepare(`INSERT INTO cards (id, user_id, label, brand, currency, pan_enc, pan_hash, last4, cvv_enc, exp_month, exp_year,
               single_use, lock_to_first_merchant, per_tx_limit, monthly_limit, blocked_categories, provider_ref)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`)
      .run(id, user.id, label || 'Ma carte', brand, currency, encrypt(issued.pan, id), panHash(issued.pan), issued.pan.slice(-4),
        encrypt(issued.cvv, id), issued.expMonth, issued.expYear, singleUse ? 1 : 0, lockToFirstMerchant ? 1 : 0,
        perTxLimit ? money.toMinor(perTxLimit, currency) : null, monthlyLimit ? money.toMinor(monthlyLimit, currency) : null,
        JSON.stringify(['gambling']), issued.providerRef);

    const cardAcc = ledger.cardAccount(id, currency);
    if (feeMinor + initialMinor === 0) {
      return publicCard(d.prepare('SELECT * FROM cards WHERE id=?').get(id));
    }
    // Frais de création : prélevés via le compte carte puis versés en commission.
    const plan = fundingPlan(user.id, src, cardAcc, feeMinor + initialMinor);
    ledger.post({ userId: user.id, type: 'card_load', amount: feeMinor + initialMinor, currency,
      fee: feeMinor, description: `Création de la carte ${label || ''} •••• ${issued.pan.slice(-4)}`.replace(/\s+/g, ' '),
      reference: id, metadata: { card_id: id, debited: plan.debited, debited_currency: plan.debitedCurrency },
      entries: [...plan.entries, { account: cardAcc, amount: -feeMinor }, { account: ledger.system('fees', currency), amount: feeMinor }] });

    notify(user.id, 'Carte créée', `Votre carte ${brand.toUpperCase()} ${currency} •••• ${issued.pan.slice(-4)} est prête à l’emploi.`);
    return publicCard(d.prepare('SELECT * FROM cards WHERE id=?').get(id));
  });
}

function loadCard(user, cardId, amount, sourceCurrency) {
  const card = getCard(user.id, cardId);
  if (card.status === 'terminated') throw new AppError(409, 'CARD_TERMINATED', 'Carte résiliée');
  const minor = money.toMinor(amount, card.currency);
  if (minor <= 0) throw new AppError(400, 'INVALID_AMOUNT', 'Montant invalide');
  const src = (sourceCurrency || card.currency).toUpperCase();
  const acc = ledger.cardAccount(card.id, card.currency);
  const plan = fundingPlan(user.id, src, acc, minor);
  ledger.post({ userId: user.id, type: 'card_load', amount: minor, currency: card.currency, fee: 0,
    description: `Recharge carte •••• ${card.last4}` + (src !== card.currency ? ` depuis ${src}` : ''), reference: card.id,
    metadata: { card_id: card.id, debited: plan.debited, debited_currency: plan.debitedCurrency, fx_fee: plan.fxFee },
    entries: plan.entries });
  return publicCard(card);
}

function unloadCard(user, cardId, amount) {
  const card = getCard(user.id, cardId);
  const minor = money.toMinor(amount, card.currency);
  ledger.post({ userId: user.id, type: 'card_unload', amount: minor, currency: card.currency,
    description: `Retour vers le portefeuille depuis •••• ${card.last4}`, reference: card.id, metadata: { card_id: card.id },
    entries: [{ account: ledger.cardAccount(card.id, card.currency), amount: -minor }, { account: ledger.wallet(user.id, card.currency), amount: minor }] });
  return publicCard(card);
}

function setStatus(user, cardId, status) {
  const card = getCard(user.id, cardId);
  if (card.status === 'terminated') throw new AppError(409, 'CARD_TERMINATED', 'Carte résiliée');
  if (status === 'terminated') {
    return db.tx((d) => {
      const acc = ledger.cardAccount(card.id, card.currency);
      if (acc.balance > 0) {
        ledger.post({ userId: user.id, type: 'card_unload', amount: acc.balance, currency: card.currency,
          description: `Solde restitué (résiliation •••• ${card.last4})`, reference: card.id,
          entries: [{ account: acc, amount: -acc.balance }, { account: ledger.wallet(user.id, card.currency), amount: acc.balance }] });
      }
      d.prepare("UPDATE cards SET status='terminated', terminated_at=? WHERE id=?").run(db.now(), card.id);
      return publicCard(d.prepare('SELECT * FROM cards WHERE id=?').get(card.id));
    });
  }
  db.get().prepare('UPDATE cards SET status=? WHERE id=?').run(status, card.id);
  return publicCard(getCard(user.id, cardId));
}

function updateControls(user, cardId, c) {
  const card = getCard(user.id, cardId);
  const d = db.get();
  if (c.label !== undefined) d.prepare('UPDATE cards SET label=? WHERE id=?').run(c.label, card.id);
  if (c.perTxLimit !== undefined) d.prepare('UPDATE cards SET per_tx_limit=? WHERE id=?').run(c.perTxLimit === null ? null : money.toMinor(c.perTxLimit, card.currency), card.id);
  if (c.monthlyLimit !== undefined) d.prepare('UPDATE cards SET monthly_limit=? WHERE id=?').run(c.monthlyLimit === null ? null : money.toMinor(c.monthlyLimit, card.currency), card.id);
  if (c.blockedCategories !== undefined) {
    const bad = c.blockedCategories.filter((k) => !CATEGORIES[k]);
    if (bad.length) throw new AppError(400, 'INVALID_CATEGORY', `Catégories inconnues : ${bad.join(', ')}`);
    d.prepare('UPDATE cards SET blocked_categories=? WHERE id=?').run(JSON.stringify(c.blockedCategories), card.id);
  }
  if (c.allowedCountries !== undefined) d.prepare('UPDATE cards SET allowed_countries=? WHERE id=?').run(c.allowedCountries ? JSON.stringify(c.allowedCountries.map((x) => x.toUpperCase())) : null, card.id);
  if (c.merchantLock !== undefined) d.prepare('UPDATE cards SET merchant_lock=? WHERE id=?').run(c.merchantLock || null, card.id);
  return publicCard(getCard(user.id, cardId));
}

function reveal(user, cardId) {
  const card = getCard(user.id, cardId);
  if (card.status === 'terminated') throw new AppError(409, 'CARD_TERMINATED', 'Carte résiliée');
  const pan = decrypt(card.pan_enc, card.id);
  return { pan: pan.replace(/(\d{4})(?=\d)/g, '$1 '), cvv: decrypt(card.cvv_enc, card.id),
    expMonth: card.exp_month, expYear: card.exp_year, holder: user.full_name.toUpperCase() };
}

// ------------------------------------------------------------------ Autorisations (réseau)
function decline(card, input, reason, risk = 0) {
  const id = uuid();
  db.get().prepare(`INSERT INTO card_authorizations (id, card_id, merchant_name, merchant_category, merchant_country, amount, currency,
                    billed_amount, billed_currency, status, decline_reason, risk_score) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)`)
    .run(id, card ? card.id : 'unknown', input.merchantName, input.merchantCategory, input.merchantCountry, input.amountMinor || 0,
      input.currency, 0, card ? card.currency : input.currency, 'declined', reason, risk);
  if (card) notify(card.user_id, 'Paiement refusé', `${input.merchantName} : ${reason} (carte •••• ${card.last4}).`);
  return { approved: false, authorizationId: id, reason };
}

function riskScore(card, billedMinor, balance) {
  const d = db.get();
  const since = new Date(Date.now() - 10 * 60 * 1000).toISOString();
  const recent = d.prepare("SELECT status, COUNT(*) AS n FROM card_authorizations WHERE card_id=? AND created_at>=? GROUP BY status").all(card.id, since);
  const approved = recent.find((r) => r.status === 'approved')?.n || 0;
  const declined = recent.find((r) => r.status === 'declined')?.n || 0;
  let score = 0;
  if (approved >= 5) score += 40;           // rafale d'achats
  if (declined >= 3) score += 50;           // tentatives répétées (test de carte)
  const ageMin = (Date.now() - new Date(card.created_at).getTime()) / 60000;
  if (ageMin < 60 && fx.toUsdCents(billedMinor, card.currency) > 500_00) score += 30;
  if (balance > 0 && billedMinor > balance * 0.9) score += 10;
  return score;
}

/**
 * Simule la demande d'autorisation envoyée par le réseau (Visa/Mastercard) lors d'un achat.
 * En production, ce point d'entrée est appelé par le webhook "authorization request" de l'émetteur.
 */
function authorize(input) {
  const d = db.get();
  const amountCcy = input.currency.toUpperCase();
  input.currency = amountCcy;
  input.amountMinor = money.toMinor(input.amount, amountCcy);
  input.merchantCategory = CATEGORIES[input.merchantCategory] ? input.merchantCategory : 'other';
  input.merchantCountry = (input.merchantCountry || 'US').toUpperCase();
  const pan = String(input.pan).replace(/\s/g, '');
  const card = d.prepare('SELECT * FROM cards WHERE pan_hash=?').get(panHash(pan));
  if (!card) return decline(null, input, 'Carte inconnue');

  if (card.status === 'frozen') return decline(card, input, 'Carte gelée');
  if (card.status !== 'active') return decline(card, input, 'Carte résiliée');
  const user = d.prepare('SELECT * FROM users WHERE id=?').get(card.user_id);
  if (user.status !== 'active') return decline(card, input, 'Compte suspendu');
  const now = new Date();
  const expEnd = new Date(Date.UTC(card.exp_year, card.exp_month, 1));
  if (Number(input.expMonth) !== card.exp_month || Number(input.expYear) !== card.exp_year || expEnd <= now) {
    return decline(card, input, 'Date d’expiration invalide');
  }
  if (!safeEqual(String(input.cvv), decrypt(card.cvv_enc, card.id))) return decline(card, input, 'CVV incorrect', 20);
  if (card.single_use && card.used_once) return decline(card, input, 'Carte à usage unique déjà utilisée');
  const merchantKey = String(input.merchantName).trim().toLowerCase();
  if (card.merchant_lock && card.merchant_lock !== merchantKey) return decline(card, input, `Carte verrouillée sur le marchand « ${card.merchant_lock} »`);
  if (JSON.parse(card.blocked_categories || '[]').includes(input.merchantCategory)) return decline(card, input, 'Catégorie de marchand bloquée');
  if (card.allowed_countries && !JSON.parse(card.allowed_countries).includes(input.merchantCountry)) return decline(card, input, 'Pays du marchand non autorisé');

  // Conversion si le marchand facture dans une autre devise que la carte.
  let billed = input.amountMinor;
  let fee = 0;
  if (amountCcy !== card.currency) {
    money.currency(amountCcy);
    billed = fx.midConvert(input.amountMinor, amountCcy, card.currency);
    fee = money.bpsFee(billed, config.fees.cardCrossCurrencyBps);
  }
  const total = billed + fee;
  if (card.per_tx_limit != null && total > card.per_tx_limit) return decline(card, input, 'Plafond par transaction de la carte dépassé');
  if (card.monthly_limit != null && monthlySpent(card.id) + total > card.monthly_limit) return decline(card, input, 'Plafond mensuel de la carte atteint');

  const acc = ledger.cardAccount(card.id, card.currency);
  const risk = riskScore(card, total, acc.balance);
  if (risk >= 70) return decline(card, input, 'Transaction bloquée par l’anti-fraude', risk);
  if (acc.balance < total) return decline(card, input, 'Solde de la carte insuffisant', risk);

  return db.tx((dd) => {
    const tx = ledger.post({ userId: card.user_id, type: 'card_purchase', amount: total, currency: card.currency, fee,
      description: `${input.merchantName}${amountCcy !== card.currency ? ` (${money.format(input.amountMinor, amountCcy)})` : ''}`,
      reference: card.id, metadata: { card_id: card.id, merchant: input.merchantName, category: input.merchantCategory, country: input.merchantCountry },
      entries: [
        { account: acc, amount: -total },
        { account: ledger.system('fees', card.currency), amount: fee },
        { account: ledger.system('card_network', card.currency), amount: total - fee },
      ] });
    const id = uuid();
    dd.prepare(`INSERT INTO card_authorizations (id, card_id, merchant_name, merchant_category, merchant_country, amount, currency,
                billed_amount, billed_currency, fee, status, risk_score, transaction_id) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)`)
      .run(id, card.id, input.merchantName, input.merchantCategory, input.merchantCountry, input.amountMinor, amountCcy,
        total, card.currency, fee, 'approved', risk, tx.id);
    if (card.single_use) dd.prepare('UPDATE cards SET used_once=1 WHERE id=?').run(card.id);
    if (card.lock_to_first_merchant && !card.merchant_lock) dd.prepare('UPDATE cards SET merchant_lock=? WHERE id=?').run(merchantKey, card.id);
    notify(card.user_id, 'Paiement accepté', `${money.format(total, card.currency)} chez ${input.merchantName} (•••• ${card.last4}).`);
    return { approved: true, authorizationId: id, billedAmount: money.toMajor(total, card.currency), billedCurrency: card.currency,
      fee: money.toMajor(fee, card.currency) };
  });
}

/** Remboursement marchand d'une autorisation approuvée. */
function refund(authorizationId) {
  return db.tx((d) => {
    const a = d.prepare('SELECT * FROM card_authorizations WHERE id=?').get(authorizationId);
    if (!a || a.status !== 'approved') throw new AppError(404, 'AUTH_NOT_FOUND', 'Autorisation introuvable ou non remboursable');
    ledger.reverse(a.transaction_id, 'reversed');
    d.prepare("UPDATE card_authorizations SET status='reversed' WHERE id=?").run(a.id);
    const card = d.prepare('SELECT * FROM cards WHERE id=?').get(a.card_id);
    notify(card.user_id, 'Remboursement reçu', `${money.format(a.billed_amount, a.billed_currency)} remboursés par ${a.merchant_name}.`);
    return { ok: true };
  });
}

function authorizations(user, cardId) {
  getCard(user.id, cardId);
  return db.get().prepare('SELECT * FROM card_authorizations WHERE card_id=? ORDER BY created_at DESC LIMIT 100').all(cardId)
    .map((a) => ({ id: a.id, merchant: a.merchant_name, category: a.merchant_category, country: a.merchant_country,
      amount: money.toMajor(a.amount, a.currency), currency: a.currency, billedAmount: money.toMajor(a.billed_amount, a.billed_currency),
      billedCurrency: a.billed_currency, status: a.status, declineReason: a.decline_reason, createdAt: a.created_at }));
}

function list(user) {
  return db.get().prepare('SELECT * FROM cards WHERE user_id=? ORDER BY created_at DESC').all(user.id).map(publicCard);
}

module.exports = { CATEGORIES, createCard, loadCard, unloadCard, previewLoad, setStatus, updateControls, reveal, authorize, refund,
  authorizations, list, getCard, publicCard };
