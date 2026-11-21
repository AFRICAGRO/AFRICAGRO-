'use strict';
// Grand livre en partie double : chaque mouvement est équilibré (somme nulle par devise)
// et les soldes clients ne peuvent jamais devenir négatifs.
const db = require('../db');
const { uuid } = require('../lib/crypto');
const { AppError } = require('../lib/errors');
const money = require('../lib/money');

const SYSTEM = 'platform';
// Comptes systèmes autorisés en négatif (actifs : float chez l'agrégateur, réseau carte, réserve de change).
const SYSTEM_NEGATIVE = new Set(['mm_float', 'fx_pool', 'card_network']);

function getOrCreateAccount(ownerType, ownerId, kind, currency) {
  money.currency(currency);
  const d = db.get();
  let acc = d.prepare('SELECT * FROM accounts WHERE owner_type=? AND owner_id=? AND kind=? AND currency=?')
    .get(ownerType, ownerId, kind, currency);
  if (!acc) {
    const id = uuid();
    const allowNeg = ownerType === 'system' && SYSTEM_NEGATIVE.has(kind) ? 1 : 0;
    d.prepare('INSERT INTO accounts (id, owner_type, owner_id, kind, currency, allow_negative) VALUES (?,?,?,?,?,?)')
      .run(id, ownerType, ownerId, kind, currency, allowNeg);
    acc = d.prepare('SELECT * FROM accounts WHERE id=?').get(id);
  }
  return acc;
}

const wallet = (userId, currency) => getOrCreateAccount('user', userId, 'wallet', currency);
const cardAccount = (cardId, currency) => getOrCreateAccount('card', cardId, 'card', currency);
const system = (kind, currency) => getOrCreateAccount('system', SYSTEM, kind, currency);

function checkBalanced(entries) {
  const sums = {};
  for (const e of entries) {
    if (!Number.isSafeInteger(e.amount)) throw new Error('Montant d’écriture invalide');
    sums[e.account.currency] = (sums[e.account.currency] || 0) + e.amount;
  }
  for (const [ccy, s] of Object.entries(sums)) {
    if (s !== 0) throw new Error(`Écritures déséquilibrées en ${ccy} (${s})`);
  }
}

function applyEntries(d, txId, entries) {
  checkBalanced(entries);
  for (const e of entries) {
    if (e.amount === 0) continue;
    const acc = d.prepare('SELECT * FROM accounts WHERE id=?').get(e.account.id);
    const newBal = acc.balance + e.amount;
    if (newBal < 0 && !acc.allow_negative) {
      throw new AppError(402, 'INSUFFICIENT_FUNDS', `Solde insuffisant (${money.format(acc.balance, acc.currency)} disponible)`);
    }
    d.prepare('UPDATE accounts SET balance=? WHERE id=?').run(newBal, acc.id);
    d.prepare('INSERT INTO ledger_entries (transaction_id, account_id, amount, currency, balance_after) VALUES (?,?,?,?,?)')
      .run(txId, acc.id, e.amount, acc.currency, newBal);
  }
}

/**
 * Enregistre une transaction et ses écritures de manière atomique.
 * entries: [{ account, amount }] — amount positif = crédit, négatif = débit.
 */
function post({ userId = null, type, status = 'completed', amount, currency, fee = 0, description = '', reference = null, metadata = null, entries = [], id = uuid() }) {
  return db.tx((d) => {
    d.prepare(`INSERT INTO transactions (id, user_id, type, status, amount, currency, fee, description, reference, metadata)
               VALUES (?,?,?,?,?,?,?,?,?,?)`)
      .run(id, userId, type, status, amount, currency, fee, description, reference, metadata ? JSON.stringify(metadata) : null);
    applyEntries(d, id, entries);
    return d.prepare('SELECT * FROM transactions WHERE id=?').get(id);
  });
}

/** Finalise une transaction existante (ex. dépôt confirmé) en ajoutant ses écritures. */
function settle(txId, { status, entries = [] }) {
  return db.tx((d) => {
    applyEntries(d, txId, entries);
    d.prepare('UPDATE transactions SET status=?, updated_at=? WHERE id=?').run(status, db.now(), txId);
    return d.prepare('SELECT * FROM transactions WHERE id=?').get(txId);
  });
}

/** Annule les écritures d'une transaction en passant des écritures inverses. */
function reverse(txId, status = 'reversed') {
  return db.tx((d) => {
    const rows = d.prepare('SELECT account_id, amount FROM ledger_entries WHERE transaction_id=?').all(txId);
    const entries = rows.map((r) => ({ account: d.prepare('SELECT * FROM accounts WHERE id=?').get(r.account_id), amount: -r.amount }));
    applyEntries(d, txId, entries);
    d.prepare('UPDATE transactions SET status=?, updated_at=? WHERE id=?').run(status, db.now(), txId);
    return d.prepare('SELECT * FROM transactions WHERE id=?').get(txId);
  });
}

function balance(accountId) {
  return db.get().prepare('SELECT balance FROM accounts WHERE id=?').get(accountId)?.balance ?? 0;
}

function userWallets(userId) {
  return db.get().prepare("SELECT currency, balance FROM accounts WHERE owner_type='user' AND owner_id=? AND kind='wallet' ORDER BY currency")
    .all(userId);
}

/** Vérification d'intégrité : la somme de toutes les écritures par devise doit être nulle. */
function integrityCheck() {
  const d = db.get();
  const sums = d.prepare('SELECT currency, SUM(amount) AS total FROM ledger_entries GROUP BY currency').all();
  const unbalanced = sums.filter((s) => s.total !== 0);
  const drift = d.prepare(`SELECT a.id, a.balance, COALESCE(SUM(e.amount),0) AS computed
                           FROM accounts a LEFT JOIN ledger_entries e ON e.account_id=a.id
                           GROUP BY a.id HAVING a.balance != computed`).all();
  return { ok: unbalanced.length === 0 && drift.length === 0, unbalanced, drift };
}

module.exports = { getOrCreateAccount, wallet, cardAccount, system, post, settle, reverse, balance, userWallets, integrityCheck };
