const { Router } = require('express');
const installmentController = require('./controller');

const router = Router();

// GET /api/v1/installments - List installments across system or filtered by plan/customer
router.get('/', installmentController.getInstallments);

// GET /api/v1/installments/:id - Get single installment
router.get('/:id', installmentController.getInstallmentById);

// PATCH /api/v1/installments/:id - Update permitted installment details (due date, amount)
router.patch('/:id', installmentController.updateInstallment);

// POST /api/v1/installments/:id/payments - Record a payment / Mark as paid
router.post('/:id/payments', installmentController.recordPayment);

// GET /api/v1/installments/:id/payments - Payment history for this installment
router.get('/:id/payments', installmentController.getPayments);

module.exports = router;
