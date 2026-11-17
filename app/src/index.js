const createApp = require('./app');
const config = require('./config');
const logger = require('./logger');

const { port } = config();
const app = createApp();

const server = app.listen(port, () => {
  logger.info({ port }, 'server listening');
});

function shutdown(signal) {
  logger.info({ signal }, 'shutting down');
  server.close((err) => {
    if (err) {
      logger.error({ err }, 'error during shutdown');
      process.exit(1);
    }
    process.exit(0);
  });

  // Force-exit if connections don't drain in time.
  setTimeout(() => process.exit(1), 10000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

module.exports = server;
