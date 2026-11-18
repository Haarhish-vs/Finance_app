const { getSupabaseClient } = require('../../config/supabase');

/**
 * Admin repository handling persistence with Supabase `admins` table
 * and resilient local memory store fallback.
 */
class AuthRepository {
  constructor() {
    this._memoryAdmins = new Map();
    this._hasSupabaseTable = null; // null: unknown, true: table exists, false: fallback to memory
  }

  /**
   * Find admin by email/username (case-insensitive)
   */
  async findByEmail(email) {
    const normalizedEmail = (email || '').trim().toLowerCase();
    if (!normalizedEmail) return null;

    if (this._hasSupabaseTable !== false) {
      try {
        const supabase = getSupabaseClient();
        const { data, error } = await supabase
          .from('admins')
          .select('*')
          .ilike('email', normalizedEmail)
          .maybeSingle();

        if (!error) {
          this._hasSupabaseTable = true;
          return data;
        }

        // Check if table missing
        if (error.code === 'PGRST205' || error.message?.includes('schema cache') || error.message?.includes('not found')) {
          this._hasSupabaseTable = false;
        }
      } catch (err) {
        // Fall back to memory
        this._hasSupabaseTable = false;
      }
    }

    return this._memoryAdmins.get(normalizedEmail) || null;
  }

  /**
   * Find admin by id
   */
  async findById(id) {
    if (!id) return null;

    if (this._hasSupabaseTable !== false) {
      try {
        const supabase = getSupabaseClient();
        const { data, error } = await supabase
          .from('admins')
          .select('*')
          .eq('id', id)
          .maybeSingle();

        if (!error && data) {
          this._hasSupabaseTable = true;
          return data;
        }
      } catch (err) {
        // Ignore and fallback
      }
    }

    for (const admin of this._memoryAdmins.values()) {
      if (admin.id === id) return admin;
    }
    return null;
  }

  /**
   * Create or update admin
   */
  async saveAdmin(adminData) {
    const normalizedEmail = adminData.email.trim().toLowerCase();
    const record = {
      id: adminData.id || `admin-${Date.now()}`,
      email: normalizedEmail,
      password_hash: adminData.password_hash,
      role: adminData.role || 'admin',
      created_at: adminData.created_at || new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    if (this._hasSupabaseTable !== false) {
      try {
        const supabase = getSupabaseClient();
        const { data, error } = await supabase
          .from('admins')
          .upsert(record, { onConflict: 'email' })
          .select()
          .maybeSingle();

        if (!error && data) {
          this._hasSupabaseTable = true;
          this._memoryAdmins.set(normalizedEmail, data);
          return data;
        }

        if (error?.code === 'PGRST205' || error?.message?.includes('schema cache')) {
          this._hasSupabaseTable = false;
        }
      } catch (err) {
        this._hasSupabaseTable = false;
      }
    }

    this._memoryAdmins.set(normalizedEmail, record);
    return record;
  }
}

module.exports = new AuthRepository();

