# Politique de sécurité

## Signaler une vulnérabilité

Si vous découvrez une faille de sécurité dans AfriCard, **ne l'ouvrez pas en ticket public**.
Écrivez à **security@africard.example** [À COMPLÉTER] avec :

- la description du problème et son impact ;
- les étapes pour le reproduire ;
- vos coordonnées si vous souhaitez être crédité.

Nous accusons réception sous 72 heures, tenons le signaleur informé, et publions un correctif
au plus vite. Les recherches menées de bonne foi, sans accès aux données d'autrui ni interruption
du service, ne feront l'objet d'aucune poursuite.

## Défenses en place

- Agents automatiques de sécurité, de fiabilité et de notification (voir `docs/AGENTS.md`).
- Chiffrement AES-256-GCM des données sensibles, scrypt pour les secrets, 2FA TOTP, PIN de transaction.
- Grand livre en partie double avec contrôle continu et « mode protégé ».
- CI : tests automatiques, contrôles statiques, `npm audit`, analyse CodeQL, mises à jour Dependabot.
