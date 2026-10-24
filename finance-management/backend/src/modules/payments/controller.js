const paymentRepository = require('./repository');

/**
 * Controller for Payment History
 */
class PaymentController {
  async getPayments(req, res, next) {
    try {
      const page = Math.max(1, parseInt(req.query.page, 10) || 1);
      const limit = Math.min(100, Math.max(1, parseInt(req.query.limit, 10) || 20));
      const offset = (page - 1) * limit;

      const { payments, totalCount } = await paymentRepository.findAll({
        customerId: req.query.customer_id,
        planId: req.query.plan_id || req.query.loan_id,
        offset,
        limit,
      });

      const totalPages = Math.ceil(totalCount / limit) || 1;

      res.status(200).json({
        success: true,
        message: 'Payments retrieved successfully',
        data: payments,
        pagination: {
          page,
          limit,
          totalRecords: totalCount,
          totalPages,
          hasNextPage: page < totalPages,
          hasPrevPage: page > 1,
        },
      });
    } catch (err) {
      next(err);
    }
  }
}

module.exports = new PaymentController();
