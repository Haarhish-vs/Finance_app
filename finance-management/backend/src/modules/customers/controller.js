const customerService = require('./service');
const { sendSuccess } = require('../../utils/api-response');

/**
 * Customer Controller dispatching HTTP endpoints
 */
class CustomerController {
  /**
   * POST /api/v1/customers
   */
  createCustomer = async (req, res, next) => {
    try {
      const customer = await customerService.createCustomer(req.body);
      return sendSuccess(res, customer, 201, 'Customer created successfully');
    } catch (err) {
      next(err);
    }
  };

  /**
   * GET /api/v1/customers
   */
  getCustomers = async (req, res, next) => {
    try {
      const { search, status, page, limit } = req.query;
      const result = await customerService.getCustomers({ search, status, page, limit });
      return sendSuccess(res, result, 200, 'Customers retrieved successfully');
    } catch (err) {
      next(err);
    }
  };

  /**
   * GET /api/v1/customers/:id
   */
  getCustomerById = async (req, res, next) => {
    try {
      const { id } = req.params;
      const customer = await customerService.getCustomerById(id);
      return sendSuccess(res, customer, 200, 'Customer retrieved successfully');
    } catch (err) {
      next(err);
    }
  };

  /**
   * PATCH /api/v1/customers/:id
   */
  updateCustomer = async (req, res, next) => {
    try {
      const { id } = req.params;
      const customer = await customerService.updateCustomer(id, req.body);
      return sendSuccess(res, customer, 200, 'Customer updated successfully');
    } catch (err) {
      next(err);
    }
  };

  /**
   * PATCH /api/v1/customers/:id/status
   */
  updateCustomerStatus = async (req, res, next) => {
    try {
      const { id } = req.params;
      const { status, isActive } = req.body;
      const targetStatus = status !== undefined ? status : isActive;
      const customer = await customerService.updateCustomerStatus(id, targetStatus);
      return sendSuccess(res, customer, 200, 'Customer status updated successfully');
    } catch (err) {
      next(err);
    }
  };

  /**
   * DELETE /api/v1/customers/:id
   */
  deleteCustomer = async (req, res, next) => {
    try {
      const { id } = req.params;
      const result = await customerService.deleteCustomer(id);
      return sendSuccess(res, result, 200, 'Customer deleted successfully');
    } catch (err) {
      next(err);
    }
  };
}

module.exports = new CustomerController();
