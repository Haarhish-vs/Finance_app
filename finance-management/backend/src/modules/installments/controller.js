const installmentService = require('./service');

/**
 * Controller for Installments
 */
class InstallmentController {
  async getInstallments(req, res, next) {
    try {
      const result = await installmentService.getInstallments({
        planId: req.query.plan_id || req.query.loan_id,
        customerId: req.query.customer_id,
        status: req.query.status,
        page: req.query.page,
        limit: req.query.limit,
      });
      res.status(200).json({
        success: true,
        message: 'Installments retrieved successfully',
        data: result.installments,
        pagination: result.pagination,
      });
    } catch (err) {
      next(err);
    }
  }

  async getInstallmentById(req, res, next) {
    try {
      const installment = await installmentService.getInstallmentById(req.params.id);
      res.status(200).json({
        success: true,
        message: 'Installment details retrieved successfully',
        data: installment,
      });
    } catch (err) {
      next(err);
    }
  }

  async updateInstallment(req, res, next) {
    try {
      const updated = await installmentService.updateInstallment(req.params.id, req.body);
      res.status(200).json({
        success: true,
        message: 'Installment updated successfully',
        data: updated,
      });
    } catch (err) {
      next(err);
    }
  }

  async recordPayment(req, res, next) {
    try {
      const result = await installmentService.recordPayment(req.params.id, req.body);
      res.status(201).json({
        success: true,
        message: result.isFullyPaid
          ? 'Installment marked as fully paid successfully'
          : 'Partial payment recorded successfully',
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  async getPayments(req, res, next) {
    try {
      const payments = await installmentService.getPayments(req.params.id);
      res.status(200).json({
        success: true,
        message: 'Payment history retrieved successfully',
        data: payments,
      });
    } catch (err) {
      next(err);
    }
  }
}

module.exports = new InstallmentController();
