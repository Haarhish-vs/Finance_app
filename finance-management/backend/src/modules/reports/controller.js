const reportsService = require('./service');

class ReportsController {
  async getReport(req, res, next) {
    try {
      const { range } = req.query;
      const report = await reportsService.getReport({ range });
      res.status(200).json({
        success: true,
        data: report,
      });
    } catch (err) {
      next(err);
    }
  }

  async exportCsv(req, res, next) {
    try {
      const { range } = req.query;
      const csvData = await reportsService.generateCsv({ range });
      const safeRange = (range || 'all_time').toLowerCase().replace(/[^a-z0-9_-]/g, '_');
      const filename = `finance_report_${safeRange}_${new Date().toISOString().slice(0, 10)}.csv`;

      res.setHeader('Content-Type', 'text/csv; charset=utf-8');
      res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
      res.status(200).send(csvData);
    } catch (err) {
      next(err);
    }
  }
}

module.exports = new ReportsController();
