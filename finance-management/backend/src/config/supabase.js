const { createClient } = require('@supabase/supabase-js');
const env = require('./env');

let supabaseInstance = null;

if (env.SUPABASE_URL && env.SUPABASE_SECRET_KEY) {
  supabaseInstance = createClient(env.SUPABASE_URL, env.SUPABASE_SECRET_KEY, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}

/**
 * Returns the Supabase client instance or throws if not configured.
 */
function getSupabaseClient() {
  if (!supabaseInstance) {
    throw new Error(
      'Supabase client is not initialized. Please ensure SUPABASE_URL and SUPABASE_SECRET_KEY are set.'
    );
  }
  return supabaseInstance;
}

module.exports = {
  supabase: supabaseInstance,
  getSupabaseClient,
};
