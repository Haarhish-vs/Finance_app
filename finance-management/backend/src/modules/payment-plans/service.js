const loanRepository = require('./repository');
const installmentRepository = require('../installments/repository');
const customerService = require('../customers/service');
const customerRepository = require('../customers/repository');
const loanCalculator = require('../../utils/loan-calculator');
const AppError = require('../../utils/api-error');

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

class LoanService {
  /**
   * Generates a live calculation preview before saving
   */
  previewLoan(data) {
    const principal = Number(data.principal ?? data.principal_amount);
    const interestRate = Number(data.interest_rate);
    const totalInstallments = Number(data.total_installments ?? data.duration_in_weeks ?? data.duration_in_months);
    const frequency = (data.frequency || 'monthly').toLowerCase();

    if (isNaN(principal) || principal <= 0) {
      throw AppError.badRequest('Principal loan amount must be greater than 0', [
        { field: 'principal', message: 'Principal must be > 0' },
      ]);
    }
    if (isNaN(interestRate) || interestRate < 0) {
      throw AppError.badRequest('Interest rate must be a non-negative number', [
        { field: 'interest_rate', message: 'Interest rate must be >= 0' },
      ]);
    }
    if (isNaN(totalInstallments) || totalInstallments <= 0 || !Number.isInteger(totalInstallments)) {
      throw AppError.badRequest('Installment count must be a positive integer', [
        { field: 'total_installments', message: 'Must be >= 1' },
      ]);
    }

    return loanCalculator.generateSchedule({
      principal,
      interestRate,
      frequency,
      totalInstallments,
      startDate: data.start_date,
      firstDueDate: data.first_due_date,
      customInstallments: data.custom_installments || null,
    });
  }

  /**
   * Creates a loan (and optionally creates the customer if new customer info is provided)
   */
  async createLoan(data) {
    let customerId = data.customer_id;

    // If new customer details provided, create or find customer
    if (!customerId) {
      const customerName = (data.customer_name || data.name || data.full_name || '').trim();
      const phone = (data.phone || '').trim();

      if (!customerName) {
        throw AppError.badRequest('Customer name is required', [
          { field: 'customer_name', message: 'Customer name is required' },
        ]);
      }
      if (!phone) {
        throw AppError.badRequest('Phone number is required', [
          { field: 'phone', message: 'Phone number is required and must be valid' },
        ]);
      }

      // Check if customer with same phone already exists
      const { customers } = await customerRepository.findAll({ search: phone, limit: 1 });
      if (customers && customers.length > 0 && customers[0].phone === phone) {
        customerId = customers[0].id;
      } else {
        const createdCustomer = await customerService.createCustomer({
          full_name: customerName,
          phone,
          email: data.email || null,
          address: data.address || null,
          id_type: data.id_type || null,
          id_number: data.id_number || null,
          initial_amount_collected: data.initial_amount_collected || 0,
          notes: data.customer_notes || 'Created during loan origination',
        });
        customerId = createdCustomer.id;
      }
    } else {
      if (!UUID_REGEX.test(customerId)) {
        throw AppError.badRequest('Invalid customer ID format', null, 'INVALID_CUSTOMER_ID');
      }
      await customerService.getCustomerById(customerId);
    }

    // Run authoritative schedule and summary calculations
    const scheduled = this.previewLoan(data);
    const summary = scheduled.summary;

    const planCode = data.plan_code || (data.idempotency_key ? data.idempotency_key : `LN-${Date.now().toString().slice(-6)}`);
    const loanTitle = data.title || `${summary.frequency === 'weekly' ? 'Weekly' : 'Monthly'} Loan - ${planCode}`;

    // 1. Check for exact plan_code (idempotency key) replay
    const existingByCode = await loanRepository.findByPlanCode(planCode);
    if (existingByCode) {
      const existingInstallments = await installmentRepository.findByPlanId(existingByCode.id);
      return {
        loan: this._formatLoan(existingByCode),
        summary,
        installments: existingInstallments.map((item) => this._formatInstallment(item)),
        is_idempotent_replay: true,
      };
    }

    // 2. Prevent rapid double-tap duplicate submissions within 15 seconds
    const recentLoans = await loanRepository.findByCustomerId(customerId);
    const fifteenSecondsAgo = new Date(Date.now() - 15000);
    const recentDuplicate = recentLoans.find(
      (l) =>
        new Date(l.created_at) > fifteenSecondsAgo &&
        Number(l.total_amount) === Number(summary.totalRepayment) &&
        Number(l.total_installments) === Number(summary.totalInstallments) &&
        l.start_date === summary.startDate
    );
    if (recentDuplicate) {
      const existingInstallments = await installmentRepository.findByPlanId(recentDuplicate.id);
      return {
        loan: this._formatLoan(recentDuplicate),
        summary,
        installments: existingInstallments.map((item) => this._formatInstallment(item)),
        is_idempotent_replay: true,
      };
    }

    // Store metadata inside notes column
    const metadata = {
      monthly_interest_rate: summary.monthlyInterestRate,
      monthly_interest_amount: summary.monthlyInterest,
      total_interest: summary.totalInterest,
      duration_in_months: summary.durationInMonths,
      first_due_date: summary.firstDueDate,
      final_due_date: summary.finalDueDate,
      notes: data.notes || '',
    };

    let planRecord;
    try {
      // 3. Insert loan into payment_plans
      planRecord = await loanRepository.create({
        plan_code: planCode,
        customer_id: customerId,
        title: loanTitle,
        principal_amount: summary.principal,
        interest_rate: summary.monthlyInterestRate,
        total_amount: summary.totalRepayment,
        down_payment: data.down_payment || 0,
        total_installments: summary.totalInstallments,
        frequency: summary.frequency,
        start_date: summary.startDate,
        end_date: summary.finalDueDate,
        status: 'active',
        notes: JSON.stringify(metadata),
      });

      // 4. Prepare installments for bulk insert
      const installmentRows = scheduled.installments.map((inst) => ({
        plan_id: planRecord.id,
        customer_id: customerId,
        installment_number: inst.installment_number,
        due_date: inst.due_date,
        amount_due: inst.amount_due,
        amount_paid: 0,
        status: 'pending',
      }));

      // 5. Insert installments
      const savedInstallments = await installmentRepository.createMany(installmentRows);

      return {
        loan: this._formatLoan(planRecord),
        summary,
        installments: savedInstallments.map((item) => this._formatInstallment(item)),
      };
    } catch (err) {
      // Compensating rollback: delete orphaned loan if installment creation fails
      if (planRecord && planRecord.id) {
        try {
          await loanRepository.delete(planRecord.id);
          console.warn(`[Rollback] Orphaned loan ${planRecord.id} successfully rolled back.`);
        } catch (cleanupErr) {
          console.error(`[Rollback Error] Failed to delete orphaned loan ${planRecord.id}:`, cleanupErr.message);
        }
      }
      throw err;
    }
  }

  /**
   * List loans with search, status filtering, and pagination
   */
  async getLoans({ search, status, customerId, page = 1, limit = 10 }) {
    const parsedPage = Math.max(1, parseInt(page, 10) || 1);
    const parsedLimit = Math.min(100, Math.max(1, parseInt(limit, 10) || 10));
    const offset = (parsedPage - 1) * parsedLimit;

    if (customerId && !UUID_REGEX.test(customerId)) {
      throw AppError.badRequest('Invalid customer ID format', null, 'INVALID_CUSTOMER_ID');
    }

    const { loans, totalCount } = await loanRepository.findAll({
      search,
      status,
      customerId,
      offset,
      limit: parsedLimit,
    });

    // Enrich each loan with installment metrics
    const enrichedLoans = await Promise.all(
      loans.map(async (loan) => {
        const installments = await installmentRepository.findByPlanId(loan.id);
        return this._formatLoanWithMetrics(loan, installments);
      })
    );

    const totalPages = Math.ceil(totalCount / parsedLimit) || 1;

    return {
      loans: enrichedLoans,
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
   * Retrieve single loan details with financial summary and installments
   */
  async getLoanById(id) {
    if (!id || !UUID_REGEX.test(id)) {
      throw AppError.badRequest('Invalid loan ID format', null, 'INVALID_LOAN_ID');
    }

    const loan = await loanRepository.findById(id);
    if (!loan) {
      throw AppError.notFound(`Loan not found with ID ${id}`, 'LOAN_NOT_FOUND');
    }

    const installments = await installmentRepository.findByPlanId(id);
    const enrichedLoan = this._formatLoanWithMetrics(loan, installments);

    return {
      loan: enrichedLoan,
      installments: installments.map((item) => this._formatInstallment(item)),
    };
  }

  /**
   * Get all loans for a customer
   */
  async getLoansByCustomerId(customerId) {
    if (!customerId || !UUID_REGEX.test(customerId)) {
      throw AppError.badRequest('Invalid customer ID format', null, 'INVALID_CUSTOMER_ID');
    }

    const loans = await loanRepository.findByCustomerId(customerId);
    return Promise.all(
      loans.map(async (loan) => {
        const installments = await installmentRepository.findByPlanId(loan.id);
        return this._formatLoanWithMetrics(loan, installments);
      })
    );
  }

  /**
   * Update permitted loan details
   */
  async updateLoan(id, data) {
    if (!id || !UUID_REGEX.test(id)) {
      throw AppError.badRequest('Invalid loan ID format', null, 'INVALID_LOAN_ID');
    }

    const existing = await loanRepository.findById(id);
    if (!existing) {
      throw AppError.notFound(`Loan not found with ID ${id}`, 'LOAN_NOT_FOUND');
    }

    const updates = {};
    if (data.title !== undefined) updates.title = String(data.title).trim();
    if (data.status !== undefined) updates.status = String(data.status).toLowerCase();
    if (data.notes !== undefined) {
      let currentMeta = {};
      try {
        currentMeta = JSON.parse(existing.notes || '{}');
      } catch (_) {}
      currentMeta.notes = String(data.notes);
      updates.notes = JSON.stringify(currentMeta);
    }

    const updated = await loanRepository.update(id, updates);
    const installments = await installmentRepository.findByPlanId(id);
    return this._formatLoanWithMetrics(updated, installments);
  }

  _formatLoan(loan) {
    let meta = {};
    try {
      meta = JSON.parse(loan.notes || '{}');
    } catch (_) {}

    return {
      id: loan.id,
      plan_code: loan.plan_code,
      loan_code: loan.plan_code,
      customer_id: loan.customer_id,
      customer: loan.customers || null,
      customer_name: loan.customers ? loan.customers.full_name : null,
      title: loan.title,
      principal_amount: Number(loan.principal_amount) || 0,
      interest_rate: Number(loan.interest_rate) || 0,
      total_amount: Number(loan.total_amount) || 0,
      total_repayment: Number(loan.total_amount) || 0,
      total_interest: meta.total_interest || 0,
      monthly_interest_amount: meta.monthly_interest_amount || 0,
      duration_in_months: meta.duration_in_months || null,
      down_payment: Number(loan.down_payment) || 0,
      total_installments: loan.total_installments,
      frequency: loan.frequency,
      start_date: loan.start_date,
      end_date: loan.end_date,
      status: loan.status,
      notes: meta.notes || loan.notes || '',
      created_at: loan.created_at,
      updated_at: loan.updated_at,
    };
  }

  _formatLoanWithMetrics(loan, installments = []) {
    const base = this._formatLoan(loan);

    let totalCollected = 0;
    let paidCount = 0;
    let overdueCount = 0;
    let nextDueItem = null;

    const todayStr = new Date().toISOString().split('T')[0];

    for (const inst of installments) {
      const paid = Number(inst.amount_paid) || 0;
      const due = Number(inst.amount_due) || 0;
      totalCollected += paid;

      if (inst.status === 'paid' || paid >= due) {
        paidCount++;
      } else {
        if (inst.due_date && inst.due_date < todayStr) {
          overdueCount++;
        }
        if (!nextDueItem) {
          nextDueItem = inst;
        }
      }
    }

    totalCollected = Math.round(totalCollected * 100) / 100;
    const outstanding = Math.max(0, Math.round((base.total_repayment - totalCollected) * 100) / 100);
    const progress = base.total_repayment > 0
      ? Math.min(1.0, Math.round((totalCollected / base.total_repayment) * 1000) / 1000)
      : 0.0;

    return {
      ...base,
      amount_collected: totalCollected,
      total_collected: totalCollected,
      outstanding_balance: outstanding,
      progress,
      paid_installments_count: paidCount,
      overdue_installments_count: overdueCount,
      next_due_date: nextDueItem ? nextDueItem.due_date : null,
      next_due_amount: nextDueItem ? Number(nextDueItem.amount_due) - Number(nextDueItem.amount_paid || 0) : 0,
    };
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

    const isWeekly = item.payment_plans && item.payment_plans.frequency === 'weekly';
    const periodLabel = isWeekly
      ? `Week ${item.installment_number}`
      : `Month ${item.installment_number}`;

    return {
      id: item.id,
      plan_id: item.plan_id,
      customer_id: item.customer_id,
      customer: item.customers || null,
      customer_name: item.customers ? item.customers.full_name : null,
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

module.exports = new LoanService();
