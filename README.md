# AfriCard — cartes bancaires virtuelles pour l'Afrique

AfriCard permet à n'importe qui en Afrique de **créer sa propre carte Visa/Mastercard virtuelle**
en dollars, euros ou livres, **rechargée par Mobile Money** (Orange Money, MTN MoMo, Wave, Moov,
M-Pesa, Airtel Money, Free Money, T-Money, telebirr, OPay…), pour payer en ligne là où les
cartes locales sont refusées : Netflix, Spotify, Amazon, AliExpress, Meta/Google Ads, ChatGPT,
Canva, Coursera, frais de visa et de concours, billets d'avion, fournisseurs chinois…

> **Statut :** plateforme complète et fonctionnelle en **mode sandbox** (simulation de bout en bout,
> aucun argent réel). Le passage en production nécessite des partenaires agréés et des licences :
> voir [docs/MISE-EN-PRODUCTION.md](docs/MISE-EN-PRODUCTION.md).

## Fonctionnalités

| Domaine | Ce que fait la plateforme |
|---|---|
| **Dépôts Mobile Money** | 24 pays, 59 opérateurs et moyens de paiement locaux, aperçu des frais avant paiement, demande « USSD push » puis confirmation par webhook signé |
| **Portefeuilles multi-devises** | XOF, XAF, NGN, GHS, KES, UGX, TZS, RWF, GNF, CDF, ZMW, ZAR, MAD, EGP, ETB + USD, EUR, CNY, GBP, AED, CAD, CHF, JPY, INR, TRY, SAR |
| **Change** | Cotation garantie 60 s, mode « je donne » ou « je reçois », marge affichée, franc CFA arrimé à l'euro (655,957) |
| **Cartes virtuelles** | Visa ou Mastercard, en USD/EUR/GBP, rechargement **direct depuis le solde en FCFA/Naira/Cedi…** avec conversion automatique |
| **Contrôles de carte** | Gel/dégel instantané, plafond par achat et mensuel, catégories bloquées (paris bloqués par défaut), pays autorisés |
| **Cartes spéciales** | **Usage unique** (essais gratuits, sites douteux) et **verrouillage sur le premier marchand** (un abonnement = une carte) |
| **Autorisations** | Vérification CVV/expiration, solde, plafonds, anti-fraude (rafales, tests de carte), conversion de devise marchande, remboursements |
| **Retraits** | Vers Mobile Money, fonds réservés puis **restitués automatiquement** si l'opérateur échoue |
| **Transferts P2P** | Gratuits et instantanés entre membres par téléphone ou e-mail (famille, tontines, cotisations) |
| **Historique** | Filtres, notifications, **relevé CSV** (utile pour visas, comptabilité, justificatifs) |
| **Administration** | Statistiques, revenus, file KYC, gel de comptes, contrôle d'intégrité du grand livre, journal d'audit |

### Agents automatiques (sécurité, bugs, notifications)

| Agent | Rôle |
|---|---|
| 🛡️ **Sécurité** | Bloque les IP qui attaquent par force brute, **gèle les cartes victimes de test CVV**, prévient le titulaire, détecte les schémas de blanchiment (gros montants, fractionnement, entrée-sortie rapide) |
| 🔧 **Fiabilité** | Contrôle le grand livre en continu : **auto-réparation** des soldes, **mode protégé** qui suspend les mouvements de fonds en cas d'anomalie, expiration des dépôts bloqués, détection des pics d'erreurs (bugs), purge des données expirées |
| 📣 **Notifications** | Envoie SMS, e-mails et alertes équipe (Slack/Discord/Telegram) avec relances ; prévient des soldes bas, cartes qui expirent, étapes non terminées |

Plus : alerte « nouvelle connexion », détection du vol de session, et une **CI GitHub** (tests, contrôles
statiques, `npm audit`, CodeQL, Dependabot) qui bloque les bugs avant la mise en ligne. Détails : [docs/AGENTS.md](docs/AGENTS.md).

### Conformité et protection des données

- **Politique de confidentialité** et **CGU** versionnées (`/legal/confidentialite.html`, `/legal/cgu.html`), à **acceptation obligatoire** à l'inscription ; la preuve (version, date, IP) est conservée.
- Nouvelle version publiée ⇒ **ré-acceptation exigée** avant toute opération.
- Droits des personnes dans l'application : **export de toutes ses données** (JSON), préférences de notifications, consentement marketing facultatif, **clôture du compte avec anonymisation** (justificatifs financiers conservés 10 ans, obligation LBC/FT).
- **Support et réclamations** intégrés (accusé de réception, suivi, réponses de l'équipe), alertes prioritaires pour les fraudes.
- **Mot de passe oublié** par code à usage unique (SMS + e-mail), sans révéler si un compte existe.
- Cookie unique strictement nécessaire, aucun traceur publicitaire.

### Sécurité

- **Grand livre en partie double** : chaque mouvement est équilibré, aucun solde client ne peut devenir négatif, contrôle d'intégrité intégré.
- Montants en **unités mineures entières** (aucun flottant), conversions en `BigInt`.
- Mots de passe et **PIN de transaction** hachés avec **scrypt** ; verrouillage après 5 erreurs.
- **PAN, CVV, numéros de pièce d'identité et secrets 2FA chiffrés en AES-256-GCM** (données liées par AAD).
- **Double authentification TOTP** (Google Authenticator, Authy…).
- Sessions : jeton d'accès court (15 min) + jeton de rafraîchissement **httpOnly / SameSite=Strict avec rotation et détection de vol** (réutilisation ⇒ révocation de toute la famille).
- **Idempotence** (`Idempotency-Key`) sur toutes les opérations financières : pas de double débit en cas de réseau instable.
- **Webhooks signés** (HMAC) + anti-rejeu.
- En-têtes de sécurité stricts (CSP sans script inline, HSTS, anti-clickjacking), limitation de débit, journal d'audit.
- Plafonds réglementaires par **niveau KYC** (0 : 100 $/op ; 1 : 3 000 $/mois ; 2 : 25 000 $/mois).

## Démarrage rapide

Prérequis : **Node.js ≥ 22.13** (utilise le module SQLite intégré, aucune base externe).

```bash
npm install
npm start            # http://localhost:3000
npm test             # 23 tests : unitaires, intégration, agents, conformité
npm run check        # contrôles statiques
```

Parcours de test (mode sandbox) :
1. Créez un compte, définissez votre **code PIN** puis vérifiez votre identité (validée automatiquement en sandbox).
2. **Recharger** → choisissez Orange Money / Wave… → « Simuler la validation ».
3. **Convertir** vos FCFA en dollars (ou chargez directement une carte depuis vos FCFA).
4. **Nouvelle carte** → **Afficher les détails** (PIN) → **Simulateur marchand** pour payer Netflix, AliExpress (en yuans), Meta Ads…
5. Numéros se terminant par `0000` = refus opérateur (pour tester les échecs).

Pour un compte administrateur : `npm run seed:admin -- votre@email.com`.

## Architecture

```
src/
  app.js, server.js          Express + sécurité (helmet, rate-limit, CSP)
  config.js                  Configuration par variables d'environnement
  db/                        Schéma SQLite (WAL), transactions atomiques
  lib/                       crypto (scrypt, AES-GCM, TOTP), money (BigInt), erreurs
  data/                      Pays, opérateurs, devises
  services/
    ledger.js                Grand livre en partie double
    fx.js                    Cotations et change
    mobileMoney.js           Dépôts/retraits, webhooks
    cards.js                 Émission, contrôles, autorisations, anti-fraude
    limits.js                Plafonds KYC
  providers/
    mobileMoney.js           Sandbox + CinetPay, Flutterwave, pawaPay
    cardIssuer.js            Sandbox (BIN de test) — à remplacer par votre BIN sponsor
  routes/                    API REST (auth, comptes, argent, cartes, admin, webhooks)
public/                      Application web (PWA, sans framework, légère pour la 3G)
test/                        Tests node:test
```

API complète : voir [docs/API.md](docs/API.md).

## Déploiement

```bash
cp .env.example .env    # renseignez les secrets
docker build -t africard .
docker run -d -p 3000:3000 --env-file .env -v africard-data:/app/data africard
```

Placez l'application derrière un reverse proxy HTTPS (Caddy, Nginx, Cloudflare).
