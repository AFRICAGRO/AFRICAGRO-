'use strict';
// Contrôles statiques rapides (exécutés en CI) : syntaxe de tous les fichiers JS
// et règles maison qui ont déjà causé des bugs.
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const ROOT = path.join(__dirname, '..');
const files = [];
(function walk(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (['node_modules', '.git', 'data'].includes(e.name)) continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p); else if (p.endsWith('.js')) files.push(p);
  }
}(ROOT));

const problems = [];
for (const f of files) {
  try { execFileSync(process.execPath, ['--check', f], { stdio: 'pipe' }); } catch (err) { problems.push(`${f}: erreur de syntaxe\n${err.stderr}`); }
}

const front = fs.readFileSync(path.join(ROOT, 'public/app.js'), 'utf8');
// Un identifiant HTML commençant par un chiffre n'est pas un sélecteur CSS valide (#2fa…).
for (const m of front.matchAll(/['"`]#(\d\w*-[\w-]+)/g)) problems.push(`public/app.js : sélecteur invalide #${m[1]}`);
// Après un "await", e.currentTarget vaut null : il faut le capturer avant.
for (const m of front.matchAll(/await[^;\n]*\n?[^;\n]*withBusy\(e\.currentTarget/g)) problems.push(`public/app.js : e.currentTarget utilisé après await (${m[0].slice(0, 40)}…)`);
// Pas d'attribut style inline (bloqué par la CSP).
if (/\sstyle="/.test(front)) problems.push('public/app.js : attribut style="" interdit par la CSP');

if (problems.length) {
  console.error(problems.join('\n'));
  process.exit(1);
}
console.log(`OK : ${files.length} fichiers vérifiés`);
