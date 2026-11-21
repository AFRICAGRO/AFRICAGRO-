'use strict';
const config = require('./config');
const db = require('./db');
const fx = require('./services/fx');
const { createApp } = require('./app');

db.open();
const app = createApp();

fx.refreshLiveRates();
if (config.fxLive) setInterval(() => fx.refreshLiveRates(), 15 * 60 * 1000).unref();

const server = app.listen(config.port, () => {
  console.log(`AfriCard démarré sur http://localhost:${config.port} (env=${config.env}, mobile money=${config.mobileMoneyMode}, cartes=${config.cardIssuerMode})`);
});

for (const sig of ['SIGINT', 'SIGTERM']) {
  process.on(sig, () => server.close(() => process.exit(0)));
}
