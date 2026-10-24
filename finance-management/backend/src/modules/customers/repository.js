const { getSupabaseClient } = require('../../config/supabase');

/**
 * Customer Repository interacting directly with Supabase PostgreSQL 'customers' table.
 */
class CustomerRepository {
  /**
   * Insert a new customer into the database
   */
  async create(customerData) {
    const supabase = getSupabaseClient();
    const { data, error } = await supabase
      .from('customers')
      .insert([customerData])
      .select()
      .single();

    if (error) throw error;
    return data;
  }

  /**
   * Find customers with search, status filtering, and range pagination
   */
  async findAll({ search, status, offset = 0, limit = 10 }) {
    const supabase = getSupabaseClient();

    let query = supabase
      .from('customers')
      .select('*', { count: 'exact' });

    // Optional status filter
    if (status && status !== 'all') {
      query = query.eq('status', status);
    }

    // Search filter across full_name, phone, email, and id_number
    if (search && search.trim()) {
      const cleanSearch = search.trim();
      query = query.or(
        `full_name.ilike.%${cleanSearch}%,phone.ilike.%${cleanSearch}%,email.ilike.%${cleanSearch}%,id_number.ilike.%${cleanSearch}%`
      );
    }

    query = query
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    const { data, count, error } = await query;
    if (error) throw error;

    return {
      customers: data || [],
      totalCount: count || 0,
    };
  }

  /**
   * Find a single customer by UUID
   */
  async findById(id) {
    const supabase = getSupabaseClient();
    const { data, error } = await supabase
      .from('customers')
      .select('*')
      .eq('id', id)
      .maybeSingle();

    if (error) throw error;
    return data;
  }

  /**
   * Update customer record by UUID
   */
  async update(id, updateData) {
    const supabase = getSupabaseClient();
    const { data, error } = await supabase
      .from('customers')
      .update({
        ...updateData,
        updated_at: new Date().toISOString(),
      })
      .eq('id', id)
      .select()
      .maybeSingle();

    if (error) throw error;
    return data;
  }

  /**
   * Update customer active status
   */
  async updateStatus(id, status) {
    const supabase = getSupabaseClient();
    const { data, error } = await supabase
      .from('customers')
      .update({
        status,
        updated_at: new Date().toISOString(),
      })
      .eq('id', id)
      .select()
      .maybeSingle();

    if (error) throw error;
    return data;
  }
}

module.exports = new CustomerRepository();
