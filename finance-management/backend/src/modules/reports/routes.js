const { Router } = require('express');
const reportsController = require('./controller');

const router = Router();

// GET /api/v1/reports -> JSON summary and datasets
router.get('/', (req, res, next) => reportsController.getReport(req, res, next));

// GET /api/v1/reports/export-csv -> Downloadable CSV attachment
router.get('/export-csv', (req, res, next) => reportsController.exportCsv(req, res, next));

module.exports = router;
