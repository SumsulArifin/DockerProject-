const express = require('express');
const config = require('./config');
const logger = require('./logger');
const { register, metricsMiddleware } = require('./metrics');

function createApp() {
  const app = express();
  const { version, environment } = config();

  app.use(metricsMiddleware);

  app.use((req, res, next) => {
    res.on('finish', () => {
      logger.info({
        method: req.method,
        path: req.path,
        status: res.statusCode,
      }, 'request handled');
    });
    next();
  });

  app.get('/', (req, res) => {
    res.json({ message: 'Hello from DevOps Task!', status: 'running', version });
  });

  app.get('/health', (req, res) => {
    res.json({ status: 'ok', environment, version });
  });

  app.get('/metrics', async (req, res) => {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  });

  // Keep after routes so route matching above still happens first.
  app.use((req, res) => {
    res.status(404).json({ error: 'not found' });
  });

  return app;
}

module.exports = createApp;
