const { Router } = require('express');
const loanController = require('./controller');

const router = Router();

// POST /api/v1/loans/preview - Live calculation preview
router.post('/preview', loanController.previewLoan);

// POST /api/v1/loans - Create loan and generate installments
router.post('/', loanController.createLoan);

// GET /api/v1/loans - List loans with pagination and search
router.get('/', loanController.getLoans);

// GET /api/v1/loans/:id - Loan details and financial summary
router.get('/:id', loanController.getLoanById);

// GET /api/v1/loans/:id/installments - Loan installments
router.get('/:id/installments', loanController.getLoanInstallments);

// PATCH /api/v1/loans/:id - Update permitted loan details
router.patch('/:id', loanController.updateLoan);

module.exports = router;
