const { Router } = require('express');
const customerController = require('./controller');
const { validateRequest } = require('../../middleware/validate-request');

const router = Router();

// POST /api/v1/customers - Create a customer
router.post(
  '/',
  validateRequest((req) => {
    const errors = [];
    const name = req.body.full_name || req.body.name;
    if (!name || typeof name !== 'string' || !name.trim()) {
      errors.push({ field: 'name', message: 'Name is required' });
    }
    if (
      req.body.initial_amount_collected !== undefined &&
      req.body.initial_amount_collected !== null
    ) {
      const amount = Number(req.body.initial_amount_collected);
      if (isNaN(amount) || amount < 0) {
        errors.push({
          field: 'initial_amount_collected',
          message: 'Initial amount collected must be a non-negative number',
        });
      }
    }
    return errors;
  }),
  customerController.createCustomer
);

// GET /api/v1/customers - List customers with search, pagination & status filter
router.get('/', customerController.getCustomers);

// GET /api/v1/customers/:id - Retrieve one customer by UUID
router.get(
  '/:id',
  validateRequest({
    params: {
      id: { type: 'uuid', required: true, message: 'Invalid customer ID format' },
    },
  }),
  customerController.getCustomerById
);

// PATCH /api/v1/customers/:id - Update customer details
router.patch(
  '/:id',
  validateRequest({
    params: {
      id: { type: 'uuid', required: true, message: 'Invalid customer ID format' },
    },
  }),
  customerController.updateCustomer
);

// PATCH /api/v1/customers/:id/status - Activate or deactivate customer
router.patch(
  '/:id/status',
  validateRequest({
    params: {
      id: { type: 'uuid', required: true, message: 'Invalid customer ID format' },
    },
  }),
  customerController.updateCustomerStatus
);

// GET /api/v1/customers/:id/loans - List loans for a customer
const loanController = require('../payment-plans/controller');
router.get(
  '/:id/loans',
  validateRequest({
    params: {
      id: { type: 'uuid', required: true, message: 'Invalid customer ID format' },
    },
  }),
  loanController.getLoansByCustomerId
);

// DELETE /api/v1/customers/:id - Delete customer and cascade delete dependent records
router.delete(
  '/:id',
  validateRequest({
    params: {
      id: { type: 'uuid', required: true, message: 'Invalid customer ID format' },
    },
  }),
  customerController.deleteCustomer
);

module.exports = router;
