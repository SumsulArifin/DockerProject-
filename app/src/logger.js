const pino = require('pino');
const config = require('./config');

const { logLevel, environment } = config();

const logger = pino({
  level: logLevel,
  base: { env: environment },
  timestamp: pino.stdTimeFunctions.isoTime,
});

module.exports = logger;
