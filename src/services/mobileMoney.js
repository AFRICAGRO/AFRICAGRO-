'use strict';
// Dépôts (collecte) et retraits (décaissement) Mobile Money.
const config = require('../config');
const db = require('../db');
const ledger = require('./ledger');
const limits = require('./limits');
const money = require('../lib/money');
const { notify } = require('./notify');
const { uuid } = require('../lib/crypto');
const { AppError } = require('../lib/errors');
const { getCountry, getOperator, normalizePhone } = require('../data/countries');
const { providerFor, PROVIDERS } = require('../providers/mobileMoney');

function validate({ country, operator, phone, amount }) {
  const c = getCountry(country);
  if (!c) throw new AppError(400, 'UNSUPPORTED_COUNTRY', 'Pays non pris en charge');
  const o = getOperator(country, operator);
  if (!o) throw new AppError(400, 'UNSUPPORTED_OPERATOR', 'Opérateur non disponible dans ce pays');
  const e164 = normalizePhone(country, phone);
  if (!e164) throw new AppError(400, 'INVALID_PHONE', `Numéro invalide pour ${c.name} (+${c.dial})`);
  const minor = money.toMinor(amount, c.currency);
  if (minor < money.toMinor(String(c.min), c.currency) || minor > money.toMinor(String(c.max), c.currency)) {
    throw new AppError(400, 'AMOUNT_OUT_OF_RANGE', `Montant autorisé : ${c.min} à ${c.max} ${c.currency}`);
  }
  return { c, o, e164, minor, currency: c.currency };
}

function quoteFee(direction, minor) {
  return money.bpsFee(minor, direction === 'deposit' ? config.fees.depositBps : config.fees.withdrawalBps);
}

async function initiateDeposit(user, input) {
  const { c, o, e164, minor, currency } = validate(input);
  limits.assertWithinLimits(user, minor, currency, { kind: 'deposit' });
  const fee = quoteFee('deposit', minor);
  const provider = providerFor(input.country);
  const opId = uuid();

  const tx = ledger.post({ userId: user.id, type: 'deposit', status: 'pending', amount: minor, currency, fee,
    description: `Dépôt ${o.name} (${e164})`, reference: opId, metadata: { operator: o.code, phone: e164 } });

  db.get().prepare(`INSERT INTO mobile_money_ops (id, user_id, direction, provider, country, operator, phone, amount, currency, fee, transaction_id)
                    VALUES (?,?,?,?,?,?,?,?,?,?,?)`)
    .run(opId, user.id, 'deposit', provider.name, input.country, o.code, e164, minor, currency, fee, tx.id);

  let result;
  try {
    result = await provider.initiateCollection({
      opId, phone: e164, operatorCode: o.code, operatorName: o.name, amountMajor: money.toMajor(minor, currency),
      currency, country: input.country, email: user.email, customerName: user.full_name,
      description: `Recharge AfriCard ${opId.slice(0, 8)}`,
    });
  } catch (err) {
    finalize(opId, 'failed', err.message);
    throw err;
  }
  db.get().prepare('UPDATE mobile_money_ops SET provider_ref=? WHERE id=?').run(result.providerRef, opId);
  if (result.status === 'failed') {
    finalize(opId, 'failed', result.reason);
    throw new AppError(402, 'DEPOSIT_REFUSED', result.reason || 'Paiement refusé par l’opérateur');
  }
  return { id: opId, status: 'pending', amount: money.toMajor(minor, currency), fee: money.toMajor(fee, currency),
    net: money.toMajor(minor - fee, currency), currency, instructions: result.instructions, redirectUrl: result.redirectUrl || null,
    provider: provider.name };
}

async function initiateWithdrawal(user, input) {
  const { o, e164, minor, currency } = validate(input);
  limits.assertWithinLimits(user, minor, currency, { kind: 'withdrawal' });
  const fee = quoteFee('withdrawal', minor);
  const provider = providerFor(input.country);
  const opId = uuid();

  // Les fonds sont débités immédiatement (réservés) puis restitués si le décaissement échoue.
  const tx = ledger.post({ userId: user.id, type: 'withdrawal', status: 'pending', amount: minor, currency, fee,
    description: `Retrait vers ${o.name} (${e164})`, reference: opId, metadata: { operator: o.code, phone: e164 },
    entries: [
      { account: ledger.wallet(user.id, currency), amount: -minor },
      { account: ledger.system('fees', currency), amount: fee },
      { account: ledger.system('mm_float', currency), amount: minor - fee },
    ] });

  db.get().prepare(`INSERT INTO mobile_money_ops (id, user_id, direction, provider, country, operator, phone, amount, currency, fee, transaction_id)
                    VALUES (?,?,?,?,?,?,?,?,?,?,?)`)
    .run(opId, user.id, 'withdrawal', provider.name, input.country, o.code, e164, minor, currency, fee, tx.id);

  let result;
  try {
    result = await provider.initiatePayout({ opId, phone: e164, operatorCode: o.code, amountMajor: money.toMajor(minor - fee, currency),
      currency, customerName: user.full_name });
  } catch (err) {
    finalize(opId, 'failed', err.message);
    throw err;
  }
  db.get().prepare('UPDATE mobile_money_ops SET provider_ref=? WHERE id=?').run(result.providerRef, opId);
  if (result.status !== 'pending') finalize(opId, result.status, result.reason);
  const op = getOp(opId);
  if (op.status === 'failed') throw new AppError(422, 'WITHDRAWAL_FAILED', result.reason || 'Retrait refusé par l’opérateur');
  return publicOp(op);
}

/** Finalise une opération (idempotent) : crédit du portefeuille ou restitution des fonds. */
function finalize(opId, status, reason) {
  return db.tx((d) => {
    const op = d.prepare('SELECT * FROM mobile_money_ops WHERE id=?').get(opId);
    if (!op) throw new AppError(404, 'OP_NOT_FOUND', 'Opération introuvable');
    if (op.status !== 'pending' || !['completed', 'failed'].includes(status)) return op;

    if (op.direction === 'deposit') {
      if (status === 'completed') {
        ledger.settle(op.transaction_id, { status: 'completed', entries: [
          { account: ledger.system('mm_float', op.currency), amount: -op.amount },
          { account: ledger.system('fees', op.currency), amount: op.fee },
          { account: ledger.wallet(op.user_id, op.currency), amount: op.amount - op.fee },
        ] });
        notify(op.user_id, 'Dépôt reçu', `${money.format(op.amount - op.fee, op.currency)} ont été crédités sur votre portefeuille.`);
      } else {
        ledger.settle(op.transaction_id, { status: 'failed' });
        notify(op.user_id, 'Dépôt échoué', reason || 'Le paiement Mobile Money n’a pas abouti.');
      }
    } else if (status === 'completed') {
      ledger.settle(op.transaction_id, { status: 'completed' });
      notify(op.user_id, 'Retrait effectué', `${money.format(op.amount - op.fee, op.currency)} envoyés au ${op.phone}.`);
    } else {
      ledger.reverse(op.transaction_id, 'failed');
      notify(op.user_id, 'Retrait échoué', `${reason || 'Le décaissement a échoué.'} Vos fonds ont été restitués.`);
    }
    d.prepare('UPDATE mobile_money_ops SET status=?, failure_reason=?, updated_at=? WHERE id=?').run(status, reason || null, db.now(), opId);
    return d.prepare('SELECT * FROM mobile_money_ops WHERE id=?').get(opId);
  });
}

/** Traite un webhook fournisseur vérifié. Anti-rejeu via l'identifiant d'événement. */
async function handleWebhook(providerName, req) {
  const provider = PROVIDERS[providerName];
  if (!provider) throw new AppError(404, 'UNKNOWN_PROVIDER', 'Fournisseur inconnu');
  if (!provider.verifyWebhook(req)) throw new AppError(401, 'BAD_SIGNATURE', 'Signature de webhook invalide');
  const evt = provider.parseWebhook(req.body || {});
  if (!evt.opId || !evt.eventId) throw new AppError(400, 'BAD_PAYLOAD', 'Notification incomplète');

  const d = db.get();
  const seen = d.prepare('SELECT 1 FROM webhook_events WHERE id=?').get(`${providerName}:${evt.eventId}`);
  if (seen) return { duplicate: true };
  d.prepare('INSERT INTO webhook_events (id, provider, payload) VALUES (?,?,?)').run(`${providerName}:${evt.eventId}`, providerName, JSON.stringify(req.body));

  const op = getOp(evt.opId);
  if (!op || op.provider !== providerName) throw new AppError(404, 'OP_NOT_FOUND', 'Opération introuvable');

  let status = evt.status;
  if (status === 'verify' && provider.checkStatus) status = await provider.checkStatus(evt.opId);
  if (status === 'completed' || status === 'failed') finalize(evt.opId, status, evt.reason);
  return { ok: true, status };
}

function getOp(id) {
  return db.get().prepare('SELECT * FROM mobile_money_ops WHERE id=?').get(id);
}

function publicOp(op) {
  return { id: op.id, direction: op.direction, status: op.status, country: op.country, operator: op.operator, phone: op.phone,
    amount: money.toMajor(op.amount, op.currency), fee: money.toMajor(op.fee, op.currency),
    net: money.toMajor(op.amount - op.fee, op.currency), currency: op.currency, failureReason: op.failure_reason,
    provider: op.provider, createdAt: op.created_at };
}

module.exports = { initiateDeposit, initiateWithdrawal, finalize, handleWebhook, getOp, publicOp, quoteFee, validate };
