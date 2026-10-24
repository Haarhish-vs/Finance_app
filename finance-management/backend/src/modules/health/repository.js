const { supabase } = require('../../config/supabase');

/**
 * Health repository responsible for database connectivity checks
 */
class HealthRepository {
  /**
   * Verifies database connectivity against an existing table (customers)
   * in a strictly read-only manner without modifying data.
   * 
   * @returns {Promise<{ connected: boolean, latencyMs: number, checkedTable: string, count?: number, error?: string }>}
   */
  async checkDatabaseConnection() {
    if (!supabase) {
      return {
        connected: false,
        latencyMs: 0,
        checkedTable: 'customers',
        error: 'Supabase client is not configured. SUPABASE_URL or SUPABASE_SECRET_KEY missing.',
      };
    }

    const start = Date.now();

    try {
      // Query the existing 'customers' table in read-only mode using head/count
      const { data, count, error } = await supabase
        .from('customers')
        .select('id', { count: 'exact', head: true });

      const latencyMs = Date.now() - start;

      if (error) {
        return {
          connected: false,
          latencyMs,
          checkedTable: 'customers',
          error: error.message,
        };
      }

      return {
        connected: true,
        latencyMs,
        checkedTable: 'customers',
        totalRecords: count ?? 0,
      };
    } catch (err) {
      const latencyMs = Date.now() - start;
      return {
        connected: false,
        latencyMs,
        checkedTable: 'customers',
        error: err.message || 'Database connection error',
      };
    }
  }
}

module.exports = new HealthRepository();
