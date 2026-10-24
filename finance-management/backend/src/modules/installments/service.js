const installmentRepository = require('./repository');
const paymentRepository = require('../payments/repository');
const loanRepository = require('../payment-plans/repository');
const AppError = require('../../utils/api-error');

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

class InstallmentService {
  /**
   * Get installments with pagination and filters
   */
  async getInstallments({ planId, customerId, status, page = 1, limit = 50 }) {
    const parsedPage = Math.max(1, parseInt(page, 10) || 1);
    const parsedLimit = Math.min(100, Math.max(1, parseInt(limit, 10) || 50));
    const offset = (parsedPage - 1) * parsedLimit;

    if (planId && !UUID_REGEX.test(planId)) {
      throw AppError.badRequest('Invalid plan ID format', null, 'INVALID_PLAN_ID');
    }
    if (customerId && !UUID_REGEX.test(customerId)) {
      throw AppError.badRequest('Invalid customer ID format', null, 'INVALID_CUSTOMER_ID');
    }

    const { installments, totalCount } = await installmentRepository.findAll({
      planId,
      customerId,
      status,
      offset,
      limit: parsedLimit,
    });

    const formatted = installments.map((i) => this._formatInstallment(i));
    const totalPages = Math.ceil(totalCount / parsedLimit) || 1;

    return {
      installments: formatted,
      pagination: {
        page: parsedPage,
        limit: parsedLimit,
        totalRecords: totalCount,
        totalPages,
        hasNextPage: parsedPage < totalPages,
        hasPrevPage: parsedPage > 1,
      },
    };
  }

  /**
   * Get a single installment by ID
   */
  async getInstallmentById(id) {
    if (!id || !UUID_REGEX.test(id)) {
      throw AppError.badRequest('Invalid installment ID format', null, 'INVALID_INSTALLMENT_ID');
    }

    const installment = await installmentRepository.findById(id);
    if (!installment) {
      throw AppError.notFound(`Installment not found with ID ${id}`, 'INSTALLMENT_NOT_FOUND');
    }

    return this._formatInstallment(installment);
  }

  /**
   * Update permitted installment details (due date and amount due)
   */
  async updateInstallment(id, data) {
    if (!id || !UUID_REGEX.test(id)) {
      throw AppError.badRequest('Invalid installment ID format', null, 'INVALID_INSTALLMENT_ID');
    }

    const existing = await installmentRepository.findById(id);
    if (!existing) {
      throw AppError.notFound(`Installment not found with ID ${id}`, 'INSTALLMENT_NOT_FOUND');
    }

    if (existing.status === 'paid') {
      throw AppError.badRequest(
        'Cannot modify an installment that has already been fully paid',
        [{ field: 'status', message: 'Installment is already paid' }],
        'INSTALLMENT_ALREADY_PAID'
      );
    }

    const updates = {};

    if (data.due_date !== undefined) {
      const parsedDate = new Date(data.due_date);
      if (isNaN(parsedDate.getTime())) {
        throw AppError.badRequest('Invalid due date format', [
          { field: 'due_date', message: 'Must be a valid date YYYY-MM-DD' },
        ]);
      }
      updates.due_date = parsedDate.toISOString().split('T')[0];
    }

    if (data.amount_due !== undefined) {
      const newAmount = Math.round(Number(data.amount_due) * 100) / 100;
      if (isNaN(newAmount) || newAmount <= 0) {
        throw AppError.badRequest('Amount due must be greater than 0', [
          { field: 'amount_due', message: 'Amount must be > 0' },
        ]);
      }
      const currentPaid = Number(existing.amount_paid) || 0;
      if (newAmount < currentPaid) {
        throw AppError.badRequest(
          `Amount due cannot be less than already collected amount (₹${currentPaid})`,
          [{ field: 'amount_due', message: `Must be >= ₹${currentPaid}` }]
        );
      }
      updates.amount_due = newAmount;
    }

    const updated = await installmentRepository.update(id, updates);

    // If amount_due changed, update total_amount on the parent loan
    if (updates.amount_due !== undefined) {
      const allPlanInstallments = await installmentRepository.findByPlanId(existing.plan_id);
      let newTotal = 0;
      for (const inst of allPlanInstallments) {
        newTotal += Number(inst.amount_due) || 0;
      }
      newTotal = Math.round(newTotal * 100) / 100;
      await loanRepository.update(existing.plan_id, { total_amount: newTotal });
    }

    return this._formatInstallment(updated);
  }

  /**
   * Record payment against an installment
   */
  async recordPayment(installmentId, data) {
    if (!installmentId || !UUID_REGEX.test(installmentId)) {
      throw AppError.badRequest('Invalid installment ID format', null, 'INVALID_INSTALLMENT_ID');
    }

    const installment = await installmentRepository.findById(installmentId);
    if (!installment) {
      throw AppError.notFound(`Installment not found with ID ${installmentId}`, 'INSTALLMENT_NOT_FOUND');
    }

    const currentPaid = Number(installment.amount_paid) || 0;
    const currentDue = Number(installment.amount_due) || 0;
    const outstanding = Math.max(0, Math.round((currentDue - currentPaid) * 100) / 100);

    if (outstanding <= 0 && installment.status === 'paid') {
      throw AppError.badRequest(
        'This installment is already fully settled',
        null,
        'INSTALLMENT_ALREADY_PAID'
      );
    }

    const paymentAmount = Math.round(Number(data.amount) * 100) / 100;
    if (isNaN(paymentAmount) || paymentAmount <= 0) {
      throw AppError.badRequest('Payment amount must be greater than 0', [
        { field: 'amount', message: 'Payment amount must be > 0' },
      ]);
    }

    // Compute new paid and status
    const newPaid = Math.round((currentPaid + paymentAmount) * 100) / 100;
    const isFullyPaid = newPaid >= currentDue;
    const dbStatus = isFullyPaid ? 'paid' : 'partial';

    const paymentDate = data.payment_date ? new Date(data.payment_date).toISOString() : new Date().toISOString();
    const reference = data.payment_reference || `RCP-${Date.now().toString().slice(-8)}`;

    // 1. Record in payments table
    const paymentRecord = await paymentRepository.create({
      payment_reference: reference,
      customer_id: installment.customer_id,
      plan_id: installment.plan_id,
      installment_id: installmentId,
      amount: paymentAmount,
      payment_date: paymentDate,
      payment_method: (data.payment_method || 'cash').toLowerCase(),
      notes: data.notes || `Settlement for installment #${installment.installment_number}`,
    });

    // 2. Update installment status & paid amount
    const updatedInstallment = await installmentRepository.update(installmentId, {
      amount_paid: newPaid,
      status: dbStatus,
      paid_at: isFullyPaid ? paymentDate : installment.paid_at,
    });

    // 3. Check if all installments for the loan are now settled
    const allPlanInstallments = await installmentRepository.findByPlanId(installment.plan_id);
    const allSettled = allPlanInstallments.every((item) => {
      const p = Number(item.amount_paid) || 0;
      const d = Number(item.amount_due) || 0;
      return p >= d && d > 0;
    });

    if (allSettled) {
      await loanRepository.update(installment.plan_id, { status: 'completed' });
    }

    return {
      payment: paymentRecord,
      installment: this._formatInstallment(updatedInstallment),
      isFullyPaid,
      isLoanCompleted: allSettled,
    };
  }

  /**
   * Get payment history for an installment
   */
  async getPayments(installmentId) {
    if (!installmentId || !UUID_REGEX.test(installmentId)) {
      throw AppError.badRequest('Invalid installment ID format', null, 'INVALID_INSTALLMENT_ID');
    }
    return paymentRepository.findByInstallmentId(installmentId);
  }

  _formatInstallment(item) {
    const todayStr = new Date().toISOString().split('T')[0];
    const amountDue = Number(item.amount_due) || 0;
    const amountPaid = Number(item.amount_paid) || 0;
    const outstanding = Math.max(0, Math.round((amountDue - amountPaid) * 100) / 100);

    let status = item.status || 'pending';
    if (amountPaid >= amountDue && amountDue > 0) {
      status = 'paid';
    } else if (amountPaid > 0 && amountPaid < amountDue) {
      status = item.due_date && item.due_date < todayStr ? 'overdue' : 'partially_paid';
    } else if (amountPaid === 0 && item.due_date && item.due_date < todayStr) {
      status = 'overdue';
    }

    const frequency = item.payment_plans ? item.payment_plans.frequency : 'monthly';
    const periodLabel = frequency === 'weekly'
      ? `Week ${item.installment_number}`
      : `Month ${item.installment_number}`;

    return {
      id: item.id,
      plan_id: item.plan_id,
      customer_id: item.customer_id,
      customer: item.customers || null,
      customer_name: item.customers ? item.customers.full_name : null,
      plan: item.payment_plans || null,
      plan_code: item.payment_plans ? item.payment_plans.plan_code : null,
      installment_number: item.installment_number,
      period_label: periodLabel,
      due_date: item.due_date,
      amount_due: amountDue,
      amount_paid: amountPaid,
      outstanding_balance: outstanding,
      status,
      paid_at: item.paid_at,
      created_at: item.created_at,
      updated_at: item.updated_at,
    };
  }
}

module.exports = new InstallmentService();
