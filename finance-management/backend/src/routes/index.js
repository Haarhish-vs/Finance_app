const { Router } = require('express');
const healthRoutes = require('../modules/health/routes');
const customerRoutes = require('../modules/customers/routes');
const loanRoutes = require('../modules/payment-plans/routes');
const installmentRoutes = require('../modules/installments/routes');
const paymentRoutes = require('../modules/payments/routes');

const apiRouter = Router();

// Mount health routes under /health -> /api/v1/health, /api/v1/health/db
apiRouter.use('/health', healthRoutes);

// Mount customer routes under /customers -> /api/v1/customers
apiRouter.use('/customers', customerRoutes);

// Mount loan routes under /loans and /payment-plans
apiRouter.use('/loans', loanRoutes);
apiRouter.use('/payment-plans', loanRoutes);

// Mount installment routes under /installments
apiRouter.use('/installments', installmentRoutes);

// Mount payment routes under /payments
apiRouter.use('/payments', paymentRoutes);

module.exports = apiRouter;
