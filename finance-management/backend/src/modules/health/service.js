const healthRepository = require('./repository');
const env = require('../../config/env');

/**
 * Health service containing health check business logic
 */
class HealthService {
  /**
   * Retrieves overall system health and runtime metadata
   */
  getSystemHealth() {
    return {
      status: 'ok',
      service: 'Finance Management API',
      version: '1.0.0',
      environment: env.NODE_ENV,
      uptimeSeconds: Math.floor(process.uptime()),
      timestamp: new Date().toISOString(),
      memory: {
        rssMb: Math.round((process.memoryUsage().rss / 1024 / 1024) * 100) / 100,
        heapUsedMb: Math.round((process.memoryUsage().heapUsed / 1024 / 1024) * 100) / 100,
      },
    };
  }

  /**
   * Retrieves database connection health
   */
  async getDatabaseHealth() {
    const dbStatus = await healthRepository.checkDatabaseConnection();

    return {
      status: dbStatus.connected ? 'ok' : 'degraded',
      database: {
        connected: dbStatus.connected,
        provider: 'Supabase PostgreSQL',
        checkedTable: dbStatus.checkedTable,
        latencyMs: dbStatus.latencyMs,
        ...(dbStatus.totalRecords !== undefined && { totalRecords: dbStatus.totalRecords }),
        ...(dbStatus.error && { error: dbStatus.error }),
      },
      timestamp: new Date().toISOString(),
    };
  }
}

module.exports = new HealthService();
