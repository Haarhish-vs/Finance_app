const { getSupabaseClient } = require('../../config/supabase');
const AppError = require('../../utils/api-error');

const WEEKDAY_NAMES = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

class DashboardService {
  /**
   * Retrieves weekly collections grouped by weekday (Monday through Sunday)
   * for the specified target week.
   */
  async getWeeklyCollections({ weekDate, weekStart, weekEnd }) {
    const supabase = getSupabaseClient();

    // Determine week boundaries (Monday to Sunday)
    let startDate;
    let endDate;

    if (weekStart && weekEnd) {
      startDate = new Date(weekStart);
      endDate = new Date(weekEnd);
    } else {
      const anchor = weekDate ? new Date(weekDate) : new Date();
      if (isNaN(anchor.getTime())) {
        throw AppError.badRequest('Invalid week_date provided');
      }

      // In JS, 0=Sunday, 1=Monday, ..., 6=Saturday
      const day = anchor.getUTCDay();
      // Distance to Monday: if Sunday (0), distance is -6 days; otherwise 1 - day
      const diffToMonday = day === 0 ? -6 : 1 - day;

      startDate = new Date(anchor);
      startDate.setUTCDate(anchor.getUTCDate() + diffToMonday);

      endDate = new Date(startDate);
      endDate.setUTCDate(startDate.getUTCDate() + 6);
    }

    const startIso = startDate.toISOString().split('T')[0];
    const endIso = endDate.toISOString().split('T')[0];
    const todayIso = new Date().toISOString().split('T')[0];

    // Query actual installments due in this week range
    const { data: rows, error } = await supabase
      .from('installments')
      .select(`
        id,
        installment_number,
        due_date,
        amount_due,
        amount_paid,
        status,
        paid_at,
        customers (
          id,
          full_name,
          phone,
          status
        ),
        payment_plans (
          id,
          plan_code,
          title,
          frequency,
          notes
        )
      `)
      .gte('due_date', startIso)
      .lte('due_date', endIso)
      .order('due_date', { ascending: true });

    if (error) {
      throw AppError.internal('Failed to retrieve installment records: ' + error.message);
    }

    // Filter to weekly frequency payment plans
    const weeklyInstallments = (rows || []).filter((inst) => {
      const freq = inst.payment_plans?.frequency?.toLowerCase();
      return freq === 'weekly';
    });

    // Build standard Monday -> Sunday 7-day schedule map
    const weekdaysOrder = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const daysBreakdown = [];

    let totalWeeklyCustomers = 0;
    let totalWeeklyAmountDue = 0;
    let totalWeeklyCollected = 0;

    for (let i = 0; i < 7; i++) {
      const dayDate = new Date(startDate);
      dayDate.setUTCDate(startDate.getUTCDate() + i);
      const dateStr = dayDate.toISOString().split('T')[0];
      const weekdayName = weekdaysOrder[i];

      // Match installments due on this specific date
      const dayInstallments = weeklyInstallments.filter((inst) => inst.due_date === dateStr);

      let dayTotalDue = 0;
      let dayTotalCollected = 0;

      const items = dayInstallments.map((inst) => {
        const due = Number(inst.amount_due) || 0;
        const paid = Number(inst.amount_paid) || 0;
        const outstanding = Math.max(0, Math.round((due - paid) * 100) / 100);

        dayTotalDue += due;
        dayTotalCollected += paid;

        let status = 'pending';
        if (paid >= due && due > 0) {
          status = 'paid';
        } else if (inst.due_date && inst.due_date < todayIso) {
          status = 'overdue';
        }

        return {
          installment_id: inst.id,
          customer_id: inst.customers?.id || null,
          customer_name: inst.customers?.full_name || 'Borrower',
          phone_number: inst.customers?.phone || 'N/A',
          installment_amount: due,
          amount_paid: paid,
          outstanding_balance: outstanding,
          due_date: inst.due_date,
          status,
          plan_code: inst.payment_plans?.plan_code || '',
          installment_number: inst.installment_number,
        };
      });

      dayTotalDue = Math.round(dayTotalDue * 100) / 100;
      dayTotalCollected = Math.round(dayTotalCollected * 100) / 100;

      totalWeeklyCustomers += items.length;
      totalWeeklyAmountDue += dayTotalDue;
      totalWeeklyCollected += dayTotalCollected;

      daysBreakdown.push({
        weekday: weekdayName,
        date: dateStr,
        customer_count: items.length,
        total_due: dayTotalDue,
        total_collected: dayTotalCollected,
        items,
      });
    }

    return {
      week_start: startIso,
      week_end: endIso,
      total_weekly_customers: totalWeeklyCustomers,
      total_weekly_amount_due: Math.round(totalWeeklyAmountDue * 100) / 100,
      total_weekly_collected: Math.round(totalWeeklyCollected * 100) / 100,
      weekdays: daysBreakdown,
    };
  }
}

module.exports = new DashboardService();
