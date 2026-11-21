'use strict';
const config = require('./config');
const db = require('./db');
const fx = require('./services/fx');
const { createApp } = require('./app');
const agents = require('./agents');
const { recordError } = require('./services/system');

db.open();
const app = createApp();

fx.refreshLiveRates();
if (config.fxLive) setInterval(() => fx.refreshLiveRates(), 15 * 60 * 1000).unref();

agents.start();
process.on('unhandledRejection', (err) => { console.error('unhandledRejection', err); recordError(err, 'process'); });
process.on('uncaughtException', (err) => { console.error('uncaughtException', err); recordError(err, 'process'); });

const server = app.listen(config.port, () => {
  console.log(`AfriCard démarré sur http://localhost:${config.port} (env=${config.env}, mobile money=${config.mobileMoneyMode}, cartes=${config.cardIssuerMode})`);
});

for (const sig of ['SIGINT', 'SIGTERM']) {
  process.on(sig, () => { agents.stop(); server.close(() => process.exit(0)); });
}
