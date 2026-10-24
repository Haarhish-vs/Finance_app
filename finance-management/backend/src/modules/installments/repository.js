const { getSupabaseClient } = require('../../config/supabase');

/**
 * Repository for Installments
 */
class InstallmentRepository {
  /**
   * Bulk insert installments for a loan
   */
  async createMany(installments) {
    const supabase = getSupabaseClient();
    const rows = installments.map((item) => ({
      plan_id: item.plan_id,
      customer_id: item.customer_id,
      installment_number: item.installment_number,
      due_date: item.due_date,
      amount_due: item.amount_due,
      amount_paid: item.amount_paid || 0,
      status: item.status || 'pending',
      paid_at: item.paid_at || null,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }));

    const { data, error } = await supabase
      .from('installments')
      .insert(rows)
      .select('*')
      .order('installment_number', { ascending: true });

    if (error) throw error;
    return data;
  }

  /**
   * Find all installments for a loan/plan
   */
  async findByPlanId(planId) {
    const supabase = getSupabaseClient();
    const { data, error } = await supabase
      .from('installments')
      .select('*, customers(id, full_name, phone)')
      .eq('plan_id', planId)
      .order('installment_number', { ascending: true });

    if (error) throw error;
    return data || [];
  }

  /**
   * Find all installments across the system with filtering and pagination
   */
  async findAll({ planId, customerId, status, offset = 0, limit = 50 }) {
    const supabase = getSupabaseClient();
    let query = supabase
      .from('installments')
      .select('*, customers(id, full_name, phone), payment_plans(id, plan_code, title, frequency)', { count: 'exact' });

    if (planId) {
      query = query.eq('plan_id', planId);
    }
    if (customerId) {
      query = query.eq('customer_id', customerId);
    }
    if (status && status !== 'all') {
      query = query.eq('status', status);
    }

    query = query
      .order('due_date', { ascending: true })
      .range(offset, offset + limit - 1);

    const { data, error, count } = await query;
    if (error) throw error;

    return {
      installments: data || [],
      totalCount: count || 0,
    };
  }

  /**
   * Find a single installment by ID
   */
  async findById(id) {
    const supabase = getSupabaseClient();
    const { data, error } = await supabase
      .from('installments')
      .select('*, customers(id, full_name, phone), payment_plans(id, plan_code, title, frequency, status)')
      .eq('id', id)
      .maybeSingle();

    if (error) throw error;
    return data;
  }

  /**
   * Update installment details
   */
  async update(id, updates) {
    const supabase = getSupabaseClient();
    const { data, error } = await supabase
      .from('installments')
      .update({
        ...updates,
        updated_at: new Date().toISOString(),
      })
      .eq('id', id)
      .select('*')
      .single();

    if (error) throw error;
    return data;
  }
}

module.exports = new InstallmentRepository();
