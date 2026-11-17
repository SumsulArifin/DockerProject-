const pkg = require('../package.json');

function config() {
  return {
    port: parseInt(process.env.PORT, 10) || 8080,
    logLevel: process.env.LOG_LEVEL || 'info',
    environment: process.env.APP_ENV || 'development',
    version: process.env.APP_VERSION || pkg.version,
  };
}

module.exports = config;
