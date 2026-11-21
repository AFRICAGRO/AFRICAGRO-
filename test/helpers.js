'use strict';
process.env.NODE_ENV = 'test';
process.env.DB_PATH = ':memory:';
process.env.SANDBOX_AUTO_APPROVE_KYC = 'true';

const db = require('../src/db');
const { createApp } = require('../src/app');

async function startServer() {
  db.open(':memory:');
  const app = createApp();
  const server = await new Promise((resolve) => { const s = app.listen(0, () => resolve(s)); });
  const base = `http://127.0.0.1:${server.address().port}/api`;

  async function call(method, path, { token, body, headers = {}, cookie } = {}) {
    const res = await fetch(base + path, {
      method,
      headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}), ...(cookie ? { Cookie: cookie } : {}), ...headers },
      body: body ? JSON.stringify(body) : undefined,
    });
    const text = await res.text();
    let json; try { json = JSON.parse(text); } catch { json = text; }
    return { status: res.status, body: json, headers: res.headers };
  }

  let n = 0;
  async function newUser({ country = 'CI', phone, kyc = true, pin = '2580' } = {}) {
    n += 1;
    const r = await call('POST', '/auth/register', { body: {
      fullName: `Testeur ${n}`, email: `user${n}_${Date.now()}@test.africa`, country,
      phone: phone || `07${String(10000000 + n * 7919).slice(0, 8)}`, password: 'MotDePasse123', acceptPrivacy: true, acceptTerms: true,
    } });
    if (r.status !== 201) throw new Error(`register failed: ${JSON.stringify(r.body)}`);
    const token = r.body.accessToken;
    const cookie = r.headers.get('set-cookie').split(';')[0];
    await call('POST', '/security/pin', { token, body: { pin, password: 'MotDePasse123' } });
    if (kyc) {
      await call('POST', '/kyc', { token, body: { targetLevel: 1, idType: 'cni', idNumber: 'CI00123456', dateOfBirth: '1990-05-12', address: 'Cocody, Abidjan' } });
    }
    return { token, cookie, user: r.body.user, pin };
  }

  async function deposit(token, { country = 'CI', operator = 'ORANGE_CI', phone = '0701020304', amount = '100000' } = {}) {
    const r = await call('POST', '/deposits', { token, body: { country, operator, phone, amount } });
    if (r.status !== 201) throw new Error(`deposit failed: ${JSON.stringify(r.body)}`);
    const c = await call('POST', `/sandbox/mobile-money/${r.body.id}/confirm`, { token, body: { success: true } });
    return c.body;
  }

  return { server, call, newUser, deposit, close: () => new Promise((r) => server.close(r)) };
}

module.exports = { startServer };
