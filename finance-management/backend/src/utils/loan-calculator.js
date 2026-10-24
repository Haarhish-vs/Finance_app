/**
 * Loan Calculator Utility
 * Implements simple interest monetary calculations, weekly-to-monthly duration conversion,
 * date progression with month-end and leap-year safety, and final-installment rounding reconciliation.
 */

// Documented convention: 52 weeks = 12 months in a standard calendar year
const WEEKS_PER_YEAR = 52;
const MONTHS_PER_YEAR = 12;

/**
 * Converts weekly duration into months using the standard calendar convention:
 * durationInMonths = durationInWeeks * (12 / 52)
 */
function weeksToMonths(weeks) {
  return Number(((weeks * MONTHS_PER_YEAR) / WEEKS_PER_YEAR).toFixed(6));
}

/**
 * Rounds a number to exactly two decimal places (paise precision)
 */
function roundToTwo(num) {
  return Math.round((Number(num) + Number.EPSILON) * 100) / 100;
}

/**
 * Computes simple interest and loan summary
 */
function calculateLoanSummary({
  principal,
  interestRate,
  frequency = 'monthly',
  totalInstallments,
  startDate,
  firstDueDate,
}) {
  const p = roundToTwo(principal);
  const r = Number(interestRate); // Monthly interest percentage (e.g. 5 for 5%)
  const n = parseInt(totalInstallments, 10);

  if (isNaN(p) || p <= 0) {
    throw new Error('Principal amount must be a positive number');
  }
  if (isNaN(r) || r < 0) {
    throw new Error('Interest rate must be a non-negative number');
  }
  if (isNaN(n) || n <= 0) {
    throw new Error('Total installments must be a positive integer');
  }

  const isWeekly = String(frequency).toLowerCase() === 'weekly';
  const durationInMonths = isWeekly ? weeksToMonths(n) : n;

  // Simple Interest: Total Interest = Principal * (Monthly Rate / 100) * Duration in Months
  const monthlyInterest = roundToTwo(p * (r / 100));
  const totalInterest = roundToTwo(p * (r / 100) * durationInMonths);
  const totalRepayment = roundToTwo(p + totalInterest);

  // Installment calculation with 2 decimal precision
  const baseInstallment = Math.floor((totalRepayment / n) * 100) / 100;
  const roundingDiff = roundToTwo(totalRepayment - (baseInstallment * n));

  const start = startDate ? new Date(startDate) : new Date();
  const firstDue = firstDueDate ? new Date(firstDueDate) : computeDefaultFirstDueDate(start, isWeekly);

  // Compute final due date
  const finalDueDate = isWeekly
    ? computeWeeklyDate(firstDue, n - 1)
    : computeMonthlyDate(firstDue, n - 1);

  return {
    principal: p,
    monthlyInterestRate: r,
    frequency: isWeekly ? 'weekly' : 'monthly',
    totalInstallments: n,
    durationInMonths: roundToTwo(durationInMonths),
    monthlyInterest,
    totalInterest,
    totalRepayment,
    baseInstallment,
    finalInstallmentAdjustment: roundingDiff,
    regularInstallmentAmount: roundToTwo(baseInstallment + (roundingDiff === 0 ? 0 : 0)),
    startDate: start.toISOString().split('T')[0],
    firstDueDate: firstDue.toISOString().split('T')[0],
    finalDueDate,
  };
}

/**
 * Computes default first due date (1 week or 1 month after start date)
 */
function computeDefaultFirstDueDate(startDate, isWeekly) {
  const d = new Date(startDate);
  if (isWeekly) {
    d.setUTCDate(d.getUTCDate() + 7);
  } else {
    return new Date(computeMonthlyDate(d, 1));
  }
  return d;
}

/**
 * Computes weekly date with week offset
 */
function computeWeeklyDate(baseDate, weekOffset) {
  const d = new Date(baseDate);
  d.setUTCDate(d.getUTCDate() + (weekOffset * 7));
  return d.toISOString().split('T')[0];
}

/**
 * Computes monthly date with month offset, preserving month-end dates and leap years
 */
function computeMonthlyDate(baseDate, monthOffset, anchorDay = null) {
  const original = new Date(baseDate);
  const targetYear = original.getUTCFullYear();
  const targetMonth = original.getUTCMonth() + monthOffset;
  const dayToUse = anchorDay || original.getUTCDate();

  // Create date at 1st of target month
  const target = new Date(Date.UTC(targetYear, targetMonth, 1));

  // Determine last day of the target month
  const lastDay = new Date(Date.UTC(target.getUTCFullYear(), target.getUTCMonth() + 1, 0)).getUTCDate();

  // Preserve day or clamp to month-end (e.g. Jan 31 -> Feb 28/29, Mar 31 -> Apr 30)
  const safeDay = Math.min(dayToUse, lastDay);
  target.setUTCDate(safeDay);

  return target.toISOString().split('T')[0];
}

/**
 * Generates the full installment schedule.
 * Accepts optional custom overrides if the admin manually modified individual due dates/amounts.
 */
function generateSchedule({
  principal,
  interestRate,
  frequency = 'monthly',
  totalInstallments,
  startDate,
  firstDueDate,
  customInstallments = null,
}) {
  const summary = calculateLoanSummary({
    principal,
    interestRate,
    frequency,
    totalInstallments,
    startDate,
    firstDueDate,
  });

  const isWeekly = summary.frequency === 'weekly';
  const firstDue = new Date(summary.firstDueDate);
  const anchorDay = firstDue.getUTCDate();
  const installments = [];

  let accumulatedDue = 0;

  for (let i = 1; i <= summary.totalInstallments; i++) {
    // If custom installment override provided by admin
    const custom = Array.isArray(customInstallments)
      ? customInstallments.find((ci) => Number(ci.installment_number) === i)
      : null;

    let dueDate;
    if (custom && custom.due_date) {
      dueDate = custom.due_date;
    } else {
      dueDate = isWeekly
        ? computeWeeklyDate(firstDue, i - 1)
        : computeMonthlyDate(firstDue, i - 1, anchorDay);
    }

    let amountDue;
    if (custom && custom.amount_due !== undefined && custom.amount_due !== null) {
      amountDue = roundToTwo(custom.amount_due);
    } else if (i === summary.totalInstallments) {
      // Reconcile final installment with remaining balance
      amountDue = roundToTwo(summary.totalRepayment - accumulatedDue);
    } else {
      amountDue = summary.baseInstallment;
    }

    accumulatedDue = roundToTwo(accumulatedDue + amountDue);

    const periodLabel = isWeekly ? `Week ${i}` : `Month ${i}`;

    installments.push({
      installment_number: i,
      period_label: periodLabel,
      due_date: dueDate,
      amount_due: amountDue,
      amount_paid: 0,
      outstanding_balance: amountDue,
      status: 'pending',
    });
  }

  return {
    summary: {
      ...summary,
      totalScheduledAmount: accumulatedDue,
      isReconciled: roundToTwo(accumulatedDue) === roundToTwo(summary.totalRepayment),
    },
    installments,
  };
}

module.exports = {
  WEEKS_PER_YEAR,
  MONTHS_PER_YEAR,
  weeksToMonths,
  roundToTwo,
  calculateLoanSummary,
  generateSchedule,
  computeWeeklyDate,
  computeMonthlyDate,
};
