'use strict';
// Orchestrateur des agents automatiques : exécution périodique, sans chevauchement,
// journalisation de chaque passage (consultable dans l'administration).
const config = require('../config');
const db = require('../db');
const system = require('../services/system');
const { alertAdmins } = require('../services/notify');

const AGENTS = {
  security: require('./securityAgent'),
  reliability: require('./reliabilityAgent'),
  notification: require('./notificationAgent'),
};
const running = new Set();
const timers = [];

async function runAgent(name) {
  const agent = AGENTS[name];
  if (!agent) throw new Error(`Agent inconnu : ${name}`);
  if (running.has(name)) return { skipped: true };
  running.add(name);
  const started = db.now();
  try {
    const summary = await agent.run();
    db.get().prepare('INSERT INTO agent_runs (agent, status, summary, started_at, finished_at) VALUES (?,?,?,?,?)')
      .run(name, 'ok', JSON.stringify(summary), started, db.now());
    return summary;
  } catch (err) {
    system.recordError(err, `agent:${name}`);
    db.get().prepare('INSERT INTO agent_runs (agent, status, summary, started_at, finished_at) VALUES (?,?,?,?,?)')
      .run(name, 'error', String(err.message), started, db.now());
    alertAdmins({ severity: 'critical', type: 'agent_failure', message: `L’agent ${name} a échoué : ${err.message}`, dedupeKey: `agent:${name}:${started.slice(0, 13)}` });
    return { error: err.message };
  } finally {
    running.delete(name);
  }
}

function status() {
  const d = db.get();
  return Object.keys(AGENTS).map((name) => {
    const last = d.prepare('SELECT * FROM agent_runs WHERE agent=? ORDER BY id DESC LIMIT 1').get(name);
    const errors24h = d.prepare("SELECT COUNT(*) AS n FROM agent_runs WHERE agent=? AND status='error' AND finished_at>=?")
      .get(name, new Date(Date.now() - 86400000).toISOString()).n;
    return { name, lastRun: last ? { status: last.status, at: last.finished_at, summary: safeJson(last.summary) } : null, errors24h, running: running.has(name) };
  });
}

const safeJson = (s) => { try { return JSON.parse(s); } catch { return s; } };

function start() {
  if (!config.agents.enabled) return;
  const a = config.agents;
  const every = (name, sec) => {
    const t = setInterval(() => { runAgent(name); }, sec * 1000);
    t.unref();
    timers.push(t);
    setTimeout(() => runAgent(name), 2000).unref();
  };
  every('security', a.securityIntervalSec);
  every('reliability', a.reliabilityIntervalSec);
  every('notification', a.notificationIntervalSec);
  console.log('Agents actifs : sécurité, fiabilité, notifications');
}

function stop() { timers.splice(0).forEach(clearInterval); }

module.exports = { runAgent, status, start, stop, AGENTS };
