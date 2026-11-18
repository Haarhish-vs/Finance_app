const { Router } = require('express');
const dashboardController = require('./controller');
const { authenticateAdmin } = require('../../middleware/auth');

const router = Router();

// GET /api/v1/dashboard/weekly-collections (protected)
router.get('/weekly-collections', authenticateAdmin, dashboardController.getWeeklyCollections);

module.exports = router;

