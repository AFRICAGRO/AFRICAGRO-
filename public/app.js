'use strict';
/* AfriCard — application web (SPA sans dépendance, compatible connexions lentes). */
(() => {
  // ================================================================ Utilitaires
  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));
  const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  class Raw { constructor(s) { this.s = s; } toString() { return this.s; } }
  const raw = (s) => new Raw(s);
  /** Gabarit HTML qui échappe automatiquement toutes les valeurs (anti-XSS). */
  const html = (strings, ...vals) => raw(strings.reduce((out, s, i) => {
    if (i === 0) return s;
    const v = vals[i - 1];
    const str = v instanceof Raw ? v.s : Array.isArray(v) ? v.map((x) => (x instanceof Raw ? x.s : esc(x))).join('') : esc(v);
    return out + str + s;
  }, ''));
  const uuid = () => (crypto.randomUUID ? crypto.randomUUID() : String(Date.now()) + Math.random().toString(16).slice(2));

  const DEC = {};
  const SYM = {};
  function fmt(amount, ccy) {
    const d = DEC[ccy] ?? 2;
    const n = Number(amount);
    return `${n.toLocaleString('fr-FR', { minimumFractionDigits: d, maximumFractionDigits: d })} ${SYM[ccy] || ccy}`;
  }
  const dateFmt = (iso) => new Date(iso).toLocaleString('fr-FR', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' });

  // ================================================================ État & API
  const state = { token: null, user: null, limits: null, meta: null, unread: 0 };

  async function api(method, path, body, opts = {}) {
    const headers = { 'Content-Type': 'application/json' };
    if (state.token) headers.Authorization = `Bearer ${state.token}`;
    if (opts.idempotent) headers['Idempotency-Key'] = opts.idempotent;
    const res = await fetch(`/api${path}`, { method, headers, body: body ? JSON.stringify(body) : undefined, credentials: 'same-origin' });
    if (res.status === 401 && !opts.noRetry && path !== '/auth/refresh' && state.token) {
      if (await refresh()) return api(method, path, body, { ...opts, noRetry: true });
      logoutLocal();
    }
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      const err = new Error(data?.error?.message || 'Une erreur est survenue');
      err.code = data?.error?.code; err.status = res.status;
      if (err.code === 'CONSENT_REQUIRED') showConsentModal(data.error.details?.missing || ['privacy', 'terms']);
      throw err;
    }
    return data;
  }

  async function refresh() {
    try {
      const r = await fetch('/api/auth/refresh', { method: 'POST', credentials: 'same-origin' });
      if (!r.ok) return false;
      const data = await r.json();
      state.token = data.accessToken; state.user = data.user;
      return true;
    } catch { return false; }
  }

  function logoutLocal() {
    state.token = null; state.user = null;
    location.hash = '#/connexion';
  }

  async function loadMeta() {
    if (state.meta) return state.meta;
    const [countries, currencies, categories, tiers, fees] = await Promise.all([
      api('GET', '/meta/countries'), api('GET', '/meta/currencies'), api('GET', '/meta/card-categories'), api('GET', '/meta/tiers'), api('GET', '/meta/fees'),
    ]);
    for (const c of currencies.currencies) { DEC[c.code] = c.decimals; SYM[c.code] = c.symbol; }
    state.meta = { countries: countries.countries, currencies: currencies.currencies, cardCurrencies: currencies.cardCurrencies,
      categories: categories.categories, tiers: tiers.tiers, fees };
    return state.meta;
  }

  async function loadMe() {
    const me = await api('GET', '/auth/me');
    state.user = me.user; state.limits = me.limits;
    if (me.missingConsents?.length) showConsentModal(me.missingConsents);
  }

  // ================================================================ UI : toasts, modales
  function toast(msg, type = '') {
    const el = document.createElement('div');
    el.className = `toast ${type}`;
    el.textContent = msg;
    $('#toast-root').appendChild(el);
    setTimeout(() => el.remove(), 4200);
  }

  function modal(content, { onMount, locked = false } = {}) {
    const root = $('#modal-root');
    root.innerHTML = html`<div class="modal-backdrop"><div class="modal" role="dialog" aria-modal="true">${content}</div></div>`.s;
    const close = () => { root.innerHTML = ''; document.removeEventListener('keydown', onKey); };
    const onKey = (e) => { if (e.key === 'Escape') close(); };
    if (!locked) {
      document.addEventListener('keydown', onKey);
      $('.modal-backdrop', root).addEventListener('click', (e) => { if (e.target.classList.contains('modal-backdrop')) close(); });
    }
    $$('[data-close]', root).forEach((b) => b.addEventListener('click', close));
    if (onMount) onMount($('.modal', root), close);
    return close;
  }

  const LEGAL_LINKS = html`<a href="/legal/confidentialite.html" target="_blank" rel="noopener">Politique de confidentialité</a>
    <a href="/legal/cgu.html" target="_blank" rel="noopener">Conditions d’utilisation</a>`;

  let consentOpen = false;
  /** Modale bloquante : acceptation obligatoire des nouvelles versions des documents juridiques. */
  function showConsentModal(missing) {
    if (consentOpen) return;
    consentOpen = true;
    const names = { privacy: 'la politique de confidentialité', terms: 'les conditions générales d’utilisation' };
    modal(html`
      <h2>Mise à jour de nos conditions</h2>
      <p>Pour continuer à utiliser AfriCard, merci de lire et d’accepter ${missing.map((m) => names[m]).join(' et ')} en vigueur.</p>
      <form id="consent-form" class="stack">
        ${missing.includes('privacy') ? html`<label class="check"><input type="checkbox" required> J’ai lu et j’accepte la <a href="/legal/confidentialite.html" target="_blank" rel="noopener">politique de confidentialité</a>.</label>` : ''}
        ${missing.includes('terms') ? html`<label class="check"><input type="checkbox" required> J’ai lu et j’accepte les <a href="/legal/cgu.html" target="_blank" rel="noopener">conditions d’utilisation</a>.</label>` : ''}
        <div class="row"><a class="btn secondary" href="#/deconnexion" data-close>Se déconnecter</a><button class="btn accent" type="submit">J’accepte</button></div>
      </form>`, { locked: true, onMount: (m, close) => {
      $('[data-close]', m).addEventListener('click', () => { consentOpen = false; });
      $('#consent-form', m).addEventListener('submit', async (e) => {
        e.preventDefault();
        await withBusy($('button[type=submit]', e.target), async () => {
          await api('POST', '/consents', { documents: missing });
          consentOpen = false; close();
          toast('Merci, vos choix sont enregistrés', 'success');
          route();
        });
      });
    } });
  }

  /** Demande le code PIN de transaction (modale). */
  function askPin(title = 'Confirmez avec votre code PIN') {
    if (!state.user.pinSet) {
      toast('Définissez d’abord votre code PIN dans Sécurité', 'error');
      location.hash = '#/securite';
      return Promise.resolve(null);
    }
    return new Promise((resolve) => {
      let done = false;
      const close = modal(html`
        <h2>${title}</h2>
        <form id="pin-form">
          <div class="field"><input class="pin-input" id="pin" type="password" inputmode="numeric" autocomplete="one-time-code" maxlength="6" pattern="\\d{4,6}" required aria-label="Code PIN"></div>
          <div class="row"><button type="button" class="btn secondary" data-close>Annuler</button><button class="btn" type="submit">Valider</button></div>
        </form>`, { onMount: (m) => {
        $('#pin', m).focus();
        $('#pin-form', m).addEventListener('submit', (e) => { e.preventDefault(); done = true; const v = $('#pin', m).value; close(); resolve(v); });
      } });
      const obs = new MutationObserver(() => { if (!$('#modal-root').children.length) { obs.disconnect(); if (!done) resolve(null); } });
      obs.observe($('#modal-root'), { childList: true });
    });
  }

  async function withBusy(btn, fn) {
    const label = btn.innerHTML;
    btn.disabled = true; btn.innerHTML = '<span class="spinner"></span>';
    try { return await fn(); } catch (e) { toast(e.message, 'error'); return undefined; } finally { btn.disabled = false; btn.innerHTML = label; }
  }

  const formData = (form) => Object.fromEntries(new FormData(form).entries());

  // ================================================================ Mise en page
  const NAV = [
    ['accueil', '🏠', 'Accueil'], ['recharger', '📲', 'Recharger'], ['cartes', '💳', 'Mes cartes'], ['convertir', '💱', 'Convertir'],
    ['envoyer', '💸', 'Envoyer'], ['retirer', '🏧', 'Retirer'], ['historique', '🧾', 'Historique'], ['securite', '🔐', 'Sécurité & profil'],
    ['simulateur', '🛒', 'Simulateur marchand'], ['support', '💬', 'Support & réclamations'],
  ];
  const MOBILE_NAV = [['accueil', '🏠', 'Accueil'], ['recharger', '📲', 'Recharger'], ['cartes', '💳', 'Cartes'], ['historique', '🧾', 'Historique'], ['securite', '👤', 'Profil']];

  function layout(route, content) {
    const u = state.user;
    const nav = [...NAV, ...(u.role === 'admin' ? [['admin', '🛡️', 'Administration']] : [])];
    const sandbox = state.meta.fees.modes.mobileMoney !== 'live';
    return html`
      <div class="shell">
        <aside class="sidebar">
          <div class="brand"><span class="brand-mark">A</span> AfriCard</div>
          <nav class="nav">${nav.map(([r, i, l]) => html`<a href="#/${r}" class="${route === r ? 'active' : ''}"><span class="ico">${i}</span>${l}</a>`)}</nav>
          <div class="spacer"></div>
          ${sandbox ? html`<div class="sandbox-pill">Mode test (sandbox) : aucun argent réel n’est débité.</div>` : ''}
          <a href="#/deconnexion" class="logout">↪ Se déconnecter</a>
          <div class="legal-links">${LEGAL_LINKS}</div>
        </aside>
        <main class="main">
          <div class="topbar">
            <div class="who"><div class="avatar">${(u.fullName || '?').slice(0, 1).toUpperCase()}</div>
              <div><div><strong>${u.fullName}</strong></div><div class="small muted">Niveau ${u.kycLevel} · ${state.limits?.name || ''}</div></div></div>
            <a class="btn ghost bell" href="#/notifications" aria-label="Notifications">🔔${state.unread ? html`<span class="dot">${state.unread}</span>` : ''}</a>
          </div>
          ${content}
        </main>
        <nav class="bottom-nav">${MOBILE_NAV.map(([r, i, l]) => html`<a href="#/${r}" class="${route === r ? 'active' : ''}"><span class="ico">${i}</span>${l}</a>`)}</nav>
      </div>`;
  }

  function render(route, content, after) {
    $('#app').innerHTML = layout(route, content).s;
    window.scrollTo(0, 0);
    if (after) after($('#app'));
  }

  const txIcon = { deposit: '📥', withdrawal: '🏧', fx: '💱', card_load: '💳', card_unload: '↩️', card_purchase: '🛒', p2p: '💸', fee: '🏷️' };
  const txLabel = { deposit: 'Dépôt', withdrawal: 'Retrait', fx: 'Conversion', card_load: 'Recharge carte', card_unload: 'Retour carte', card_purchase: 'Achat carte', p2p: 'Transfert' };
  const statusBadge = (s) => {
    const map = { completed: ['success', 'Réussi'], approved: ['success', 'Accepté'], pending: ['warning', 'En attente'], failed: ['danger', 'Échoué'],
      declined: ['danger', 'Refusé'], reversed: ['', 'Remboursé'], active: ['success', 'Active'], frozen: ['warning', 'Gelée'], terminated: ['', 'Résiliée'] };
    const [cls, label] = map[s] || ['', s];
    return html`<span class="badge ${cls}">${label}</span>`;
  };
  const isCredit = (t) => t.type === 'deposit' || t.type === 'card_unload' || (t.type === 'p2p' && t.metadata?.direction === 'in');

  function txList(txs) {
    if (!txs.length) return html`<div class="empty">Aucune opération pour l’instant.</div>`;
    return html`<ul class="list">${txs.map((t) => html`
      <li><span class="ico-circle">${txIcon[t.type] || '•'}</span>
        <div class="grow"><div class="title">${t.description || txLabel[t.type]}</div>
          <div class="small muted">${txLabel[t.type] || t.type} · ${dateFmt(t.createdAt)} ${statusBadge(t.status)}</div></div>
        <div class="amt num ${isCredit(t) ? 'pos' : ''}">${isCredit(t) ? '+' : '−'}${fmt(t.amount, t.currency)}</div></li>`)}</ul>`;
  }

  // ================================================================ Visuel de carte
  function cardVisual(c, revealed) {
    const pan = revealed ? revealed.pan : c.maskedPan;
    const net = c.brand === 'mastercard' ? html`<span class="mc-logo"><span></span><span></span></span>` : html`<span class="net">VISA</span>`;
    return html`
      <div class="vcard ${c.brand} ${c.status}">
        <div class="top"><div><div class="label">${c.label}</div><div class="meta">${c.currency} · ${c.singleUse ? 'Usage unique' : 'Virtuelle'}</div></div>${net}</div>
        <div class="chip-ico"></div>
        <div class="pan">${pan}</div>
        <div class="bottom">
          <div><div class="meta">Titulaire</div><div class="val">${revealed ? revealed.holder : state.user.fullName.toUpperCase()}</div></div>
          <div><div class="meta">Exp.</div><div class="val">${String(c.expMonth).padStart(2, '0')}/${String(c.expYear).slice(-2)}</div></div>
          <div><div class="meta">CVV</div><div class="val">${revealed ? revealed.cvv : '•••'}</div></div>
        </div>
      </div>`;
  }

  // ================================================================ Pages
  const pages = {};

  // ---------------- Authentification
  pages.connexion = async () => {
    const meta = await loadMeta();
    const countryOpts = meta.countries.map((c) => html`<option value="${c.code}" ${c.code === 'CI' ? 'selected' : ''}>${c.name} (+${c.dial})</option>`);
    $('#app').innerHTML = html`
      <div class="auth-wrap">
        <section class="auth-side">
          <div class="brand"><span class="brand-mark">A</span> AfriCard</div>
          <h1>Votre carte <span class="hl">Visa & Mastercard</span> virtuelle, rechargée par Mobile Money.</h1>
          <p>Payez Netflix, Amazon, AliExpress, Meta Ads, Coursera, vos frais de visa et de concours… depuis ${meta.countries.length} pays africains.</p>
          <ul>
            <li>📲 Dépôt Orange Money, MTN MoMo, Wave, Moov, M-Pesa, Airtel Money…</li>
            <li>💱 Conversion en dollars, euros, yuans, livres… avec frais affichés à l’avance</li>
            <li>💳 Cartes à usage unique ou verrouillées sur un marchand pour vos abonnements</li>
            <li>🔐 Code PIN, double authentification, données de carte chiffrées</li>
          </ul>
          <div class="legal-links">${LEGAL_LINKS}</div>
          <div class="ops-logos">${['Orange Money', 'MTN MoMo', 'Wave', 'Moov Money', 'M-Pesa', 'Airtel Money', 'Free Money', 'T-Money', 'telebirr', 'OPay'].map((o) => html`<span>${o}</span>`)}</div>
        </section>
        <section class="auth-form">
          <div class="card">
            <div class="tabs" role="tablist"><button class="active" data-tab="login">Connexion</button><button data-tab="register">Créer un compte</button></div>
            <form id="login-form">
              <div class="field"><label for="l-login">E-mail ou numéro de téléphone</label><input id="l-login" name="login" autocomplete="username" required></div>
              <div class="field"><label for="l-country">Pays (si connexion par téléphone)</label><select id="l-country" name="country">${countryOpts}</select></div>
              <div class="field"><label for="l-pass">Mot de passe</label><input id="l-pass" name="password" type="password" autocomplete="current-password" required></div>
              <div class="field hidden" id="totp-field"><label for="l-totp">Code de double authentification</label><input id="l-totp" name="totp" inputmode="numeric" maxlength="6" autocomplete="one-time-code"></div>
              <button class="btn block" type="submit">Se connecter</button>
              <p class="small section-title"><button type="button" class="link-btn" id="forgot">Mot de passe oublié ?</button></p>
            </form>
            <form id="register-form" class="hidden">
              <div class="field"><label for="r-name">Nom complet (comme sur votre pièce d’identité)</label><input id="r-name" name="fullName" required minlength="3" autocomplete="name"></div>
              <div class="field"><label for="r-email">E-mail</label><input id="r-email" name="email" type="email" required autocomplete="email"></div>
              <div class="field"><label for="r-country">Pays de résidence</label><select id="r-country" name="country">${countryOpts}</select></div>
              <div class="field"><label for="r-phone">Téléphone (Mobile Money)</label><div class="input-group"><span class="prefix" id="r-dial">+225</span><input id="r-phone" name="phone" inputmode="tel" required autocomplete="tel-national"></div></div>
              <div class="field"><label for="r-pass">Mot de passe</label><input id="r-pass" name="password" type="password" required minlength="10" autocomplete="new-password">
                <div class="hint">10 caractères minimum, avec majuscule, minuscule et chiffre.</div></div>
              <label class="check"><input type="checkbox" name="acceptPrivacy" required> <span>J’ai lu et j’accepte la <a href="/legal/confidentialite.html" target="_blank" rel="noopener">politique de confidentialité</a> (obligatoire).</span></label>
              <label class="check"><input type="checkbox" name="acceptTerms" required> <span>J’accepte les <a href="/legal/cgu.html" target="_blank" rel="noopener">conditions générales d’utilisation</a> et certifie avoir au moins 18 ans (obligatoire).</span></label>
              <label class="check"><input type="checkbox" name="marketingOptIn"> <span>Je souhaite recevoir les offres et nouveautés AfriCard (facultatif).</span></label>
              <button class="btn block accent" type="submit">Créer mon compte gratuitement</button>
            </form>
          </div>
        </section>
      </div>`.s;

    $$('.tabs button').forEach((b) => b.addEventListener('click', () => {
      $$('.tabs button').forEach((x) => x.classList.toggle('active', x === b));
      $('#login-form').classList.toggle('hidden', b.dataset.tab !== 'login');
      $('#register-form').classList.toggle('hidden', b.dataset.tab !== 'register');
    }));
    $('#r-country').addEventListener('change', (e) => { $('#r-dial').textContent = `+${meta.countries.find((c) => c.code === e.target.value).dial}`; });

    $('#login-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const body = formData(e.target);
      if (!body.totp) delete body.totp;
      await withBusy($('button[type=submit]', e.target), async () => {
        try {
          const r = await api('POST', '/auth/login', body);
          state.token = r.accessToken; state.user = r.user;
          location.hash = '#/accueil';
        } catch (err) {
          if (err.code === 'TOTP_REQUIRED') { $('#totp-field').classList.remove('hidden'); $('#l-totp').focus(); }
          throw err;
        }
      });
    });
    $('#forgot').addEventListener('click', () => forgotPassword(meta));
    $('#register-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      await withBusy($('button[type=submit]', e.target), async () => {
        const f = formData(e.target);
        const r = await api('POST', '/auth/register', { ...f, acceptPrivacy: f.acceptPrivacy === 'on', acceptTerms: f.acceptTerms === 'on', marketingOptIn: f.marketingOptIn === 'on' });
        state.token = r.accessToken; state.user = r.user;
        toast('Bienvenue ! Commencez par définir votre code PIN.', 'success');
        location.hash = '#/securite';
      });
    });
  };

  function forgotPassword(meta) {
    const countryOpts = meta.countries.map((c) => html`<option value="${c.code}" ${c.code === 'CI' ? 'selected' : ''}>${c.name}</option>`);
    modal(html`
      <h2>Mot de passe oublié</h2>
      <form id="fp1" class="stack">
        <p class="small muted">Recevez un code à 6 chiffres par SMS et e-mail.</p>
        <div class="field"><label for="fp-login">E-mail ou téléphone</label><input id="fp-login" name="login" required></div>
        <div class="field"><label for="fp-country">Pays (si téléphone)</label><select id="fp-country" name="country">${countryOpts}</select></div>
        <div class="row"><button type="button" class="btn secondary" data-close>Annuler</button><button class="btn" type="submit">Recevoir le code</button></div>
      </form>
      <form id="fp2" class="stack hidden">
        <div class="alert small" id="fp-info"></div>
        <div class="field"><label for="fp-code">Code reçu</label><input id="fp-code" name="code" inputmode="numeric" maxlength="6" required autocomplete="one-time-code"></div>
        <div class="field"><label for="fp-new">Nouveau mot de passe</label><input id="fp-new" name="newPassword" type="password" minlength="10" required autocomplete="new-password">
          <div class="hint">10 caractères minimum, majuscule, minuscule et chiffre.</div></div>
        <div class="field hidden" id="fp-totp-f"><label for="fp-totp">Code de double authentification</label><input id="fp-totp" name="totp" inputmode="numeric" maxlength="6"></div>
        <button class="btn accent" type="submit">Changer mon mot de passe</button>
      </form>`, { onMount: (m, close) => {
      let ident;
      $('#fp1', m).addEventListener('submit', async (e) => {
        e.preventDefault();
        ident = formData(e.target);
        const r = await withBusy($('button[type=submit]', e.target), () => api('POST', '/auth/password/forgot', ident));
        if (!r) return;
        $('#fp1', m).classList.add('hidden'); $('#fp2', m).classList.remove('hidden');
        $('#fp-info', m).textContent = r.message + (r.devCode ? ` (Mode test : code ${r.devCode})` : '');
      });
      $('#fp2', m).addEventListener('submit', async (e) => {
        e.preventDefault();
        const f = formData(e.target); if (!f.totp) delete f.totp;
        try {
          await api('POST', '/auth/password/reset', { ...ident, ...f });
          close(); toast('Mot de passe changé : connectez-vous', 'success');
        } catch (err) {
          if (err.code === 'TOTP_REQUIRED') $('#fp-totp-f', m).classList.remove('hidden');
          toast(err.message, 'error');
        }
      });
    } });
  }

  // ---------------- Accueil
  pages.accueil = async () => {
    const [w, tx, cards] = await Promise.all([api('GET', '/wallets'), api('GET', '/transactions?limit=8'), api('GET', '/cards')]);
    const u = state.user;
    const activeCards = cards.cards.filter((c) => c.status !== 'terminated');
    const steps = [
      [u.pinSet, 'Définir votre code PIN de transaction', '#/securite'],
      [u.kycLevel >= 1, 'Vérifier votre identité (KYC)', '#/securite'],
      [w.wallets.some((x) => Number(x.balance) > 0), 'Recharger via Mobile Money', '#/recharger'],
      [cards.cards.length > 0, 'Créer votre première carte virtuelle', '#/cartes'],
    ];
    const onboarding = steps.every((s) => s[0]) ? '' : html`
      <div class="card"><h2>Bien démarrer</h2><ol class="steps">${steps.map(([done, label, href]) => html`
        <li class="${done ? 'done' : ''}"><span class="grow">${label}</span>${done ? '' : html`<a class="btn sm secondary" href="${href}">Faire</a>`}</li>`)}</ol></div>`;

    render('accueil', html`
      <section class="hero">
        <div class="label">Avoir total (portefeuilles + cartes)</div>
        <div class="amount num">${fmt(w.total, w.preferredCurrency)}</div>
        <div class="sub">Portefeuilles ${fmt(w.totalWallets, w.preferredCurrency)} · Cartes ${fmt(w.totalCards, w.preferredCurrency)}</div>
        <div class="actions">
          <a class="action" href="#/recharger"><span class="ico">📲</span>Recharger</a>
          <a class="action" href="#/convertir"><span class="ico">💱</span>Convertir</a>
          <a class="action" href="#/cartes/nouvelle"><span class="ico">💳</span>Nouvelle carte</a>
          <a class="action" href="#/envoyer"><span class="ico">💸</span>Envoyer</a>
          <a class="action" href="#/retirer"><span class="ico">🏧</span>Retirer</a>
        </div>
      </section>
      ${onboarding ? html`<div class="section-title"></div>${onboarding}` : ''}
      <div class="section-title"><h2>Mes portefeuilles</h2><a class="small" href="#/convertir">Convertir →</a></div>
      ${w.wallets.length ? html`<div class="wallet-list">${w.wallets.map((x) => html`
        <div class="wallet"><div class="ccy">${x.currency}</div><div class="bal num">${fmt(x.balance, x.currency)}</div>
          ${x.currency !== w.preferredCurrency ? html`<div class="small muted num">≈ ${fmt(x.equivalent, w.preferredCurrency)}</div>` : ''}</div>`)}</div>`
        : html`<div class="card empty">Aucun solde. <a href="#/recharger">Faites votre premier dépôt Mobile Money</a>.</div>`}
      <div class="grid grid-2">
        <div>
          <div class="section-title"><h2>Mes cartes</h2><a class="small" href="#/cartes">Tout voir →</a></div>
          ${activeCards.length ? html`<a class="card-tile" href="#/cartes/${activeCards[0].id}">${cardVisual(activeCards[0])}</a>
            <p class="small muted">Solde : <strong class="num">${fmt(activeCards[0].balance, activeCards[0].currency)}</strong>${activeCards.length > 1 ? ` · +${activeCards.length - 1} autre(s)` : ''}</p>`
            : html`<div class="card empty">Pas encore de carte. <a href="#/cartes/nouvelle">Créer une carte</a></div>`}
        </div>
        <div>
          <div class="section-title"><h2>Dernières opérations</h2><a class="small" href="#/historique">Historique →</a></div>
          <div class="card">${txList(tx.transactions)}</div>
        </div>
      </div>`);
  };

  // ---------------- Recharger (dépôt Mobile Money)
  function mmForm(kind) {
    const meta = state.meta;
    const country = meta.countries.find((c) => c.code === state.user.country) || meta.countries[0];
    return html`
      <form id="mm-form" class="card">
        <div class="field"><label for="mm-country">Pays</label><select id="mm-country" name="country">${meta.countries.map((c) => html`<option value="${c.code}" ${c.code === country.code ? 'selected' : ''}>${c.name} — ${c.currency}</option>`)}</select></div>
        <div class="field"><label>Opérateur</label><div class="chips" id="mm-ops"></div><input type="hidden" name="operator" id="mm-operator"></div>
        <div class="field"><label for="mm-phone">Numéro ${kind === 'deposit' ? 'à débiter' : 'qui reçoit l’argent'}</label>
          <div class="input-group"><span class="prefix" id="mm-dial"></span><input id="mm-phone" name="phone" inputmode="tel" required value="${state.user.phone.replace(/^\+\d{1,3}/, '')}"></div></div>
        <div class="field"><label for="mm-amount">Montant</label><div class="input-group"><input id="mm-amount" name="amount" inputmode="decimal" required placeholder="10000"><span class="prefix" id="mm-ccy"></span></div>
          <div class="hint" id="mm-range"></div></div>
        <dl class="kv hidden" id="mm-preview"></dl>
        <div class="section-title"></div>
        <button class="btn block accent" type="submit">${kind === 'deposit' ? 'Recharger mon portefeuille' : 'Retirer vers Mobile Money'}</button>
      </form>`;
  }

  function bindMmForm(root, kind, onSubmit) {
    const meta = state.meta;
    const sel = $('#mm-country', root);
    const update = () => {
      const c = meta.countries.find((x) => x.code === sel.value);
      $('#mm-dial', root).textContent = `+${c.dial}`;
      $('#mm-ccy', root).textContent = c.currency;
      $('#mm-range', root).textContent = `Entre ${fmt(c.min, c.currency)} et ${fmt(c.max, c.currency)} par opération.`;
      $('#mm-ops', root).innerHTML = c.operators.map((o, i) => html`<button type="button" class="chip ${i === 0 ? 'active' : ''}" data-op="${o.code}">${o.name}</button>`.s).join('');
      $('#mm-operator', root).value = c.operators[0].code;
      $$('#mm-ops .chip', root).forEach((b) => b.addEventListener('click', () => {
        $$('#mm-ops .chip', root).forEach((x) => x.classList.toggle('active', x === b));
        $('#mm-operator', root).value = b.dataset.op;
      }));
      preview();
    };
    let timer;
    const preview = () => {
      clearTimeout(timer);
      timer = setTimeout(async () => {
        const body = formData($('#mm-form', root));
        const box = $('#mm-preview', root);
        if (!body.amount || !body.phone) { box.classList.add('hidden'); return; }
        try {
          const p = await api('POST', `/${kind === 'deposit' ? 'deposits' : 'withdrawals'}/preview`, body);
          box.innerHTML = (kind === 'deposit'
            ? html`<dt>Montant débité</dt><dd class="num">${fmt(p.amount, p.currency)}</dd><dt>Frais (${meta.fees.depositBps / 100} %)</dt><dd class="num">${fmt(p.fee, p.currency)}</dd>
                   <dt class="total">Crédité sur AfriCard</dt><dd class="total num">${fmt(p.net, p.currency)}</dd><dt>Équivalent</dt><dd class="num">≈ ${fmt(p.usdEquivalent, 'USD')}</dd>`
            : html`<dt>Débité du portefeuille</dt><dd class="num">${fmt(p.amount, p.currency)}</dd><dt>Frais (${meta.fees.withdrawalBps / 100} %)</dt><dd class="num">${fmt(p.fee, p.currency)}</dd>
                   <dt class="total">Vous recevez</dt><dd class="total num">${fmt(p.received, p.currency)}</dd><dt>Disponible</dt><dd class="num">${fmt(p.available, p.currency)}</dd>`).s;
          box.classList.remove('hidden');
        } catch (err) { box.innerHTML = html`<dt class="muted">${err.message}</dt><dd></dd>`.s; box.classList.remove('hidden'); }
      }, 350);
    };
    sel.addEventListener('change', update);
    $('#mm-amount', root).addEventListener('input', preview);
    $('#mm-phone', root).addEventListener('input', preview);
    $('#mm-form', root).addEventListener('submit', (e) => { e.preventDefault(); onSubmit(formData(e.target), $('button[type=submit]', e.target)); });
    update();
  }

  pages.recharger = async () => {
    render('recharger', html`
      <h1>Recharger via Mobile Money</h1>
      <p class="muted">Le montant est crédité dans la devise de votre pays. Vous pourrez ensuite le convertir ou l’envoyer directement sur une carte.</p>
      <div class="grid grid-2"><div id="mm-wrap">${mmForm('deposit')}</div><div id="mm-status"></div></div>`, (root) => {
      bindMmForm(root, 'deposit', async (body, btn) => {
        const r = await withBusy(btn, () => api('POST', '/deposits', body, { idempotent: uuid() }));
        if (r) showDepositStatus(r);
      });
    });
  };

  function showDepositStatus(r) {
    const box = $('#mm-status');
    const sandbox = r.provider === 'sandbox';
    box.innerHTML = html`<div class="card stack">
      <h2>Paiement en attente <span class="spinner"></span></h2>
      <div class="alert warning">${r.instructions || 'Validez la demande de paiement sur votre téléphone.'}</div>
      <dl class="kv"><dt>Montant</dt><dd class="num">${fmt(r.amount, r.currency)}</dd><dt>Frais</dt><dd class="num">${fmt(r.fee, r.currency)}</dd><dt class="total">À créditer</dt><dd class="total num">${fmt(r.net, r.currency)}</dd></dl>
      ${r.redirectUrl ? html`<a class="btn block" href="${r.redirectUrl}" rel="noopener">Ouvrir la page de paiement</a>` : ''}
      ${sandbox ? html`<div class="alert small">Mode test : simulez la réponse du client sur son téléphone.</div>
        <div class="row"><button class="btn accent" id="sbx-ok">✅ Simuler la validation</button><button class="btn secondary" id="sbx-ko">Simuler un refus</button></div>` : ''}
    </div>`.s;
    let stopped = false;
    const poll = async () => {
      if (stopped || !document.body.contains(box)) return;
      try {
        const op = await api('GET', `/mobile-money/${r.id}`);
        if (op.status !== 'pending') return finish(op);
      } catch { /* réessaie */ }
      setTimeout(poll, 3000);
    };
    const finish = async (op) => {
      stopped = true;
      await loadMe();
      box.innerHTML = (op.status === 'completed'
        ? html`<div class="card stack"><h2>✅ Dépôt réussi</h2><p>${fmt(op.net, op.currency)} ont été crédités sur votre portefeuille.</p>
            <div class="row"><a class="btn accent" href="#/convertir">Convertir en USD/EUR</a><a class="btn secondary" href="#/cartes">Recharger une carte</a></div></div>`
        : html`<div class="card stack"><h2>❌ Dépôt échoué</h2><p>${op.failureReason || 'Le paiement n’a pas abouti.'}</p></div>`).s;
    };
    if (sandbox) {
      const confirm = (success) => async (e) => {
        const btn = e.currentTarget;
        const op = await withBusy(btn, () => api('POST', `/sandbox/mobile-money/${r.id}/confirm`, { success }));
        if (op) finish(op);
      };
      $('#sbx-ok').addEventListener('click', confirm(true));
      $('#sbx-ko').addEventListener('click', confirm(false));
    }
    setTimeout(poll, 3000);
  }

  // ---------------- Retirer
  pages.retirer = async () => {
    render('retirer', html`
      <h1>Retirer vers Mobile Money</h1>
      <p class="muted">Rapatriez votre argent vers votre compte Orange Money, Wave, MTN MoMo, M-Pesa…</p>
      ${state.user.kycLevel < 1 ? html`<div class="alert warning">Les retraits nécessitent une identité vérifiée. <a href="#/securite">Vérifier mon identité</a></div><div class="section-title"></div>` : ''}
      <div class="grid grid-2"><div>${mmForm('withdrawal')}</div><div id="wd-result"></div></div>`, (root) => {
      bindMmForm(root, 'withdrawal', async (body, btn) => {
        const pin = await askPin('Confirmer le retrait');
        if (!pin) return;
        const r = await withBusy(btn, () => api('POST', '/withdrawals', { ...body, pin }, { idempotent: uuid() }));
        if (r) {
          $('#wd-result').innerHTML = html`<div class="card stack"><h2>${r.status === 'completed' ? '✅ Retrait effectué' : '⏳ Retrait en cours'}</h2>
            <p>${fmt(r.net, r.currency)} ${r.status === 'completed' ? 'ont été envoyés' : 'vont être envoyés'} au ${r.phone}.</p></div>`.s;
          toast('Retrait enregistré', 'success');
        }
      });
    });
  };

  // ---------------- Convertir
  pages.convertir = async () => {
    const [w, rates] = await Promise.all([api('GET', '/wallets'), api('GET', '/meta/rates')]);
    const ccys = state.meta.currencies;
    const local = (state.meta.countries.find((c) => c.code === state.user.country) || {}).currency || 'XOF';
    const opt = (sel) => ccys.map((c) => html`<option value="${c.code}" ${c.code === sel ? 'selected' : ''}>${c.code} — ${c.name}</option>`);
    const popular = ['USD', 'EUR', 'CNY', 'GBP', 'AED', 'CAD'];
    render('convertir', html`
      <h1>Convertir mes devises</h1>
      <p class="muted">Taux garanti pendant 60 secondes. Frais de change : ${state.meta.fees.fxSpreadBps / 100} %, inclus et affichés avant validation.</p>
      <div class="grid grid-2">
        <form id="fx-form" class="card">
          <div class="field"><label for="fx-from">Je convertis depuis</label><select id="fx-from" name="from">${opt(local)}</select>
            <div class="hint" id="fx-avail"></div></div>
          <div class="field"><label for="fx-to">Vers</label><select id="fx-to" name="to">${opt('USD')}</select>
            <div class="chips">${popular.map((c) => html`<button type="button" class="chip sm" data-to="${c}">${c}</button>`)}</div></div>
          <div class="field"><label>Je saisis le montant</label><div class="chips"><button type="button" class="chip active" data-mode="sell">à convertir</button><button type="button" class="chip" data-mode="buy">à recevoir</button></div>
            <input type="hidden" name="mode" id="fx-mode" value="sell"></div>
          <div class="field"><label for="fx-amount" id="fx-amount-label">Montant à convertir</label><input id="fx-amount" name="amount" inputmode="decimal" required></div>
          <button class="btn block" type="submit">Obtenir le taux</button>
        </form>
        <div>
          <div id="fx-quote"></div>
          <div class="card"><h2>Cours indicatifs</h2><p class="small muted">Source : ${rates.source === 'live' ? 'marché' : 'référence'} · ${dateFmt(rates.updatedAt)}</p>
            <table><thead><tr><th>Devise</th><th>1 ${local} =</th><th>1 unité = </th></tr></thead><tbody>
            ${popular.map((c) => html`<tr><td><strong>${c}</strong></td><td class="num">${(rates.rates[c] / rates.rates[local]).toPrecision(4)}</td><td class="num">${fmt((rates.rates[local] / rates.rates[c]).toFixed(DEC[local] ?? 2), local)}</td></tr>`)}
            </tbody></table></div>
        </div>
      </div>`, (root) => {
      const avail = () => {
        const f = $('#fx-from', root).value;
        const wal = w.wallets.find((x) => x.currency === f);
        $('#fx-avail', root).textContent = `Disponible : ${fmt(wal ? wal.balance : 0, f)}`;
      };
      $('#fx-from', root).addEventListener('change', avail); avail();
      $$('[data-to]', root).forEach((b) => b.addEventListener('click', () => { $('#fx-to', root).value = b.dataset.to; }));
      $$('[data-mode]', root).forEach((b) => b.addEventListener('click', () => {
        $$('[data-mode]', root).forEach((x) => x.classList.toggle('active', x === b));
        $('#fx-mode', root).value = b.dataset.mode;
        $('#fx-amount-label', root).textContent = b.dataset.mode === 'sell' ? 'Montant à convertir' : 'Montant à recevoir';
      }));
      $('#fx-form', root).addEventListener('submit', async (e) => {
        e.preventDefault();
        const q = await withBusy($('button[type=submit]', e.target), () => api('POST', '/fx/quote', formData(e.target)));
        if (q) showQuote(q);
      });
    });
  };

  function showQuote(q) {
    const box = $('#fx-quote');
    const insufficient = Number(q.fromAmount) > Number(q.available);
    box.innerHTML = html`<div class="card stack">
      <h2>Votre cotation</h2>
      <dl class="kv">
        <dt>Vous donnez</dt><dd class="num">${fmt(q.fromAmount, q.from)}</dd>
        <dt>Dont frais de change</dt><dd class="num">${fmt(q.fee, q.from)}</dd>
        <dt>Taux appliqué</dt><dd class="num">1 ${q.from} = ${q.rate} ${q.to}</dd>
        <dt class="total">Vous recevez</dt><dd class="total num">${fmt(q.toAmount, q.to)}</dd>
      </dl>
      ${insufficient ? html`<div class="alert danger">Solde insuffisant (${fmt(q.available, q.from)} disponible). <a href="#/recharger">Recharger</a></div>` : ''}
      <button class="btn block accent" id="fx-go" ${insufficient ? 'disabled' : ''}>Confirmer · <span class="countdown" id="fx-cd"></span></button>
    </div><div class="section-title"></div>`.s;
    const end = new Date(q.expiresAt).getTime();
    const iv = setInterval(() => {
      const el = $('#fx-cd');
      if (!el) return clearInterval(iv);
      const s = Math.max(0, Math.round((end - Date.now()) / 1000));
      el.textContent = `${s}s`;
      if (!s) { clearInterval(iv); $('#fx-go').disabled = true; el.textContent = 'expirée'; }
    }, 500);
    $('#fx-go').addEventListener('click', async (e) => {
        const btn = e.currentTarget;
      const r = await withBusy(btn, () => api('POST', '/fx/execute', { quoteId: q.id }, { idempotent: q.id }));
      if (r) { clearInterval(iv); toast(`Conversion effectuée : +${fmt(q.toAmount, q.to)}`, 'success'); route(); }
    });
  }

  // ---------------- Cartes
  pages.cartes = async (id) => {
    if (id === 'nouvelle') return pageNewCard();
    if (id) return pageCard(id);
    const { cards } = await api('GET', '/cards');
    render('cartes', html`
      <div class="row between"><h1>Mes cartes virtuelles</h1><div class="row"><a class="btn secondary" href="#/simulateur">🛒 Tester un paiement</a><a class="btn accent" href="#/cartes/nouvelle">+ Nouvelle carte</a></div></div>
      <p class="muted">Utilisables partout où Visa/Mastercard est accepté en ligne : abonnements, e-commerce, publicité, formations, voyages.</p>
      ${cards.length ? html`<div class="grid grid-3">${cards.map((c) => html`
        <a class="card-tile" href="#/cartes/${c.id}">${cardVisual(c)}
          <div class="row between small"><span>Solde <strong class="num">${fmt(c.balance, c.currency)}</strong></span>${statusBadge(c.status)}</div></a>`)}</div>`
        : html`<div class="card empty"><p>Vous n’avez pas encore de carte.</p><a class="btn accent" href="#/cartes/nouvelle">Créer ma première carte</a></div>`}`);
  };

  async function pageNewCard() {
    const w = await api('GET', '/wallets');
    const meta = state.meta;
    const tier = state.limits;
    const feeUsd = (meta.fees.cardCreationUsdCents / 100).toFixed(2);
    const fundOpts = w.wallets.filter((x) => Number(x.balance) > 0);
    render('cartes', html`
      <h1>Créer une carte virtuelle</h1>
      ${state.user.kycLevel < 1 ? html`<div class="alert warning">La création de carte nécessite une identité vérifiée. <a href="#/securite">Vérifier mon identité</a></div><div class="section-title"></div>` : ''}
      <div class="grid grid-2">
        <form id="nc-form" class="card">
          <div class="field"><label for="nc-label">Nom de la carte</label><input id="nc-label" name="label" maxlength="40" value="Abonnements" required>
            <div class="hint">Ex. « Netflix », « Pub Facebook », « Achats Chine »…</div></div>
          <div class="field"><label>Réseau</label><div class="chips"><button type="button" class="chip active" data-brand="visa">Visa</button><button type="button" class="chip" data-brand="mastercard">Mastercard</button></div>
            <input type="hidden" name="brand" id="nc-brand" value="visa"></div>
          <div class="field"><label for="nc-ccy">Devise de la carte</label><select id="nc-ccy" name="currency">${meta.cardCurrencies.map((c) => html`<option value="${c}">${c}</option>`)}</select>
            <div class="hint">Choisissez la devise de vos achats pour éviter les frais de conversion.</div></div>
          <div class="field"><label for="nc-amount">Montant initial (facultatif)</label><input id="nc-amount" name="initialAmount" inputmode="decimal" placeholder="20"></div>
          <div class="field"><label for="nc-fund">Payer depuis</label><select id="nc-fund" name="fundingCurrency">
            ${fundOpts.length ? fundOpts.map((x) => html`<option value="${x.currency}">Portefeuille ${x.currency} (${fmt(x.balance, x.currency)})</option>`) : html`<option value="">Aucun solde — rechargez d’abord</option>`}</select>
            <div class="hint">Conversion automatique si la devise diffère.</div></div>
          <fieldset class="field"><legend class="small muted">Options de sécurité</legend>
            <label class="check"><input type="checkbox" name="singleUse"> Carte à usage unique (essais gratuits, sites peu connus)</label>
            <label class="check"><input type="checkbox" name="lockToFirstMerchant"> Verrouiller sur le premier marchand (idéal pour un abonnement)</label>
          </fieldset>
          <div class="field"><label for="nc-ptl">Plafond par achat (facultatif)</label><input id="nc-ptl" name="perTxLimit" inputmode="decimal"></div>
          <div class="field"><label for="nc-ml">Plafond mensuel (facultatif)</label><input id="nc-ml" name="monthlyLimit" inputmode="decimal"></div>
          <button class="btn block accent" type="submit">Créer la carte</button>
        </form>
        <div class="stack">
          <div id="nc-preview"></div>
          <div class="card"><h2>Tarifs transparents</h2><dl class="kv">
            <dt>Création de carte</dt><dd>${feeUsd} USD (une fois)</dd>
            <dt>Frais mensuels</dt><dd>0</dd>
            <dt>Achat dans la devise de la carte</dt><dd>0 %</dd>
            <dt>Achat dans une autre devise</dt><dd>${meta.fees.cardCrossCurrencyBps / 100} %</dd>
            <dt>Conversion depuis le portefeuille</dt><dd>${meta.fees.fxSpreadBps / 100} %</dd>
            <dt>Cartes autorisées (votre niveau)</dt><dd>${tier.maxCards}</dd></dl></div>
        </div>
      </div>`, (root) => {
      const pv = () => {
        const f = formData($('#nc-form', root));
        $('#nc-preview', root).innerHTML = cardVisual({ label: f.label || 'Ma carte', brand: f.brand, currency: f.currency, status: 'active',
          maskedPan: '•••• •••• •••• ••••', expMonth: new Date().getMonth() + 1, expYear: new Date().getFullYear() + 3, singleUse: Boolean(f.singleUse) }).s;
      };
      $$('[data-brand]', root).forEach((b) => b.addEventListener('click', () => {
        $$('[data-brand]', root).forEach((x) => x.classList.toggle('active', x === b)); $('#nc-brand', root).value = b.dataset.brand; pv();
      }));
      $('#nc-form', root).addEventListener('input', pv); pv();
      $('#nc-form', root).addEventListener('submit', async (e) => {
        e.preventDefault();
        const f = formData(e.target);
        const body = { label: f.label, brand: f.brand, currency: f.currency, singleUse: Boolean(f.singleUse), lockToFirstMerchant: Boolean(f.lockToFirstMerchant) };
        for (const k of ['initialAmount', 'perTxLimit', 'monthlyLimit']) if (f[k]) body[k] = f[k];
        if (f.fundingCurrency) body.fundingCurrency = f.fundingCurrency;
        const pin = await askPin('Confirmer la création de la carte');
        if (!pin) return;
        const r = await withBusy($('button[type=submit]', e.target), () => api('POST', '/cards', { ...body, pin }, { idempotent: uuid() }));
        if (r) { toast('Carte créée 🎉', 'success'); location.hash = `#/cartes/${r.card.id}`; }
      });
    });
  }

  async function pageCard(id) {
    const [{ card: c }, { authorizations }, w] = await Promise.all([api('GET', `/cards/${id}`), api('GET', `/cards/${id}/authorizations`), api('GET', '/wallets')]);
    const cats = state.meta.categories;
    const terminated = c.status === 'terminated';
    render('cartes', html`
      <a href="#/cartes" class="small">← Mes cartes</a>
      <div class="grid grid-2">
        <div class="stack">
          <div id="card-visual">${cardVisual(c)}</div>
          <div class="row between"><div><div class="small muted">Solde disponible</div><div class="num"><strong>${fmt(c.balance, c.currency)}</strong></div></div>${statusBadge(c.status)}</div>
          ${terminated ? '' : html`<div class="row">
            <button class="btn" id="btn-reveal">👁️ Afficher les détails</button>
            ${c.status === 'frozen' ? html`<button class="btn secondary" id="btn-unfreeze">🔓 Dégeler</button>` : html`<button class="btn secondary" id="btn-freeze">❄️ Geler</button>`}
          </div>`}
          ${c.monthlyLimit ? html`<p class="small muted">Dépensé ce mois : ${fmt(c.monthlySpent, c.currency)} / ${fmt(c.monthlyLimit, c.currency)}</p>` : ''}
          ${c.merchantLock ? html`<div class="alert small">🔒 Verrouillée sur le marchand « ${c.merchantLock} ».</div>` : ''}
          ${c.singleUse ? html`<div class="alert small">${c.usedOnce ? 'Carte à usage unique déjà utilisée.' : 'Carte à usage unique : elle sera bloquée après le premier achat.'}</div>` : ''}
        </div>
        ${terminated ? html`<div class="card">Cette carte est résiliée. Son solde a été restitué sur votre portefeuille.</div>` : html`
        <div class="stack">
          <form class="card" id="load-form"><h2>Recharger la carte</h2>
            <div class="field"><label for="ld-amount">Montant (${c.currency})</label><input id="ld-amount" name="amount" inputmode="decimal" required></div>
            <div class="field"><label for="ld-src">Depuis</label><select id="ld-src" name="sourceCurrency">${(w.wallets.length ? w.wallets : [{ currency: c.currency, balance: '0' }]).map((x) => html`<option value="${x.currency}" ${x.currency === c.currency ? 'selected' : ''}>Portefeuille ${x.currency} (${fmt(x.balance, x.currency)})</option>`)}</select></div>
            <dl class="kv hidden" id="ld-preview"></dl><div class="section-title"></div>
            <div class="row"><button class="btn accent" type="submit">Recharger</button><button class="btn secondary" type="button" id="btn-unload">Renvoyer vers le portefeuille</button></div>
          </form>
          <form class="card" id="ctl-form"><h2>Contrôles de dépenses</h2>
            <div class="grid grid-2">
              <div class="field"><label for="ctl-ptl">Plafond par achat</label><input id="ctl-ptl" name="perTxLimit" inputmode="decimal" value="${c.perTxLimit || ''}" placeholder="Aucun"></div>
              <div class="field"><label for="ctl-ml">Plafond mensuel</label><input id="ctl-ml" name="monthlyLimit" inputmode="decimal" value="${c.monthlyLimit || ''}" placeholder="Aucun"></div>
            </div>
            <label>Catégories bloquées</label>
            ${Object.entries(cats).map(([k, v]) => html`<label class="check"><input type="checkbox" name="cat" value="${k}" ${c.blockedCategories.includes(k) ? 'checked' : ''}> ${v}</label>`)}
            <button class="btn" type="submit">Enregistrer</button>
          </form>
        </div>`}
      </div>
      <div class="section-title"><h2>Paiements de la carte</h2></div>
      <div class="card">${authorizations.length ? html`<ul class="list">${authorizations.map((a) => html`
        <li><span class="ico-circle">${a.status === 'approved' ? '✅' : a.status === 'reversed' ? '↩️' : '⛔'}</span>
          <div class="grow"><div class="title">${a.merchant}</div><div class="small muted">${cats[a.category] ? cats[a.category].split(' (')[0] : a.category} · ${a.country} · ${dateFmt(a.createdAt)}${a.declineReason ? ` · ${a.declineReason}` : ''}</div></div>
          <div class="amt num">${fmt(a.billedAmount !== '0' && a.billedAmount !== '0.00' ? a.billedAmount : a.amount, a.billedAmount !== '0' && a.billedAmount !== '0.00' ? a.billedCurrency : a.currency)}<div>${statusBadge(a.status)}</div></div></li>`)}</ul>`
        : html`<div class="empty">Aucun paiement. Utilisez la carte sur un site marchand ou testez avec le <a href="#/simulateur">simulateur</a>.</div>`}</div>
      ${terminated ? '' : html`<div class="section-title"></div><button class="btn danger" id="btn-terminate">Résilier la carte</button>`}`, (root) => {
      if (terminated) return;
      $('#btn-reveal', root).addEventListener('click', async (e) => {
        const btn = e.currentTarget;
        const pin = await askPin('Afficher les détails de la carte');
        if (!pin) return;
        const r = await withBusy(btn, () => api('POST', `/cards/${id}/reveal`, { pin }));
        if (!r) return;
        $('#card-visual', root).innerHTML = cardVisual(c, r).s;
        const copy = html`<div class="row small"><button class="btn sm secondary" data-copy="${r.pan.replace(/\s/g, '')}">Copier le numéro</button><button class="btn sm secondary" data-copy="${r.cvv}">Copier le CVV</button></div>`;
        $('#card-visual', root).insertAdjacentHTML('beforeend', copy.s);
        $$('[data-copy]', root).forEach((b) => b.addEventListener('click', () => navigator.clipboard?.writeText(b.dataset.copy).then(() => toast('Copié'))));
        setTimeout(() => { const v = $('#card-visual'); if (v) v.innerHTML = cardVisual(c).s; }, 60000); // masquage auto après 60 s
      });
      $('#btn-freeze', root)?.addEventListener('click', async (e) => {
        const btn = e.currentTarget;
        if (await withBusy(btn, () => api('POST', `/cards/${id}/freeze`))) { toast('Carte gelée : tous les paiements sont bloqués'); route(); }
      });
      $('#btn-unfreeze', root)?.addEventListener('click', async (e) => {
        const btn = e.currentTarget;
        const pin = await askPin('Dégeler la carte'); if (!pin) return;
        if (await withBusy(btn, () => api('POST', `/cards/${id}/unfreeze`, { pin }))) { toast('Carte réactivée', 'success'); route(); }
      });
      $('#btn-terminate', root).addEventListener('click', async (e) => {
        const btn = e.currentTarget;
        const pin = await askPin('Résilier définitivement la carte ?'); if (!pin) return;
        if (await withBusy(btn, () => api('POST', `/cards/${id}/terminate`, { pin }))) { toast('Carte résiliée, solde restitué'); route(); }
      });
      let t;
      const preview = () => { clearTimeout(t); t = setTimeout(async () => {
        const f = formData($('#load-form', root)); const box = $('#ld-preview', root);
        if (!f.amount) return box.classList.add('hidden');
        try {
          const p = await api('POST', `/cards/${id}/load/preview`, f);
          box.innerHTML = html`<dt>Crédité sur la carte</dt><dd class="num">${fmt(p.amount, p.cardCurrency)}</dd>
            ${p.debitedCurrency !== p.cardCurrency ? html`<dt>Taux</dt><dd class="num">1 ${p.debitedCurrency} = ${p.rate} ${p.cardCurrency}</dd><dt>Dont frais de change</dt><dd class="num">${fmt(p.fxFee, p.debitedCurrency)}</dd>` : ''}
            <dt class="total">Débité du portefeuille</dt><dd class="total num">${fmt(p.debited, p.debitedCurrency)}</dd>`.s;
          box.classList.remove('hidden');
        } catch (err) { box.innerHTML = html`<dt>${err.message}</dt><dd></dd>`.s; box.classList.remove('hidden'); }
      }, 350); };
      $('#load-form', root).addEventListener('input', preview);
      $('#load-form', root).addEventListener('submit', async (e) => {
        e.preventDefault();
        if (await withBusy($('button[type=submit]', e.target), () => api('POST', `/cards/${id}/load`, formData(e.target), { idempotent: uuid() }))) { toast('Carte rechargée', 'success'); route(); }
      });
      $('#btn-unload', root).addEventListener('click', async (e) => {
        const btn = e.currentTarget;
        const amount = $('#ld-amount', root).value || c.balance;
        if (await withBusy(btn, () => api('POST', `/cards/${id}/unload`, { amount }, { idempotent: uuid() }))) { toast('Fonds renvoyés vers le portefeuille', 'success'); route(); }
      });
      $('#ctl-form', root).addEventListener('submit', async (e) => {
        e.preventDefault();
        const fd = new FormData(e.target);
        const body = { perTxLimit: fd.get('perTxLimit') || null, monthlyLimit: fd.get('monthlyLimit') || null, blockedCategories: fd.getAll('cat') };
        if (await withBusy($('button[type=submit]', e.target), () => api('PATCH', `/cards/${id}/controls`, body))) toast('Contrôles enregistrés', 'success');
      });
    });
  }

  // ---------------- Envoyer (P2P)
  pages.envoyer = async () => {
    const w = await api('GET', '/wallets');
    render('envoyer', html`
      <h1>Envoyer de l’argent</h1>
      <p class="muted">Transfert instantané et gratuit vers un autre membre AfriCard, par numéro de téléphone ou e-mail. Idéal pour la famille, les tontines et les cotisations.</p>
      <form id="p2p-form" class="card">
        <div class="field"><label for="p-rec">Destinataire (téléphone ou e-mail)</label><input id="p-rec" name="recipient" required placeholder="+225 07 00 00 00 00 ou nom@exemple.com"></div>
        <div class="field"><label for="p-country">Pays du numéro</label><select id="p-country" name="recipientCountry">${state.meta.countries.map((c) => html`<option value="${c.code}" ${c.code === state.user.country ? 'selected' : ''}>${c.name} (+${c.dial})</option>`)}</select></div>
        <div class="grid grid-2">
          <div class="field"><label for="p-ccy">Devise</label><select id="p-ccy" name="currency">${(w.wallets.length ? w.wallets : [{ currency: 'XOF', balance: '0' }]).map((x) => html`<option value="${x.currency}">${x.currency} (${fmt(x.balance, x.currency)})</option>`)}</select></div>
          <div class="field"><label for="p-amount">Montant</label><input id="p-amount" name="amount" inputmode="decimal" required></div>
        </div>
        <div class="field"><label for="p-note">Motif (facultatif)</label><input id="p-note" name="note" maxlength="140" placeholder="Tontine de mars"></div>
        <button class="btn block accent" type="submit">Envoyer</button>
      </form>`, (root) => {
      $('#p2p-form', root).addEventListener('submit', async (e) => {
        e.preventDefault();
        const body = formData(e.target);
        if (!body.note) delete body.note;
        const pin = await askPin(`Envoyer ${body.amount} ${body.currency} ?`); if (!pin) return;
        const r = await withBusy($('button[type=submit]', e.target), () => api('POST', '/transfers', { ...body, pin }, { idempotent: uuid() }));
        if (r) { toast(`Envoyé à ${r.recipient} ✅`, 'success'); location.hash = '#/accueil'; }
      });
    });
  };

  // ---------------- Historique
  pages.historique = async () => {
    const type = new URLSearchParams(location.hash.split('?')[1] || '').get('type') || '';
    const { transactions } = await api('GET', `/transactions?limit=200${type ? `&type=${encodeURIComponent(type)}` : ''}`);
    const types = [['', 'Tout'], ['deposit', 'Dépôts'], ['withdrawal', 'Retraits'], ['fx', 'Conversions'], ['card_load', 'Recharges carte'], ['card_purchase', 'Achats'], ['p2p', 'Transferts']];
    render('historique', html`
      <div class="row between"><h1>Historique</h1><button class="btn secondary" id="export">⬇️ Exporter le relevé (CSV)</button></div>
      <div class="chips">${types.map(([k, l]) => html`<a class="chip ${k === type ? 'active' : ''}" href="#/historique${k ? `?type=${k}` : ''}">${l}</a>`)}</div>
      <div class="section-title"></div>
      <div class="card">${txList(transactions)}</div>`, (root) => {
      $('#export', root).addEventListener('click', async () => {
        const res = await fetch('/api/transactions/export.csv', { headers: { Authorization: `Bearer ${state.token}` } });
        if (!res.ok) return toast('Export impossible', 'error');
        const url = URL.createObjectURL(await res.blob());
        const a = document.createElement('a'); a.href = url; a.download = 'releve-africard.csv'; a.click();
        setTimeout(() => URL.revokeObjectURL(url), 1000);
      });
    });
  };

  // ---------------- Notifications
  pages.notifications = async () => {
    const { notifications } = await api('GET', '/notifications');
    await api('POST', '/notifications/read');
    state.unread = 0;
    render('notifications', html`<h1>Notifications</h1><div class="card">${notifications.length ? html`<ul class="list">${notifications.map((n) => html`
      <li><span class="ico-circle">🔔</span><div class="grow"><div class="title">${n.title}</div><div class="small">${n.body}</div><div class="small muted">${dateFmt(n.created_at)}</div></div></li>`)}</ul>`
      : html`<div class="empty">Aucune notification.</div>`}</div>`);
  };

  // ---------------- Sécurité, profil, KYC
  pages.securite = async () => {
    await loadMe();
    const u = state.user;
    const [{ submissions }, { activity }] = await Promise.all([api('GET', '/kyc'), api('GET', '/security/activity')]);
    const pending = submissions.find((s) => s.status === 'pending');
    const tiers = state.meta.tiers;
    const nextLevel = u.kycLevel + 1;
    render('securite', html`
      <h1>Sécurité & profil</h1>
      <div class="grid grid-2">
        <div class="stack">
          <form class="card" id="pin-set"><h2>${u.pinSet ? 'Modifier mon code PIN' : '1. Définir mon code PIN'}</h2>
            <p class="small muted">Demandé pour chaque retrait, transfert, création de carte et affichage des numéros de carte.</p>
            ${u.pinSet ? html`<div class="field"><label for="ps-cur">PIN actuel</label><input id="ps-cur" name="currentPin" type="password" inputmode="numeric" maxlength="6" required></div>` : ''}
            <div class="field"><label for="ps-pin">Nouveau PIN (4 à 6 chiffres)</label><input id="ps-pin" name="pin" type="password" inputmode="numeric" maxlength="6" pattern="\\d{4,6}" required></div>
            <div class="field"><label for="ps-pass">Mot de passe</label><input id="ps-pass" name="password" type="password" autocomplete="current-password" required></div>
            <button class="btn" type="submit">Enregistrer le PIN</button></form>

          <div class="card"><h2>${u.kycLevel >= 1 ? 'Vérification d’identité' : '2. Vérifier mon identité'}</h2>
            <p>Niveau actuel : <strong>${u.kycLevel} — ${tiers[u.kycLevel].name}</strong></p>
            <dl class="kv small"><dt>Plafond par opération</dt><dd>${fmt(tiers[u.kycLevel].perTx / 100, 'USD')}</dd><dt>Plafond mensuel</dt><dd>${fmt(tiers[u.kycLevel].monthly / 100, 'USD')}</dd>
              <dt>Utilisé ce mois</dt><dd>${fmt(state.limits.monthlyUsedUsdCents / 100, 'USD')}</dd><dt>Cartes</dt><dd>${tiers[u.kycLevel].maxCards}</dd></dl>
            ${pending ? html`<div class="alert warning">Vérification en cours d’examen (niveau ${pending.target_level}).</div>` : tiers[nextLevel] ? html`
              <form id="kyc-form" class="stack"><h3>Passer au niveau ${nextLevel} : ${tiers[nextLevel].name}</h3>
                <p class="small muted">${tiers[nextLevel].description} Plafond mensuel ${fmt(tiers[nextLevel].monthly / 100, 'USD')}.</p>
                <input type="hidden" name="targetLevel" value="${nextLevel}">
                <div class="field"><label for="k-type">Pièce d’identité</label><select id="k-type" name="idType">
                  <option value="cni">Carte nationale d’identité</option><option value="passport">Passeport</option><option value="driver_license">Permis de conduire</option>
                  <option value="residence_permit">Titre de séjour</option><option value="voter_card">Carte d’électeur</option><option value="nin">NIN (Nigeria)</option></select></div>
                <div class="field"><label for="k-num">Numéro de la pièce</label><input id="k-num" name="idNumber" required></div>
                <div class="field"><label for="k-dob">Date de naissance</label><input id="k-dob" name="dateOfBirth" type="date" required></div>
                <div class="field"><label for="k-addr">Adresse de résidence</label><input id="k-addr" name="address" required></div>
                <button class="btn accent" type="submit">Soumettre</button></form>` : html`<div class="alert success">Niveau maximal atteint ✅</div>`}
          </div>
        </div>
        <div class="stack">
          <div class="card" id="privacy"><h2>Confidentialité & notifications</h2>
            <div class="switch-row"><span>Alertes de sécurité par SMS et e-mail<div class="small muted">Toujours actives pour protéger votre compte</div></span><input type="checkbox" checked disabled aria-label="Alertes de sécurité"></div>
            <div class="switch-row"><label for="pv-email">Notifications de transactions par e-mail</label><input type="checkbox" id="pv-email" data-pref="notifyEmail" ${u.notifyEmail ? 'checked' : ''}></div>
            <div class="switch-row"><label for="pv-sms">Dépôts et retraits par SMS</label><input type="checkbox" id="pv-sms" data-pref="notifySms" ${u.notifySms ? 'checked' : ''}></div>
            <div class="switch-row"><label for="pv-mkt">Offres et nouveautés (facultatif)</label><input type="checkbox" id="pv-mkt" data-pref="marketingOptIn" ${u.marketingOptIn ? 'checked' : ''}></div>
            <div class="row section-title">
              <button class="btn sm secondary" id="pv-export">⬇️ Télécharger mes données</button>
              <a class="btn sm ghost" href="/legal/confidentialite.html" target="_blank" rel="noopener">Politique de confidentialité</a>
            </div>
            <details><summary class="small muted">Clôturer mon compte</summary>
              <form id="close-form" class="stack">
                <p class="small">Vos soldes doivent être à zéro. Vos données d’identification seront anonymisées ; les justificatifs financiers sont conservés le temps exigé par la loi (LBC/FT).</p>
                <div class="field"><label for="cl-pass">Mot de passe</label><input id="cl-pass" name="password" type="password" required></div>
                <div class="field"><label for="cl-reason">Motif (facultatif)</label><input id="cl-reason" name="reason" maxlength="300"></div>
                <button class="btn danger sm" type="submit">Clôturer définitivement</button>
              </form>
            </details>
          </div>
          <div class="card" id="twofa"><h2>Double authentification (2FA)</h2>
            ${u.totpEnabled ? html`<p>✅ Activée. Un code de votre application (Google Authenticator, Authy…) est demandé à chaque connexion.</p>
              <form id="tfa-off" class="stack"><div class="field"><label for="tf-code">Code actuel</label><input id="tf-code" name="code" inputmode="numeric" maxlength="6" required></div>
              <div class="field"><label for="tf-pass">Mot de passe</label><input id="tf-pass" name="password" type="password" required></div><button class="btn danger" type="submit">Désactiver</button></form>`
              : html`<p class="small muted">Protégez votre compte même si votre mot de passe est volé ou votre carte SIM clonée.</p><button class="btn" id="tfa-setup">Activer la 2FA</button><div id="tfa-step"></div>`}
          </div>
          <form class="card" id="pref"><h2>Devise d’affichage</h2>
            <div class="field"><select name="preferredCurrency">${state.meta.currencies.map((c) => html`<option value="${c.code}" ${c.code === u.preferredCurrency ? 'selected' : ''}>${c.code} — ${c.name}</option>`)}</select></div>
            <button class="btn secondary" type="submit">Enregistrer</button></form>
          <form class="card" id="pwd"><h2>Mot de passe</h2>
            <div class="field"><label for="pw-cur">Mot de passe actuel</label><input id="pw-cur" name="currentPassword" type="password" required autocomplete="current-password"></div>
            <div class="field"><label for="pw-new">Nouveau mot de passe</label><input id="pw-new" name="newPassword" type="password" required minlength="10" autocomplete="new-password"></div>
            <button class="btn secondary" type="submit">Changer</button></form>
          <div class="card"><h2>Activité récente</h2><ul class="list small">${activity.slice(0, 10).map((a) => html`<li><span class="grow">${a.action}</span><span class="muted">${a.ip || ''} · ${dateFmt(a.created_at)}</span></li>`)}</ul>
            <button class="btn ghost sm" id="logout-all">Déconnecter tous les appareils</button></div>
          <div class="card small"><strong>Compte :</strong> ${u.email} · ${u.phone}<div class="row section-title"><a class="btn sm secondary" href="#/envoyer">💸 Envoyer</a><a class="btn sm secondary" href="#/support">💬 Support</a><a class="btn sm secondary" href="#/convertir">💱 Convertir</a>${u.role === 'admin' ? html`<a class="btn sm secondary" href="#/admin">🛡️ Administration</a>` : ''}<a class="btn sm ghost" href="#/deconnexion">Se déconnecter</a></div></div>
        </div>
      </div>`, (root) => {
      const bind = (sel, fn) => $(sel, root)?.addEventListener('submit', async (e) => { e.preventDefault(); await withBusy($('button[type=submit]', e.target), () => fn(formData(e.target), e.target)); });
      bind('#pin-set', async (f) => { await api('POST', '/security/pin', f); toast('Code PIN enregistré', 'success'); route(); });
      bind('#kyc-form', async (f) => { const r = await api('POST', '/kyc', { ...f, targetLevel: Number(f.targetLevel) }); toast(r.status === 'approved' ? 'Identité vérifiée ✅' : 'Dossier envoyé', 'success'); route(); });
      bind('#pref', async (f) => { await api('PATCH', '/profile', f); toast('Préférence enregistrée', 'success'); });
      bind('#pwd', async (f, form) => { await api('POST', '/security/password', f); toast('Mot de passe modifié', 'success'); form.reset(); });
      bind('#tfa-off', async (f) => { await api('POST', '/security/2fa/disable', f); toast('2FA désactivée'); route(); });
      $('#tfa-setup', root)?.addEventListener('click', async (e) => {
        const btn = e.currentTarget;
        const r = await withBusy(btn, () => api('POST', '/security/2fa/setup'));
        if (!r) return;
        $('#tfa-step', root).innerHTML = html`<div class="stack"><div class="section-title"></div>
          <p class="small">Dans votre application d’authentification, ajoutez un compte avec cette clé :</p>
          <p class="mono alert">${r.secret.match(/.{1,4}/g).join(' ')}</p>
          <p class="small muted">Ou ouvrez ce lien sur votre téléphone : <a class="mono" href="${r.otpauthUrl}">otpauth://…</a></p>
          <form id="tfa-on" class="input-group"><input name="code" inputmode="numeric" maxlength="6" placeholder="Code à 6 chiffres" required><button class="btn" type="submit">Activer</button></form></div>`.s;
        bind('#tfa-on', async (f) => { await api('POST', '/security/2fa/enable', f); toast('2FA activée 🔐', 'success'); route(); });
      });
      $$('[data-pref]', root).forEach((cb) => cb.addEventListener('change', async () => {
        try { const r = await api('PATCH', '/privacy/preferences', { [cb.dataset.pref]: cb.checked }); state.user = r.user; toast('Préférence enregistrée', 'success'); } catch (err) { cb.checked = !cb.checked; toast(err.message, 'error'); }
      }));
      $('#pv-export', root).addEventListener('click', async () => {
        const res = await fetch('/api/privacy/export', { headers: { Authorization: `Bearer ${state.token}` } });
        if (!res.ok) return toast('Export impossible', 'error');
        const url = URL.createObjectURL(await res.blob());
        const a = document.createElement('a'); a.href = url; a.download = 'mes-donnees-africard.json'; a.click();
        setTimeout(() => URL.revokeObjectURL(url), 1000);
        return toast('Vos données ont été téléchargées', 'success');
      });
      $('#close-form', root).addEventListener('submit', async (e) => {
        e.preventDefault();
        const f = formData(e.target); if (!f.reason) delete f.reason;
        const pin = await askPin('Confirmer la clôture du compte'); if (!pin) return;
        const r = await withBusy($('button[type=submit]', e.target), () => api('POST', '/privacy/close-account', { ...f, pin }));
        if (r) { toast(r.message, 'success'); state.token = null; state.user = null; location.hash = '#/connexion'; }
      });
      $('#logout-all', root).addEventListener('click', async () => { await api('POST', '/auth/logout-all'); logoutLocal(); });
    });
  };

  // ---------------- Support & réclamations
  const TICKET_CATS = { reclamation: 'Réclamation', fraude: 'Fraude / opération non reconnue', carte: 'Carte', mobile_money: 'Dépôt / retrait Mobile Money',
    compte: 'Mon compte', donnees_personnelles: 'Données personnelles', autre: 'Autre' };
  pages.support = async () => {
    const { tickets } = await api('GET', '/support/tickets');
    render('support', html`
      <h1>Support & réclamations</h1>
      <p class="muted">Accusé de réception sous 48 h ouvrées, réponse sous 30 jours maximum. En cas de fraude, <strong>gelez d’abord votre carte</strong> depuis « Mes cartes ».</p>
      <div class="grid grid-2">
        <form class="card" id="tk-form">
          <div class="field"><label for="tk-cat">Sujet</label><select id="tk-cat" name="category">${Object.entries(TICKET_CATS).map(([k, v]) => html`<option value="${k}">${v}</option>`)}</select></div>
          <div class="field"><label for="tk-sub">Titre</label><input id="tk-sub" name="subject" required minlength="3" maxlength="120"></div>
          <div class="field"><label for="tk-msg">Message</label><textarea id="tk-msg" name="message" rows="6" required minlength="10" maxlength="3000" placeholder="Décrivez votre demande (date, montant, référence…). Ne communiquez jamais votre PIN ni votre mot de passe."></textarea></div>
          <button class="btn accent" type="submit">Envoyer</button>
        </form>
        <div class="card"><h2>Mes demandes</h2>${tickets.length ? html`<ul class="list">${tickets.map((t) => html`
          <li><div class="grow"><div class="title">${t.subject}</div><div class="small muted">${TICKET_CATS[t.category] || t.category} · réf. ${t.id.slice(0, 8).toUpperCase()} · ${dateFmt(t.created_at)}</div>
            ${t.reply ? html`<div class="alert small">💬 ${t.reply}</div>` : ''}</div>${statusBadge(t.status === 'open' ? 'pending' : t.status === 'answered' ? 'completed' : 'terminated')}</li>`)}</ul>`
          : html`<div class="empty">Aucune demande.</div>`}</div>
      </div>`, (root) => {
      $('#tk-form', root).addEventListener('submit', async (e) => {
        e.preventDefault();
        const r = await withBusy($('button[type=submit]', e.target), () => api('POST', '/support/tickets', formData(e.target)));
        if (r) { toast(`Demande enregistrée (réf. ${r.reference})`, 'success'); route(); }
      });
    });
  };

  // ---------------- Simulateur marchand (sandbox)
  const MERCHANTS = [
    ['Netflix', 'streaming', 'US', 'USD', '15.49'], ['Spotify', 'streaming', 'SE', 'EUR', '10.99'], ['Amazon', 'ecommerce', 'US', 'USD', '42.30'],
    ['AliExpress', 'ecommerce', 'CN', 'CNY', '268'], ['Alibaba (fournisseur)', 'ecommerce', 'CN', 'CNY', '1500'], ['Meta Ads', 'ads', 'IE', 'USD', '25'],
    ['Google Ads', 'ads', 'IE', 'EUR', '30'], ['ChatGPT Plus', 'software', 'US', 'USD', '20'], ['Canva Pro', 'software', 'AU', 'USD', '14.99'],
    ['Coursera', 'education', 'US', 'USD', '49'], ['Frais de visa France', 'education', 'FR', 'EUR', '90'], ['Booking.com', 'travel', 'NL', 'EUR', '120'],
    ['PlayStation Store', 'gaming', 'GB', 'GBP', '19.99'], ['BetPlus', 'gambling', 'MT', 'EUR', '10'],
  ];
  pages.simulateur = async () => {
    const { cards } = await api('GET', '/cards');
    const active = cards.filter((c) => c.status !== 'terminated');
    render('simulateur', html`
      <h1>Simulateur de paiement marchand</h1>
      <p class="muted">Testez vos cartes comme si vous payiez sur un site : le réseau envoie une demande d’autorisation à AfriCard, qui applique vos contrôles, l’anti-fraude et la conversion de devise.</p>
      ${active.length ? '' : html`<div class="alert warning">Créez d’abord une carte. <a href="#/cartes/nouvelle">Créer une carte</a></div><div class="section-title"></div>`}
      <div class="grid grid-2">
        <form class="card" id="sim-form">
          <div class="field"><label for="s-card">Carte</label><select id="s-card" name="card">${active.map((c) => html`<option value="${c.id}">${c.label} •••• ${c.last4} (${fmt(c.balance, c.currency)})</option>`)}</select>
            <div class="hint">Le PIN vous sera demandé pour lire les données de la carte, comme lorsque vous les copiez sur un site.</div></div>
          <div class="field"><label>Marchand</label><div class="chips">${MERCHANTS.map((m, i) => html`<button type="button" class="chip ${i === 0 ? 'active' : ''}" data-m="${i}">${m[0]}</button>`)}</div></div>
          <div class="grid grid-2">
            <div class="field"><label for="s-amount">Montant</label><input id="s-amount" name="amount" value="15.49" required></div>
            <div class="field"><label for="s-ccy">Devise du marchand</label><select id="s-ccy" name="currency">${state.meta.currencies.map((c) => html`<option value="${c.code}" ${c.code === 'USD' ? 'selected' : ''}>${c.code}</option>`)}</select></div>
          </div>
          <input type="hidden" name="merchantName" id="s-name" value="Netflix"><input type="hidden" name="merchantCategory" id="s-cat" value="streaming"><input type="hidden" name="merchantCountry" id="s-country" value="US">
          <button class="btn block accent" type="submit" ${active.length ? '' : 'disabled'}>Payer</button>
        </form>
        <div id="sim-result"></div>
      </div>`, (root) => {
      $$('[data-m]', root).forEach((b) => b.addEventListener('click', () => {
        $$('[data-m]', root).forEach((x) => x.classList.toggle('active', x === b));
        const m = MERCHANTS[Number(b.dataset.m)];
        $('#s-name', root).value = m[0]; $('#s-cat', root).value = m[1]; $('#s-country', root).value = m[2]; $('#s-ccy', root).value = m[3]; $('#s-amount', root).value = m[4];
      }));
      let details = {};
      $('#sim-form', root).addEventListener('submit', async (e) => {
        e.preventDefault();
        const f = formData(e.target);
        if (!details[f.card]) {
          const pin = await askPin('Lire les données de la carte'); if (!pin) return;
          const d = await withBusy($('button[type=submit]', e.target), () => api('POST', `/cards/${f.card}/reveal`, { pin }));
          if (!d) return;
          details[f.card] = d;
        }
        const d = details[f.card];
        const r = await withBusy($('button[type=submit]', e.target), () => api('POST', '/sandbox/card-authorizations', {
          pan: d.pan.replace(/\s/g, ''), cvv: d.cvv, expMonth: d.expMonth, expYear: d.expYear, amount: f.amount, currency: f.currency,
          merchantName: f.merchantName, merchantCategory: f.merchantCategory, merchantCountry: f.merchantCountry }));
        if (!r) return;
        $('#sim-result', root).innerHTML = (r.approved
          ? html`<div class="card stack"><h2>✅ Paiement accepté</h2><p>${f.merchantName} : ${fmt(f.amount, f.currency)}</p>
              <dl class="kv"><dt>Débité sur la carte</dt><dd class="num">${fmt(r.billedAmount, r.billedCurrency)}</dd><dt>Dont frais de devise</dt><dd class="num">${fmt(r.fee, r.billedCurrency)}</dd></dl></div>`
          : html`<div class="card stack"><h2>⛔ Paiement refusé</h2><div class="alert danger">${r.reason}</div></div>`).s;
      });
    });
  };

  // ---------------- Administration
  pages.admin = async () => {
    if (state.user.role !== 'admin') { location.hash = '#/accueil'; return; }
    const [stats, kyc, integ, ag, al, tk] = await Promise.all([api('GET', '/admin/stats'), api('GET', '/admin/kyc'), api('GET', '/admin/ledger/integrity'),
      api('GET', '/admin/agents'), api('GET', '/admin/alerts'), api('GET', '/admin/tickets')]);
    const agentLabels = { security: '🛡️ Agent de sécurité', reliability: '🔧 Agent de fiabilité', notification: '📣 Agent de notifications' };
    const openTickets = tk.tickets.filter((t) => t.status === 'open');
    render('admin', html`
      <h1>Administration</h1>
      ${ag.financialLock ? html`<div class="banner-lock">🚨 Mode protégé actif : ${ag.financialLock}<div class="row section-title"><button class="btn sm secondary" id="unlock">Lever le mode protégé</button></div></div>` : ''}
      <div class="section-title"><h2>Agents automatiques</h2></div>
      <div class="grid grid-3">${ag.agents.map((a) => html`
        <div class="card"><div class="row between"><strong>${agentLabels[a.name] || a.name}</strong>${a.lastRun ? statusBadge(a.lastRun.status === 'ok' ? 'completed' : 'failed') : html`<span class="badge">jamais</span>`}</div>
          <p class="small muted">${a.lastRun ? `Dernier passage : ${dateFmt(a.lastRun.at)}` : 'En attente du premier passage'}${a.errors24h ? ` · ${a.errors24h} échec(s) 24 h` : ''}</p>
          ${a.lastRun && typeof a.lastRun.summary === 'object' ? html`<dl class="kv small">${Object.entries(a.lastRun.summary).map(([k, v]) => html`<dt>${k}</dt><dd>${String(v)}</dd>`)}</dl>` : ''}
          <div class="section-title"></div><button class="btn sm secondary" data-agent="${a.name}">Exécuter maintenant</button></div>`)}</div>
      <div class="section-title"><h2>Alertes ouvertes (${al.alerts.length})</h2></div>
      <div class="card">${al.alerts.length ? html`<ul class="list">${al.alerts.map((a) => html`
        <li class="sev-${a.severity}"><div class="grow"><div class="title">${a.type}</div><div class="small">${a.message}</div>
          <div class="small muted">${a.full_name ? `${a.full_name} · ` : ''}${dateFmt(a.created_at)}</div></div>
          <button class="btn sm secondary" data-alert="${a.id}">Traiter</button></li>`)}</ul>` : html`<div class="empty">Aucune alerte ouverte ✅</div>`}</div>
      <div class="section-title"><h2>Demandes clients en attente (${openTickets.length})</h2></div>
      <div class="card">${openTickets.length ? html`<ul class="list">${openTickets.map((t) => html`
        <li><div class="grow"><div class="title">[${t.category}] ${t.subject}</div><div class="small">${t.message}</div><div class="small muted">${t.full_name} · ${t.email} · ${dateFmt(t.created_at)}</div></div>
          <button class="btn sm" data-ticket="${t.id}">Répondre</button></li>`)}</ul>` : html`<div class="empty">Aucune demande en attente.</div>`}</div>
      <div class="section-title"><h2>Activité</h2></div>
      <div class="grid grid-3">
        <div class="card"><div class="muted small">Utilisateurs</div><h2>${stats.users.total}</h2><div class="small">${stats.users.verified} vérifiés</div></div>
        <div class="card"><div class="muted small">Cartes actives</div><h2>${stats.cards.active}</h2><div class="small">${stats.cards.total} émises</div></div>
        <div class="card"><div class="muted small">Revenus (≈ USD)</div><h2>${fmt(stats.revenue.usdEquivalent, 'USD')}</h2><div class="small">${integ.ok ? '✅ Grand livre équilibré' : '⚠️ Écart comptable détecté'}</div></div>
      </div>
      <div class="section-title"><h2>Dossiers KYC en attente (${kyc.submissions.length})</h2></div>
      <div class="card table-wrap">${kyc.submissions.length ? html`<table><thead><tr><th>Client</th><th>Pays</th><th>Niveau</th><th>Pièce</th><th>Naissance</th><th></th></tr></thead><tbody>
        ${kyc.submissions.map((k) => html`<tr><td>${k.fullName}<div class="small muted">${k.email}</div></td><td>${k.country}</td><td>${k.targetLevel}</td><td>${k.idType} · ${k.idNumber}</td><td>${k.dateOfBirth}</td>
          <td class="row"><button class="btn sm" data-kyc="${k.id}" data-d="approved">Valider</button><button class="btn sm danger" data-kyc="${k.id}" data-d="rejected">Refuser</button></td></tr>`)}</tbody></table>`
        : html`<div class="empty">Aucun dossier en attente.</div>`}</div>
      <div class="section-title"><h2>Volumes</h2></div>
      <div class="card table-wrap"><table><thead><tr><th>Type</th><th>Devise</th><th>Nombre</th><th>Volume</th></tr></thead><tbody>
        ${stats.volumes.map((v) => html`<tr><td>${txLabel[v.type] || v.type}</td><td>${v.currency}</td><td>${v.n}</td><td class="num">${fmt(v.total, v.currency)}</td></tr>`)}</tbody></table></div>
      <div class="section-title"><h2>Principaux motifs de refus carte</h2></div>
      <div class="card"><ul class="list">${stats.topDeclineReasons.map((d) => html`<li><span class="grow">${d.decline_reason}</span><strong>${d.n}</strong></li>`)}</ul></div>`, (root) => {
      $$('[data-agent]', root).forEach((b) => b.addEventListener('click', async () => {
        const r = await withBusy(b, () => api('POST', `/admin/agents/${b.dataset.agent}/run`));
        if (r) { toast('Agent exécuté', 'success'); route(); }
      }));
      $$('[data-alert]', root).forEach((b) => b.addEventListener('click', async () => {
        const note = prompt('Note de traitement (facultatif)') || undefined;
        if (await withBusy(b, () => api('POST', `/admin/alerts/${b.dataset.alert}/resolve`, { note }))) { toast('Alerte traitée', 'success'); route(); }
      }));
      $$('[data-ticket]', root).forEach((b) => b.addEventListener('click', async () => {
        const reply = prompt('Votre réponse au client'); if (!reply) return;
        if (await withBusy(b, () => api('POST', `/admin/tickets/${b.dataset.ticket}/reply`, { reply }))) { toast('Réponse envoyée', 'success'); route(); }
      }));
      $('#unlock', root)?.addEventListener('click', async (e) => {
        const btn = e.currentTarget;
        const reason = prompt('Motif de la levée (enquête effectuée, anomalie corrigée…)'); if (!reason) return;
        if (await withBusy(btn, () => api('POST', '/admin/financial-lock/clear', { reason }))) { toast('Mode protégé levé', 'success'); route(); }
      });
      $$('[data-kyc]', root).forEach((b) => b.addEventListener('click', async () => {
        const note = b.dataset.d === 'rejected' ? (prompt('Motif du refus ?') || 'Informations non conformes') : undefined;
        if (await withBusy(b, () => api('POST', `/admin/kyc/${b.dataset.kyc}/review`, { decision: b.dataset.d, note }))) { toast('Dossier traité', 'success'); route(); }
      }));
    });
  };

  // ================================================================ Routeur
  async function route() {
    const [path] = location.hash.replace(/^#\/?/, '').split('?');
    const [name, arg] = path.split('/');
    try {
      await loadMeta();
      if (name === 'deconnexion') {
        await api('POST', '/auth/logout').catch(() => {});
        return logoutLocal();
      }
      if (!state.token && !(await refresh())) {
        if (name !== 'connexion') { location.hash = '#/connexion'; return undefined; }
        return pages.connexion();
      }
      if (name === 'connexion' || !pages[name]) { location.hash = '#/accueil'; return undefined; }
      if (!state.limits || name === 'accueil') await loadMe();
      api('GET', '/notifications').then((n) => {
        state.unread = n.unread;
        const bell = $('.bell'); if (bell && n.unread && !$('.dot', bell)) bell.insertAdjacentHTML('beforeend', html`<span class="dot">${n.unread}</span>`.s);
      }).catch(() => {});
      return await pages[name](arg);
    } catch (e) {
      if (e.status === 401) return logoutLocal();
      if (e.code === 'CONSENT_REQUIRED') return undefined; // la modale d'acceptation est déjà affichée
      toast(e.message, 'error');
      return undefined;
    }
  }

  window.addEventListener('hashchange', route);
  route();
})();
