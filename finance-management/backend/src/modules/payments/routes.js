const { Router } = require('express');
const paymentController = require('./controller');

const router = Router();

// GET /api/v1/payments - List all payments
router.get('/', paymentController.getPayments);

module.exports = router;
