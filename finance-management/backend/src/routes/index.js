const { Router } = require('express');
const healthRoutes = require('../modules/health/routes');
const authRoutes = require('../modules/auth/routes');
const customerRoutes = require('../modules/customers/routes');
const loanRoutes = require('../modules/payment-plans/routes');
const installmentRoutes = require('../modules/installments/routes');
const paymentRoutes = require('../modules/payments/routes');
const reportsRoutes = require('../modules/reports/routes');
const dashboardRoutes = require('../modules/dashboard/routes');
const { authenticateAdmin } = require('../middleware/auth');

const apiRouter = Router();

// Public routes
apiRouter.use('/health', healthRoutes);
apiRouter.use('/auth', authRoutes);

// Protected admin routes
apiRouter.use('/dashboard', authenticateAdmin, dashboardRoutes);
apiRouter.use('/customers', authenticateAdmin, customerRoutes);
apiRouter.use('/loans', authenticateAdmin, loanRoutes);
apiRouter.use('/payment-plans', authenticateAdmin, loanRoutes);
apiRouter.use('/installments', authenticateAdmin, installmentRoutes);
apiRouter.use('/payments', authenticateAdmin, paymentRoutes);
apiRouter.use('/reports', authenticateAdmin, reportsRoutes);

module.exports = apiRouter;
