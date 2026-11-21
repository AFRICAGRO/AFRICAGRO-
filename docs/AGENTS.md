# Agents automatiques

AfriCard embarque trois agents qui tournent en continu dans le serveur (`src/agents/`).
Chaque passage est journalisé (`agent_runs`) et visible dans **Administration → Agents automatiques**,
où un administrateur peut aussi les lancer manuellement. Un agent qui plante déclenche lui-même une
alerte critique.

## 🛡️ Agent de sécurité — toutes les 60 s

| Détection | Réaction automatique |
|---|---|
| ≥ 10 échecs de connexion depuis une même IP en 15 min | IP bloquée 1 h + alerte équipe |
| ≥ 5 échecs sur un même compte en 15 min | Alerte de sécurité au titulaire (SMS + e-mail) |
| ≥ 3 paiements refusés pour CVV/date erronés en 30 min (test de carte volée) | **Carte gelée** + titulaire prévenu + alerte |
| ≥ 20 tentatives avec des numéros de carte inconnus en 10 min | Alerte critique (attaque par énumération) |
| ≥ 3 PIN erronés en 1 h | Titulaire prévenu |
| LBC/FT : opération ≥ 5 000 $, volume ≥ 10 000 $/24 h, ≥ 5 dépôts proches du plafond, dépôt puis retrait quasi total en < 1 h sur un compte récent | Alerte conformité (examen humain, déclaration éventuelle à la CENTIF) |

Réactions **immédiates** (sans attendre l'agent) : alerte « nouvelle connexion » sur un nouvel appareil,
alerte et révocation en cas de vol de session, notification de PIN bloqué.

## 🔧 Agent de fiabilité — toutes les 5 min (prévenir et corriger les bugs)

| Contrôle | Correction |
|---|---|
| Écritures comptables déséquilibrées ou solde client négatif | **Mode protégé** : tous les mouvements de fonds sont suspendus (dépôts, retraits, change, cartes, transferts) + alerte critique. Levée par un administrateur uniquement quand le grand livre est de nouveau cohérent. |
| Solde en cache différent de la somme des écritures | **Auto-réparation** (les écritures font foi) + alerte |
| Dépôt Mobile Money en attente > 30 min | Re-vérification auprès du fournisseur, sinon expiration propre |
| Retrait en attente > 2 h | Alerte pour rapprochement manuel (jamais de remboursement automatique : l'argent a pu partir) |
| ≥ 5 erreurs serveur identiques en 10 min | Alerte critique avec message et route concernés |
| ≥ 10 notifications en échec en 1 h | Alerte (fournisseur SMS/e-mail en panne) |
| Données techniques expirées | Purge automatique (minimisation des données) |

En complément, la **CI GitHub** (`.github/workflows/ci.yml`) bloque les régressions avant la mise en
ligne : contrôles statiques (`npm run check`), tous les tests, `npm audit`, analyse de sécurité CodeQL,
et Dependabot propose chaque semaine les mises à jour de dépendances.

## 📣 Agent de notifications — toutes les 30 s

- Envoie la file d'attente (e-mail, SMS, alertes équipe) avec **relances exponentielles** (2, 4, 8… 60 min, 6 essais).
- Prévient les utilisateurs quand c'est utile : **solde de carte bas** (hebdomadaire), **carte qui expire** dans 30 jours,
  identité non vérifiée après 3 jours, PIN non défini.
- Respecte les préférences : les alertes de **sécurité** partent toujours (SMS + e-mail) ; transactions selon le choix
  de l'utilisateur ; offres commerciales **uniquement avec consentement**.

### Canaux (variables d'environnement)

| Canal | Fournisseurs | Variables |
|---|---|---|
| E-mail | `console` (dev), Resend, Brevo | `NOTIFY_EMAIL_PROVIDER`, `EMAIL_FROM`, `RESEND_API_KEY` / `BREVO_API_KEY` |
| SMS | `console` (dev), Africa's Talking, Twilio | `NOTIFY_SMS_PROVIDER`, `AT_USERNAME`, `AT_API_KEY`, `TWILIO_*` |
| Équipe | Webhook Slack/Discord/Teams, Telegram, e-mail | `ADMIN_ALERT_WEBHOOK_URL`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, `ADMIN_ALERT_EMAILS` |

Fréquences et seuils réglables : `AGENT_*_INTERVAL_SEC`, `AML_SINGLE_TX_USD_CENTS`, `AML_DAILY_USD_CENTS`,
`PENDING_DEPOSIT_EXPIRY_MIN`. Désactivation : `AGENTS_ENABLED=false`.
