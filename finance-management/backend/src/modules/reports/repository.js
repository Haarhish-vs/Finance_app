const { getSupabaseClient } = require('../../config/supabase');

class ReportsRepository {
  /**
   * Fetch all portfolio data for report generation with optional date range filter
   */
  async getReportData({ startDate, endDate }) {
    const supabase = getSupabaseClient();

    // 1. Fetch Customers
    let customerQuery = supabase
      .from('customers')
      .select('*')
      .order('created_at', { ascending: false });

    if (startDate) {
      customerQuery = customerQuery.gte('created_at', startDate);
    }
    if (endDate) {
      customerQuery = customerQuery.lte('created_at', endDate);
    }

    const { data: customers, error: cErr } = await customerQuery;
    if (cErr) throw cErr;

    // 2. Fetch Loans / Payment Plans
    let loanQuery = supabase
      .from('payment_plans')
      .select('*, customers(id, full_name, phone, email, status)')
      .order('created_at', { ascending: false });

    if (startDate) {
      loanQuery = loanQuery.gte('created_at', startDate);
    }
    if (endDate) {
      loanQuery = loanQuery.lte('created_at', endDate);
    }

    const { data: loans, error: lErr } = await loanQuery;
    if (lErr) throw lErr;

    // 3. Fetch Installments
    let instQuery = supabase
      .from('installments')
      .select('*, customers(id, full_name, phone), payment_plans(id, plan_code, title, frequency)')
      .order('due_date', { ascending: true });

    if (startDate) {
      instQuery = instQuery.gte('due_date', startDate.split('T')[0]);
    }
    if (endDate) {
      instQuery = instQuery.lte('due_date', endDate.split('T')[0]);
    }

    const { data: installments, error: iErr } = await instQuery;
    if (iErr) throw iErr;

    return {
      customers: customers || [],
      loans: loans || [],
      installments: installments || [],
    };
  }
}

module.exports = new ReportsRepository();
