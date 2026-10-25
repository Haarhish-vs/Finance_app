const reportsRepo = require('./repository');

class ReportsService {
  /**
   * Parse range slug into start and end Date objects
   */
  resolveDateRange(range) {
    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth(); // 0-indexed

    let startDate = null;
    let endDate = null;
    let label = 'All Time';

    switch ((range || '').toLowerCase().replace(/[\s-]/g, '_')) {
      case 'this_month':
      case 'thismonth':
        startDate = new Date(year, month, 1, 0, 0, 0);
        endDate = new Date(year, month + 1, 0, 23, 59, 59, 999);
        label = `This Month (${startDate.toISOString().slice(0, 7)})`;
        break;

      case 'last_month':
      case 'lastmonth':
        startDate = new Date(year, month - 1, 1, 0, 0, 0);
        endDate = new Date(year, month, 0, 23, 59, 59, 999);
        label = `Last Month (${startDate.toISOString().slice(0, 7)})`;
        break;

      case 'this_quarter':
      case 'thisquarter': {
        const quarter = Math.floor(month / 3);
        startDate = new Date(year, quarter * 3, 1, 0, 0, 0);
        endDate = new Date(year, (quarter + 1) * 3, 0, 23, 59, 59, 999);
        label = `This Quarter (Q${quarter + 1} ${year})`;
        break;
      }

      case 'year_to_date':
      case 'yeartodate':
      case 'ytd':
        startDate = new Date(year, 0, 1, 0, 0, 0);
        endDate = now;
        label = `Year to Date (${year})`;
        break;

      case 'all_time':
      case 'alltime':
      default:
        startDate = null;
        endDate = null;
        label = 'All Time Portfolio History';
        break;
    }

    return {
      startDate: startDate ? startDate.toISOString() : null,
      endDate: endDate ? endDate.toISOString() : null,
      label,
    };
  }

  /**
   * Escape and wrap value for CSV output
   */
  csvEscape(val) {
    if (val === null || val === undefined) return '';
    const str = String(val);
    if (str.includes(',') || str.includes('"') || str.includes('\n') || str.includes('\r')) {
      return `"${str.replace(/"/g, '""')}"`;
    }
    return str;
  }

  /**
   * Generate report summary and CSV
   */
  async getReport({ range }) {
    const { startDate, endDate, label } = this.resolveDateRange(range);
    const data = await reportsRepo.getReportData({ startDate, endDate });

    let totalPrincipalDisbursed = 0;
    let totalRepaymentExpected = 0;
    let totalInstallmentsCollected = 0;

    data.loans.forEach((l) => {
      totalPrincipalDisbursed += Number(l.principal_amount || l.total_amount || 0);
      totalRepaymentExpected += Number(l.total_amount || 0);
    });

    data.installments.forEach((i) => {
      totalInstallmentsCollected += Number(i.amount_paid || 0);
    });

    let totalInitialCollected = 0;
    let activeCustomers = 0;
    data.customers.forEach((c) => {
      if (c.notes) {
        try {
          const parsed = typeof c.notes === 'string' ? JSON.parse(c.notes) : c.notes;
          totalInitialCollected += Number(parsed.initial_amount_collected || 0);
        } catch (_) {}
      }
      if (c.status === 'active') activeCustomers++;
    });

    const totalCollected = totalInitialCollected + totalInstallmentsCollected;
    const outstandingPrincipal = Math.max(0, totalPrincipalDisbursed - totalInstallmentsCollected);

    return {
      range: label,
      startDate,
      endDate,
      metrics: {
        totalCustomers: data.customers.length,
        activeCustomers,
        totalLoans: data.loans.length,
        totalPrincipalDisbursed,
        totalRepaymentExpected,
        totalCollected,
        outstandingPrincipal,
        totalInstallments: data.installments.length,
      },
      customers: data.customers,
      loans: data.loans,
      installments: data.installments,
    };
  }

  /**
   * Build complete CSV string
   */
  async generateCsv({ range }) {
    const report = await this.getReport({ range });
    const lines = [];

    // Header info
    lines.push('# ==============================================================================');
    lines.push('# FINANCE MANAGEMENT SYSTEM - PORTFOLIO FINANCIAL REPORT');
    lines.push(`# Filter Range: ${this.csvEscape(report.range)}`);
    lines.push(`# Generated At: ${this.csvEscape(new Date().toISOString())}`);
    lines.push('# Currency: INR (₹)');
    lines.push('# ==============================================================================');
    lines.push('');

    // Summary section
    lines.push('# --- EXECUTIVE SUMMARY ---');
    lines.push('Metric,Value');
    lines.push(`Selected Date Range,${this.csvEscape(report.range)}`);
    lines.push(`Total Registered Borrowers,${report.metrics.totalCustomers}`);
    lines.push(`Active Borrowers,${report.metrics.activeCustomers}`);
    lines.push(`Total Originated Loans,${report.metrics.totalLoans}`);
    lines.push(`Total Principal Disbursed (₹),${report.metrics.totalPrincipalDisbursed.toFixed(2)}`);
    lines.push(`Total Collections Received (₹),${report.metrics.totalCollected.toFixed(2)}`);
    lines.push(`Outstanding Principal (₹),${report.metrics.outstandingPrincipal.toFixed(2)}`);
    lines.push('');

    // Section 1: Customers
    lines.push('# --- 1. BORROWER DIRECTORY ---');
    lines.push('Customer ID,Full Name,Phone Number,Email,Status,Registration Date');
    report.customers.forEach((c) => {
      lines.push([
        this.csvEscape(c.id),
        this.csvEscape(c.full_name),
        this.csvEscape(c.phone || 'N/A'),
        this.csvEscape(c.email || 'N/A'),
        this.csvEscape(c.status),
        this.csvEscape(c.created_at ? c.created_at.slice(0, 10) : ''),
      ].join(','));
    });
    lines.push('');

    // Section 2: Loans
    lines.push('# --- 2. LOANS & PAYMENT PLANS ---');
    lines.push('Plan Code,Borrower Name,Phone,Principal Amount (₹),Interest Rate (%),Frequency,Tenure,Total Repayment (₹),Status,Start Date,End Date');
    report.loans.forEach((l) => {
      const cust = l.customers || {};
      lines.push([
        this.csvEscape(l.plan_code),
        this.csvEscape(cust.full_name || 'N/A'),
        this.csvEscape(cust.phone || 'N/A'),
        Number(l.principal_amount || l.total_amount || 0).toFixed(2),
        Number(l.interest_rate || 0).toFixed(1),
        this.csvEscape(l.frequency || 'monthly'),
        `${l.total_installments} ${l.frequency === 'weekly' ? 'Weeks' : 'Months'}`,
        Number(l.total_amount || 0).toFixed(2),
        this.csvEscape(l.status),
        this.csvEscape(l.start_date || ''),
        this.csvEscape(l.end_date || ''),
      ].join(','));
    });
    lines.push('');

    // Section 3: Installments
    lines.push('# --- 3. RECOVERY & INSTALLMENT SCHEDULE ---');
    lines.push('Plan Code,Borrower Name,Installment Number,Due Date,Amount Due (₹),Amount Paid (₹),Status,Paid Date');
    report.installments.forEach((i) => {
      const cust = i.customers || {};
      const plan = i.payment_plans || {};
      lines.push([
        this.csvEscape(plan.plan_code || 'N/A'),
        this.csvEscape(cust.full_name || 'N/A'),
        i.installment_number,
        this.csvEscape(i.due_date || ''),
        Number(i.amount_due || 0).toFixed(2),
        Number(i.amount_paid || 0).toFixed(2),
        this.csvEscape(i.status),
        this.csvEscape(i.paid_at ? i.paid_at.slice(0, 10) : '-'),
      ].join(','));
    });

    return lines.join('\r\n');
  }
}

module.exports = new ReportsService();
