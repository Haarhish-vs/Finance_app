const { Router } = require('express');
const healthController = require('./controller');

const router = Router();

// GET /api/v1/health
router.get('/', healthController.getHealth);

// GET /api/v1/health/db
router.get('/db', healthController.getDbHealth);

module.exports = router;
