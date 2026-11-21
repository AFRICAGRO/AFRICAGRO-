'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { DatabaseSync } = require('node:sqlite');
const config = require('../config');

const SCHEMA = `
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  phone TEXT UNIQUE NOT NULL,
  full_name TEXT NOT NULL,
  country TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  pin_hash TEXT,
  role TEXT NOT NULL DEFAULT 'user',              -- user | admin
  status TEXT NOT NULL DEFAULT 'active',          -- active | frozen | closed
  kyc_level INTEGER NOT NULL DEFAULT 0,
  totp_secret_enc TEXT,
  totp_enabled INTEGER NOT NULL DEFAULT 0,
  failed_logins INTEGER NOT NULL DEFAULT 0,
  locked_until TEXT,
  failed_pins INTEGER NOT NULL DEFAULT 0,
  pin_locked_until TEXT,
  preferred_currency TEXT NOT NULL DEFAULT 'USD',
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  token_hash TEXT UNIQUE NOT NULL,
  family TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  revoked_at TEXT,
  user_agent TEXT,
  ip TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS kyc_submissions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  target_level INTEGER NOT NULL,
  id_type TEXT NOT NULL,
  id_number_enc TEXT NOT NULL,
  date_of_birth TEXT NOT NULL,
  address TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',        -- pending | approved | rejected
  reviewer_id TEXT,
  review_note TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  reviewed_at TEXT
);

-- Grand livre en partie double -------------------------------------------
CREATE TABLE IF NOT EXISTS accounts (
  id TEXT PRIMARY KEY,
  owner_type TEXT NOT NULL,                     -- user | card | system
  owner_id TEXT NOT NULL,
  kind TEXT NOT NULL,                           -- wallet | card | mm_float | fx_pool | fees | card_network
  currency TEXT NOT NULL,
  balance INTEGER NOT NULL DEFAULT 0,           -- unités mineures
  allow_negative INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  UNIQUE(owner_type, owner_id, kind, currency)
);

CREATE TABLE IF NOT EXISTS transactions (
  id TEXT PRIMARY KEY,
  user_id TEXT,
  type TEXT NOT NULL,      -- deposit | withdrawal | fx | card_load | card_unload | card_purchase | card_refund | p2p | fee
  status TEXT NOT NULL,    -- pending | completed | failed | declined | reversed
  amount INTEGER NOT NULL,
  currency TEXT NOT NULL,
  fee INTEGER NOT NULL DEFAULT 0,
  description TEXT,
  reference TEXT,
  metadata TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_tx_user ON transactions(user_id, created_at);

CREATE TABLE IF NOT EXISTS ledger_entries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  transaction_id TEXT NOT NULL REFERENCES transactions(id),
  account_id TEXT NOT NULL REFERENCES accounts(id),
  amount INTEGER NOT NULL,       -- positif = crédit, négatif = débit
  currency TEXT NOT NULL,
  balance_after INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_le_account ON ledger_entries(account_id);

-- Mobile Money ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mobile_money_ops (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  direction TEXT NOT NULL,                     -- deposit | withdrawal
  provider TEXT NOT NULL,
  provider_ref TEXT,
  country TEXT NOT NULL,
  operator TEXT NOT NULL,
  phone TEXT NOT NULL,
  amount INTEGER NOT NULL,
  currency TEXT NOT NULL,
  fee INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending',      -- pending | completed | failed
  transaction_id TEXT,
  failure_reason TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_mm_user ON mobile_money_ops(user_id, created_at);

-- Change ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fx_quotes (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  from_currency TEXT NOT NULL,
  to_currency TEXT NOT NULL,
  from_amount INTEGER NOT NULL,
  to_amount INTEGER NOT NULL,
  fee INTEGER NOT NULL,
  rate TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  used_at TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

-- Cartes virtuelles -------------------------------------------------------
CREATE TABLE IF NOT EXISTS cards (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  label TEXT NOT NULL,
  brand TEXT NOT NULL,                         -- visa | mastercard
  currency TEXT NOT NULL,
  pan_enc TEXT NOT NULL,
  pan_hash TEXT UNIQUE NOT NULL,
  last4 TEXT NOT NULL,
  cvv_enc TEXT NOT NULL,
  exp_month INTEGER NOT NULL,
  exp_year INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',       -- active | frozen | terminated
  single_use INTEGER NOT NULL DEFAULT 0,
  used_once INTEGER NOT NULL DEFAULT 0,
  merchant_lock TEXT,                          -- verrouillage marchand (abonnements)
  lock_to_first_merchant INTEGER NOT NULL DEFAULT 0,
  per_tx_limit INTEGER,                        -- unités mineures de la devise de la carte
  monthly_limit INTEGER,
  blocked_categories TEXT NOT NULL DEFAULT '[]',
  allowed_countries TEXT,                      -- JSON ou NULL = tous
  provider_ref TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  terminated_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_cards_user ON cards(user_id);

CREATE TABLE IF NOT EXISTS card_authorizations (
  id TEXT PRIMARY KEY,
  card_id TEXT NOT NULL REFERENCES cards(id),
  merchant_name TEXT NOT NULL,
  merchant_category TEXT NOT NULL,
  merchant_country TEXT NOT NULL,
  amount INTEGER NOT NULL,                     -- montant marchand
  currency TEXT NOT NULL,
  billed_amount INTEGER NOT NULL,              -- montant débité dans la devise carte
  billed_currency TEXT NOT NULL,
  fee INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL,                        -- approved | declined | reversed
  decline_reason TEXT,
  risk_score INTEGER NOT NULL DEFAULT 0,
  transaction_id TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_auth_card ON card_authorizations(card_id, created_at);

-- Sécurité / conformité ---------------------------------------------------
CREATE TABLE IF NOT EXISTS idempotency_keys (
  key TEXT NOT NULL,
  user_id TEXT NOT NULL,
  request_hash TEXT NOT NULL,
  response_status INTEGER,
  response_body TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  PRIMARY KEY (key, user_id)
);

CREATE TABLE IF NOT EXISTS audit_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT,
  action TEXT NOT NULL,
  ip TEXT,
  details TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_logs(user_id, created_at);

CREATE TABLE IF NOT EXISTS notifications (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  read_at TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS webhook_events (
  id TEXT PRIMARY KEY,                         -- provider:event_id (anti-rejeu)
  provider TEXT NOT NULL,
  payload TEXT NOT NULL,
  received_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
`;

let db;

function open(dbPath = config.dbPath) {
  if (dbPath !== ':memory:') fs.mkdirSync(path.dirname(path.resolve(dbPath)), { recursive: true });
  db = new DatabaseSync(dbPath);
  db.exec('PRAGMA journal_mode = WAL;');
  db.exec('PRAGMA busy_timeout = 5000;');
  db.exec(SCHEMA);
  return db;
}

function get() {
  if (!db) open();
  return db;
}

let depth = 0;
/** Exécute `fn` dans une transaction SQLite atomique (imbrication via SAVEPOINT). */
function tx(fn) {
  const d = get();
  const sp = `sp_${depth}`;
  if (depth === 0) d.exec('BEGIN IMMEDIATE'); else d.exec(`SAVEPOINT ${sp}`);
  depth++;
  try {
    const result = fn(d);
    depth--;
    if (depth === 0) d.exec('COMMIT'); else d.exec(`RELEASE ${sp}`);
    return result;
  } catch (err) {
    depth--;
    if (depth === 0) d.exec('ROLLBACK'); else d.exec(`ROLLBACK TO ${sp}; RELEASE ${sp}`);
    throw err;
  }
}

const now = () => new Date().toISOString();

module.exports = { open, get, tx, now };
