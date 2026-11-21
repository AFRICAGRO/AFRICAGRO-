# API AfriCard (`/api`)

Authentification : `Authorization: Bearer <accessToken>`. Montants transmis en chaînes décimales
(`"15.49"`, `"5000"`). Les opérations financières acceptent un en-tête `Idempotency-Key`.
Les actions sensibles exigent `pin` dans le corps (ou l'en-tête `X-Transaction-Pin`).
Erreurs : `{ "error": { "code": "INSUFFICIENT_FUNDS", "message": "…" } }`.

## Authentification
| Méthode | Route | Description |
|---|---|---|
| POST | `/auth/register` | `fullName, email, country, phone, password` |
| POST | `/auth/login` | `login` (e-mail ou téléphone), `password`, `country?`, `totp?` |
| POST | `/auth/refresh` | Cookie httpOnly → nouveau jeton (rotation) |
| POST | `/auth/logout`, `/auth/logout-all` | Déconnexion |
| GET | `/auth/me` | Profil + plafonds |

## Compte & sécurité
| POST | `/security/pin` | `pin, password, currentPin?` |
|---|---|---|
| POST | `/security/password` | `currentPassword, newPassword` |
| POST | `/security/2fa/setup` · `/enable` · `/disable` | TOTP |
| GET | `/security/sessions`, `/security/activity` | Sessions, journal |
| PATCH | `/profile` | `preferredCurrency` |
| POST/GET | `/kyc` | `targetLevel, idType, idNumber, dateOfBirth, address` |
| GET | `/notifications` · POST `/notifications/read` | |
| GET | `/transactions?type=&from=&to=&limit=` · `/transactions/export.csv` | Historique, relevé |

## Argent
| GET | `/wallets` | Soldes + total en devise préférée |
|---|---|---|
| POST | `/fx/quote` | `from, to, amount, mode: sell\|buy` → cotation 60 s |
| POST | `/fx/execute` | `quoteId` |
| POST | `/deposits/preview`, `/deposits` | `country, operator, phone, amount` |
| POST | `/withdrawals/preview`, `/withdrawals` | idem + `pin` |
| GET | `/mobile-money`, `/mobile-money/:id` | Suivi des opérations |
| POST | `/transfers` | `recipient, recipientCountry?, currency, amount, note?, pin` |

## Cartes
| GET/POST | `/cards` | Liste / création (`label, brand, currency, initialAmount?, fundingCurrency?, singleUse?, lockToFirstMerchant?, perTxLimit?, monthlyLimit?, pin`) |
|---|---|---|
| GET | `/cards/:id`, `/cards/:id/authorizations` | Détail, paiements |
| POST | `/cards/:id/load/preview`, `/cards/:id/load` | `amount, sourceCurrency?` (conversion auto) |
| POST | `/cards/:id/unload` | `amount` |
| POST | `/cards/:id/freeze` · `/unfreeze` (pin) · `/terminate` (pin) | |
| PATCH | `/cards/:id/controls` | `perTxLimit, monthlyLimit, blockedCategories, allowedCountries, merchantLock, label` |
| POST | `/cards/:id/reveal` | `pin` → PAN, CVV, expiration |

## Référentiels (public)
`GET /meta/countries`, `/meta/currencies`, `/meta/rates`, `/meta/card-categories`, `/meta/tiers`, `/meta/fees`

## Webhooks & sandbox
| POST | `/webhooks/mobile-money/:provider` | `sandbox`, `cinetpay`, `flutterwave`, `pawapay` (signature vérifiée) |
|---|---|---|
| POST | `/sandbox/mobile-money/:id/confirm` | `success: true\|false` |
| POST | `/sandbox/card-authorizations` | Simule un achat marchand |
| POST | `/sandbox/card-authorizations/:id/refund` | Remboursement marchand |

## Administration (rôle admin)
`GET /admin/stats`, `/admin/users?q=`, `/admin/kyc`, `/admin/ledger/integrity`, `/admin/audit` ·
`POST /admin/users/:id/status`, `/admin/kyc/:id/review`
