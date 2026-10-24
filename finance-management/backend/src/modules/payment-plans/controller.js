const loanService = require('./service');
const installmentService = require('../installments/service');

/**
 * Controller for Loans & Payment Plans
 */
class LoanController {
  async previewLoan(req, res, next) {
    try {
      const preview = loanService.previewLoan(req.body);
      res.status(200).json({
        success: true,
        message: 'Loan calculation generated successfully',
        data: preview,
      });
    } catch (err) {
      next(err);
    }
  }

  async createLoan(req, res, next) {
    try {
      const result = await loanService.createLoan(req.body);
      res.status(201).json({
        success: true,
        message: 'Loan originated and installment schedule generated successfully',
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  async getLoans(req, res, next) {
    try {
      const result = await loanService.getLoans({
        search: req.query.search,
        status: req.query.status,
        customerId: req.query.customer_id,
        page: req.query.page,
        limit: req.query.limit,
      });
      res.status(200).json({
        success: true,
        message: 'Loans retrieved successfully',
        data: result.loans,
        pagination: result.pagination,
      });
    } catch (err) {
      next(err);
    }
  }

  async getLoanById(req, res, next) {
    try {
      const result = await loanService.getLoanById(req.params.id);
      res.status(200).json({
        success: true,
        message: 'Loan details retrieved successfully',
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  async getLoansByCustomerId(req, res, next) {
    try {
      const loans = await loanService.getLoansByCustomerId(req.params.id);
      res.status(200).json({
        success: true,
        message: 'Customer loans retrieved successfully',
        data: loans,
      });
    } catch (err) {
      next(err);
    }
  }

  async getLoanInstallments(req, res, next) {
    try {
      const result = await installmentService.getInstallments({
        planId: req.params.id,
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

  async updateLoan(req, res, next) {
    try {
      const updated = await loanService.updateLoan(req.params.id, req.body);
      res.status(200).json({
        success: true,
        message: 'Loan details updated successfully',
        data: updated,
      });
    } catch (err) {
      next(err);
    }
  }
}

module.exports = new LoanController();
