const env = require('./config/env');
const app = require('./app');

const PORT = env.PORT;

const server = app.listen(PORT, () => {
  const hasUrl = Boolean(env.SUPABASE_URL);
  const hasKey = Boolean(env.SUPABASE_SECRET_KEY);

  console.log(`[Finance Management Server] Started successfully on port ${PORT} [${env.NODE_ENV}]`);
  console.log(`[Supabase Config] URL present: ${hasUrl}, Secret Key present: ${hasKey}`);
  console.log(`[Health Checks] GET http://localhost:${PORT}/api/v1/health`);
  console.log(`[DB Health]     GET http://localhost:${PORT}/api/v1/health/db`);
});

// Graceful shutdown handling
function handleShutdown(signal) {
  console.log(`[Server] Received ${signal}. Initiating graceful shutdown...`);
  server.close(() => {
    console.log('[Server] HTTP server closed gracefully.');
    process.exit(0);
  });

  // Force shutdown after timeout if pending connections hang
  setTimeout(() => {
    console.error('[Server] Forced shutdown due to timeout.');
    process.exit(1);
  }, 10000).unref();
}

process.on('SIGTERM', () => handleShutdown('SIGTERM'));
process.on('SIGINT', () => handleShutdown('SIGINT'));

module.exports = server;
