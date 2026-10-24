const healthService = require('./service');
const { sendSuccess } = require('../../utils/api-response');

/**
 * Health Controller handling HTTP requests for health verification
 */
class HealthController {
  /**
   * Handles GET /api/v1/health
   */
  getHealth = (req, res, next) => {
    try {
      const data = healthService.getSystemHealth();
      return sendSuccess(res, data, 200, 'Finance Management API is operational');
    } catch (err) {
      next(err);
    }
  };

  /**
   * Handles GET /api/v1/health/db
   */
  getDbHealth = async (req, res, next) => {
    try {
      const data = await healthService.getDatabaseHealth();
      const statusCode = data.database.connected ? 200 : 503;
      const message = data.database.connected
        ? 'Database connectivity verified successfully'
        : 'Database connectivity check failed';

      return res.status(statusCode).json({
        success: data.database.connected,
        message,
        ...data,
      });
    } catch (err) {
      next(err);
    }
  };
}

module.exports = new HealthController();
