const { getSupabaseClient } = require('../../config/supabase');

/**
 * Repository for Payment Transactions
 */
class PaymentRepository {
  /**
   * Record a payment receipt
   */
  async create(data) {
    const supabase = getSupabaseClient();
    const { data: created, error } = await supabase
      .from('payments')
      .insert({
        payment_reference: data.payment_reference,
        customer_id: data.customer_id,
        plan_id: data.plan_id,
        installment_id: data.installment_id,
        amount: data.amount,
        payment_date: data.payment_date || new Date().toISOString(),
        payment_method: data.payment_method || 'cash',
        notes: data.notes || null,
        receipt_url: data.receipt_url || null,
        created_at: new Date().toISOString(),
      })
      .select('*, customers(id, full_name, phone), payment_plans(id, plan_code, title)')
      .single();

    if (error) throw error;
    return created;
  }

  /**
   * List payments for a specific installment
   */
  async findByInstallmentId(installmentId) {
    const supabase = getSupabaseClient();
    const { data, error } = await supabase
      .from('payments')
      .select('*')
      .eq('installment_id', installmentId)
      .order('payment_date', { ascending: false });

    if (error) throw error;
    return data || [];
  }

  /**
   * List payments across the system with pagination
   */
  async findAll({ customerId, planId, offset = 0, limit = 20 }) {
    const supabase = getSupabaseClient();
    let query = supabase
      .from('payments')
      .select('*, customers(id, full_name, phone), payment_plans(id, plan_code, title)', { count: 'exact' });

    if (customerId) {
      query = query.eq('customer_id', customerId);
    }
    if (planId) {
      query = query.eq('plan_id', planId);
    }

    query = query
      .order('payment_date', { ascending: false })
      .range(offset, offset + limit - 1);

    const { data, error, count } = await query;
    if (error) throw error;

    return {
      payments: data || [],
      totalCount: count || 0,
    };
  }
}

module.exports = new PaymentRepository();
