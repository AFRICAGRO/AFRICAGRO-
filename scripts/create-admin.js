'use strict';
// Usage : npm run seed:admin -- admin@exemple.com
// Promeut un compte existant au rôle administrateur.
const db = require('../src/db');

const email = (process.argv[2] || '').toLowerCase();
if (!email) {
  console.error('Usage : npm run seed:admin -- <email>');
  process.exit(1);
}
db.open();
const r = db.get().prepare("UPDATE users SET role='admin' WHERE email=?").run(email);
console.log(r.changes ? `${email} est maintenant administrateur.` : `Aucun compte trouvé pour ${email}.`);
