'use strict';
const db = require('../db');
const { uuid } = require('../lib/crypto');

/** Notification in-app (point d'extension : SMS, WhatsApp, e-mail, push). */
function notify(userId, title, body) {
  db.get().prepare('INSERT INTO notifications (id, user_id, title, body) VALUES (?,?,?,?)').run(uuid(), userId, title, body);
}

function audit(userId, action, ip, details) {
  db.get().prepare('INSERT INTO audit_logs (user_id, action, ip, details) VALUES (?,?,?,?)')
    .run(userId || null, action, ip || null, details ? JSON.stringify(details) : null);
}

module.exports = { notify, audit };
