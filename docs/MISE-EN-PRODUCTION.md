# Passer de la sandbox à la production

Le code est prêt ; ce qui manque pour manipuler de l'argent réel relève des **partenaires,
licences et contrôles** — aucune plateforme ne peut émettre de vraies cartes Visa/Mastercard
ni collecter du Mobile Money sans eux.

## 1. Cadre réglementaire (à valider avec un juriste fintech)

| Zone | Régulateur | Statut typique |
|---|---|---|
| UEMOA (CI, SN, ML, BF, BJ, TG, NE, GW) | BCEAO | Agrément d'**établissement de monnaie électronique (EME)** ou partenariat avec une banque/EME agréée |
| CEMAC (CM, GA, CG, TD, CF, GQ) | BEAC / COBAC | Agrément EME ou partenariat bancaire |
| Nigeria | CBN | Licence PSSP / MMO, ou partenariat |
| Ghana | Bank of Ghana | Licence EMI / PSP |
| Kenya | CBK | Licence PSP |
| RDC, Guinée, Rwanda, Ouganda… | Banques centrales nationales | Licence PSP/EME ou partenariat |

Démarrage le plus rapide : **opérer comme agent/programme d'un partenaire déjà agréé** (banque
ou EME) et d'un **émetteur de cartes** qui porte la licence Visa/Mastercard.

Obligations associées, déjà préparées dans le code :
- **KYC/LCB-FT** : niveaux et plafonds (`src/services/limits.js`), dossier KYC chiffré, file de revue admin.
  À compléter : vérification documentaire et selfie (Smile ID, Youverify, Sumsub, Onfido…), filtrage
  sanctions/PPE, déclarations de soupçon à la CENTIF / cellule de renseignement financier.
- **Protection des données** : lois nationales (ex. CI loi 2013-450, SN loi 2008-12, NDPA Nigeria).
- **Réglementation des changes** (BCEAO R09/2010 notamment) : vérifiez les plafonds de paiements
  en devises et les obligations de déclaration de votre partenaire.

## 2. Émetteur de cartes (BIN sponsor)

Remplacez `issue()` dans `src/providers/cardIssuer.js` par l'API de votre émetteur et branchez son
webhook « authorization request » sur `cards.authorize()` (même logique de contrôle que le simulateur).
Émetteurs actifs sur le continent à comparer : Union54, Bridgecard, Sudo Africa, Maplerad,
Flutterwave, Paystack, Marqeta/Stripe Issuing (selon pays). Exigez :
- **PCI-DSS** : idéalement l'émetteur conserve le PAN et vous affiche la carte via son **widget
  sécurisé** (votre périmètre PCI se réduit alors fortement) ;
- 3-D Secure (OTP par SMS/app) ;
- règlement en USD/EUR et pré-financement (float) clair.

## 3. Agrégateurs Mobile Money

Adaptateurs fournis dans `src/providers/mobileMoney.js` :
- **CinetPay** — UEMOA, CEMAC, Guinée, RDC ;
- **Flutterwave** — Nigeria, Ghana, Kenya, Ouganda, Rwanda, Zambie, Afrique du Sud, Égypte ;
- **pawaPay** — Gabon, Congo, Tchad, RDC, Tanzanie, Zambie, Éthiopie.

Ils suivent la structure publique des API mais **doivent être testés avec vos identifiants
sandbox** et la documentation à jour de chaque fournisseur avant mise en production
(noms de champs, codes opérateurs, signatures de webhooks). Puis : `MOBILE_MONEY_MODE=live`.

## 4. Change

Activez `FX_LIVE=true` ou branchez le flux de cours de votre banque. En production, la position
`fx_pool` doit être couverte (achat réel de devises auprès de la banque partenaire) : surveillez-la
via `/api/admin/stats` et le grand livre.

## 5. Infrastructure

- **Base de données** : SQLite (WAL) convient au lancement sur un serveur unique. Au-delà
  (plusieurs instances, forte charge), migrer vers **PostgreSQL** — le schéma est standard SQL.
- **Secrets** : `JWT_SECRET`, `DATA_ENCRYPTION_KEY` dans un coffre (Vault, AWS KMS, Doppler) ;
  idéalement chiffrement d'enveloppe avec KMS/HSM.
- **HTTPS obligatoire**, sauvegardes chiffrées et testées, supervision (logs, alertes sur
  `ledger/integrity`), tests d'intrusion avant lancement.
- **SMS/WhatsApp** : `src/services/notify.js` est le point d'extension (Africa's Talking, Twilio,
  Termii, Orange SMS API).

## 6. Liste de contrôle avant lancement

- [ ] Contrat signé avec un émetteur de cartes et un agrégateur Mobile Money
- [ ] Statut réglementaire validé dans chaque pays ouvert
- [ ] `SANDBOX_AUTO_APPROVE_KYC=false` et fournisseur KYC branché
- [ ] Secrets générés, stockés hors du code
- [ ] Webhooks testés (signature, rejeu, ordre des événements)
- [ ] Rapprochement quotidien : grand livre ↔ relevés agrégateur ↔ relevés émetteur
- [ ] Test d'intrusion et revue de code sécurité
- [ ] Conditions générales, politique de confidentialité, grille tarifaire publiée
