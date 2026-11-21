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

-- Agents automatiques ----------------------------------------------------
CREATE TABLE IF NOT EXISTS agent_runs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  agent TEXT NOT NULL,
  status TEXT NOT NULL,                        -- ok | error
  summary TEXT,
  started_at TEXT NOT NULL,
  finished_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_agent_runs ON agent_runs(agent, id);

CREATE TABLE IF NOT EXISTS security_alerts (
  id TEXT PRIMARY KEY,
  severity TEXT NOT NULL,                      -- info | warning | critical
  type TEXT NOT NULL,
  user_id TEXT,
  message TEXT NOT NULL,
  details TEXT,
  dedupe_key TEXT UNIQUE,
  status TEXT NOT NULL DEFAULT 'open',         -- open | resolved
  resolved_by TEXT,
  resolved_at TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_alerts_status ON security_alerts(status, created_at);

CREATE TABLE IF NOT EXISTS ip_blocks (
  ip TEXT PRIMARY KEY,
  reason TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS error_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  fingerprint TEXT NOT NULL,
  message TEXT NOT NULL,
  stack TEXT,
  route TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_errors_fp ON error_events(fingerprint, created_at);

CREATE TABLE IF NOT EXISTS system_flags (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

-- File d'envoi des notifications (e-mail, SMS, alertes admin) avec relances
CREATE TABLE IF NOT EXISTS notification_outbox (
  id TEXT PRIMARY KEY,
  channel TEXT NOT NULL,                       -- email | sms | admin
  recipient TEXT,
  subject TEXT,
  body TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',      -- pending | sent | failed
  attempts INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  next_attempt_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  sent_at TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_outbox_pending ON notification_outbox(status, next_attempt_at);

-- Conformité / données personnelles --------------------------------------
CREATE TABLE IF NOT EXISTS consents (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  document TEXT NOT NULL,                      -- privacy | terms | marketing
  version TEXT NOT NULL,
  granted INTEGER NOT NULL DEFAULT 1,
  ip TEXT,
  user_agent TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_consents_user ON consents(user_id, document);

CREATE TABLE IF NOT EXISTS password_resets (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  code_hash TEXT NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  expires_at TEXT NOT NULL,
  used_at TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS support_tickets (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  category TEXT NOT NULL,
  subject TEXT NOT NULL,
  message TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open',         -- open | answered | closed
  reply TEXT,
  replied_by TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
`;

// Colonnes ajoutées après la première version (migrations idempotentes).
const COLUMN_MIGRATIONS = [
  ['users', 'notify_email', 'INTEGER NOT NULL DEFAULT 1'],
  ['users', 'notify_sms', 'INTEGER NOT NULL DEFAULT 1'],
  ['users', 'marketing_opt_in', 'INTEGER NOT NULL DEFAULT 0'],
  ['users', 'closed_at', 'TEXT'],
  ['notifications', 'category', "TEXT NOT NULL DEFAULT 'account'"],
  ['notifications', 'dedupe_key', 'TEXT'],
];

function migrate(d) {
  for (const [table, col, def] of COLUMN_MIGRATIONS) {
    const cols = d.prepare(`PRAGMA table_info(${table})`).all().map((c) => c.name);
    if (!cols.includes(col)) d.exec(`ALTER TABLE ${table} ADD COLUMN ${col} ${def}`);
  }
  d.exec('CREATE UNIQUE INDEX IF NOT EXISTS idx_notif_dedupe ON notifications(dedupe_key) WHERE dedupe_key IS NOT NULL');
}

let db;

function open(dbPath = config.dbPath) {
  if (dbPath !== ':memory:') fs.mkdirSync(path.dirname(path.resolve(dbPath)), { recursive: true });
  db = new DatabaseSync(dbPath);
  db.exec('PRAGMA journal_mode = WAL;');
  db.exec('PRAGMA busy_timeout = 5000;');
  db.exec(SCHEMA);
  migrate(db);
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
