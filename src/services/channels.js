'use strict';
// Canaux d'envoi réels. Chaque fonction lève une erreur en cas d'échec (l'agent relance).
const config = require('../config');

const N = () => config.notifications;
const quiet = config.env === 'test';
const timeout = () => AbortSignal.timeout(10000);

async function check(res, label) {
  if (!res.ok) throw new Error(`${label} : HTTP ${res.status} ${(await res.text()).slice(0, 200)}`);
}

async function sendEmail(to, subject, text) {
  const n = N();
  if (n.emailProvider === 'console') { if (!quiet) console.log(`[email → ${to}] ${subject}\n${text}`); return; }
  if (n.emailProvider === 'resend') {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST', headers: { Authorization: `Bearer ${n.resendApiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ from: n.emailFrom, to: [to], subject, text }), signal: timeout() });
    return check(res, 'Resend');
  }
  if (n.emailProvider === 'brevo') {
    const m = /^(.*)<(.+)>$/.exec(n.emailFrom);
    const res = await fetch('https://api.brevo.com/v3/smtp/email', {
      method: 'POST', headers: { 'api-key': n.brevoApiKey, 'Content-Type': 'application/json' },
      body: JSON.stringify({ sender: m ? { name: m[1].trim(), email: m[2] } : { email: n.emailFrom }, to: [{ email: to }], subject, textContent: text }),
      signal: timeout() });
    return check(res, 'Brevo');
  }
  throw new Error(`Fournisseur e-mail inconnu : ${n.emailProvider}`);
}

async function sendSms(to, text) {
  const n = N();
  if (n.smsProvider === 'console') { if (!quiet) console.log(`[sms → ${to}] ${text}`); return; }
  if (n.smsProvider === 'africastalking') {
    const res = await fetch('https://api.africastalking.com/version1/messaging', {
      method: 'POST',
      headers: { apiKey: n.africasTalking.apiKey, Accept: 'application/json', 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ username: n.africasTalking.username, to, message: text, from: n.smsSender }), signal: timeout() });
    return check(res, "Africa's Talking");
  }
  if (n.smsProvider === 'twilio') {
    const { sid, token, from } = n.twilio;
    const res = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`, {
      method: 'POST',
      headers: { Authorization: `Basic ${Buffer.from(`${sid}:${token}`).toString('base64')}`, 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ To: to, From: from, Body: text }), signal: timeout() });
    return check(res, 'Twilio');
  }
  throw new Error(`Fournisseur SMS inconnu : ${n.smsProvider}`);
}

/** Alerte équipe : webhook compatible Slack/Discord/Teams et/ou Telegram ; sinon console. */
async function sendAdmin(text) {
  const n = N();
  let sent = false;
  if (n.adminWebhookUrl) {
    const res = await fetch(n.adminWebhookUrl, { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text, content: text }), signal: timeout() });
    await check(res, 'Webhook admin'); sent = true;
  }
  if (n.telegramBotToken && n.telegramChatId) {
    const res = await fetch(`https://api.telegram.org/bot${n.telegramBotToken}/sendMessage`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ chat_id: n.telegramChatId, text }), signal: timeout() });
    await check(res, 'Telegram'); sent = true;
  }
  if (!sent && !quiet) console.warn(`[alerte admin] ${text}`);
}

async function deliver(row) {
  if (row.channel === 'email') return sendEmail(row.recipient, row.subject, row.body);
  if (row.channel === 'sms') return sendSms(row.recipient, row.body);
  if (row.channel === 'admin') return sendAdmin(row.body);
  throw new Error(`Canal inconnu : ${row.channel}`);
}

module.exports = { deliver, sendEmail, sendSms, sendAdmin };
