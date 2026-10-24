const dotenv = require('dotenv');
const path = require('path');

// Ensure environment variables are loaded from the root backend .env
dotenv.config({ path: path.resolve(__dirname, '../../.env') });

const env = {
  PORT: parseInt(process.env.PORT, 10) || 5000,
  NODE_ENV: process.env.NODE_ENV || 'development',
  isDev: (process.env.NODE_ENV || 'development') === 'development',
  isProd: process.env.NODE_ENV === 'production',
  SUPABASE_URL: process.env.SUPABASE_URL || '',
  SUPABASE_SECRET_KEY: process.env.SUPABASE_SECRET_KEY || '',
};

// Validate presence of critical Supabase credentials without exposing them
if (!env.SUPABASE_URL || !env.SUPABASE_SECRET_KEY) {
  console.warn(
    '[Configuration Warning] Missing SUPABASE_URL or SUPABASE_SECRET_KEY in environment variables.'
  );
}

module.exports = env;
