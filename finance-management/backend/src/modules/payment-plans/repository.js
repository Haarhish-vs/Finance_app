const { getSupabaseClient } = require('../../config/supabase');

/**
 * Repository for Loans / Payment Plans
 */
class LoanRepository {
  /**
   * Create a new loan record
   */
  async create(data) {
    const supabase = getSupabaseClient();
    const { data: created, error } = await supabase
      .from('payment_plans')
      .insert({
        plan_code: data.plan_code,
        customer_id: data.customer_id,
        title: data.title || 'Personal Loan',
        interest_rate: data.interest_rate,
        total_amount: data.total_amount,
        down_payment: data.down_payment || 0,
        total_installments: data.total_installments,
        frequency: data.frequency || 'monthly',
        start_date: data.start_date,
        end_date: data.end_date,
        status: data.status || 'active',
        notes: data.notes || null,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .select('*, customers(id, full_name, phone, email, status)')
      .single();

    if (error) throw error;
    return created;
  }

  /**
   * Find a loan by plan_code (used for idempotency)
   */
  async findByPlanCode(planCode) {
    const supabase = getSupabaseClient();
    const { data, error } = await supabase
      .from('payment_plans')
      .select('*, customers(id, full_name, phone, email, status)')
      .eq('plan_code', planCode)
      .maybeSingle();

    if (error) throw error;
    return data;
  }

  /**
   * Delete a loan record (used for compensating rollback)
   */
  async delete(id) {
    const supabase = getSupabaseClient();
    const { error } = await supabase
      .from('payment_plans')
      .delete()
      .eq('id', id);

    if (error) throw error;
    return true;
  }

  /**
   * Find a loan by UUID with customer and installments
   */
  async findById(id) {
    const supabase = getSupabaseClient();
    const { data, error } = await supabase
      .from('payment_plans')
      .select('*, customers(id, full_name, phone, email, address, status)')
      .eq('id', id)
      .maybeSingle();

    if (error) throw error;
    return data;
  }

  /**
   * Find all loans with search, status filtering, and pagination
   */
  async findAll({ search, status, customerId, offset = 0, limit = 10 }) {
    const supabase = getSupabaseClient();
    let query = supabase
      .from('payment_plans')
      .select('*, customers(id, full_name, phone, email, status)', { count: 'exact' });

    if (customerId) {
      query = query.eq('customer_id', customerId);
    }

    if (status && status !== 'all') {
      query = query.eq('status', status);
    }

    if (search) {
      query = query.or(`plan_code.ilike.%${search}%,title.ilike.%${search}%`);
    }

    query = query
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    const { data, error, count } = await query;
    if (error) throw error;

    return {
      loans: data || [],
      totalCount: count || 0,
    };
  }

  /**
   * Find loans for a specific customer
   */
  async findByCustomerId(customerId) {
    const supabase = getSupabaseClient();
    const { data, error } = await supabase
      .from('payment_plans')
      .select('*')
      .eq('customer_id', customerId)
      .order('created_at', { ascending: false });

    if (error) throw error;
    return data || [];
  }

  /**
   * Update loan details
   */
  async update(id, updates) {
    const supabase = getSupabaseClient();
    const { data, error } = await supabase
      .from('payment_plans')
      .update({
        ...updates,
        updated_at: new Date().toISOString(),
      })
      .eq('id', id)
      .select('*, customers(id, full_name, phone, email, status)')
      .single();

    if (error) throw error;
    return data;
  }
}

module.exports = new LoanRepository();
