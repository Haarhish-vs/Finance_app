const dashboardService = require('./service');
const { sendSuccess } = require('../../utils/api-response');

class DashboardController {
  /**
   * GET /api/v1/dashboard/weekly-collections
   */
  getWeeklyCollections = async (req, res, next) => {
    try {
      const { week_date, week_start, week_end } = req.query;
      const data = await dashboardService.getWeeklyCollections({
        weekDate: week_date,
        weekStart: week_start,
        weekEnd: week_end,
      });
      return sendSuccess(res, data, 200, 'Weekly collections retrieved successfully');
    } catch (err) {
      next(err);
    }
  };
}

module.exports = new DashboardController();

