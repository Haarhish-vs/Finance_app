const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const env = require('../../config/env');
const authRepository = require('./repository');
const AppError = require('../../utils/api-error');

class AuthService {
  /**
   * Seeds the initial admin account from environment variables if not present.
   */
  async seedInitialAdmin() {
    const adminEmail = (env.ADMIN_EMAIL || 'ashokfinapp').trim();
    const adminPassword = (env.ADMIN_PASSWORD || 'ashokfinpass').trim();

    try {
      const existing = await authRepository.findByEmail(adminEmail);
      if (!existing) {
        const passwordHash = await bcrypt.hash(adminPassword, 10);
        const created = await authRepository.saveAdmin({
          email: adminEmail,
          password_hash: passwordHash,
          role: 'admin',
        });
        console.log(`[Admin Auth] Initial admin account '${adminEmail}' successfully seeded.`);
        return created;
      } else {
        // Ensure admin has valid password hash matching env if env was updated
        const matches = await bcrypt.compare(adminPassword, existing.password_hash);
        if (!matches) {
          const updatedHash = await bcrypt.hash(adminPassword, 10);
          await authRepository.saveAdmin({
            ...existing,
            password_hash: updatedHash,
          });
          console.log(`[Admin Auth] Admin credentials for '${adminEmail}' updated.`);
        }
        return existing;
      }
    } catch (err) {
      console.error('[Admin Auth] Error seeding initial admin:', err.message);
    }
  }

  /**
   * Authenticates admin with email/username and password.
   * Returns JWT token and sanitized admin profile.
   */
  async login({ email, password }) {
    const inputEmail = (email || '').trim();
    const inputPassword = (password || '').trim();

    if (!inputEmail || !inputPassword) {
      throw AppError.badRequest('Email/Username and password are required', [
        { field: 'email', message: 'Email/Username is required' },
        { field: 'password', message: 'Password is required' },
      ]);
    }

    // Ensure initial admin is seeded
    let admin = await authRepository.findByEmail(inputEmail);
    if (!admin) {
      // Lazy seed check if database wasn't ready at startup
      await this.seedInitialAdmin();
      admin = await authRepository.findByEmail(inputEmail);
    }

    if (!admin) {
      throw AppError.unauthorized('Invalid email or password', 'INVALID_CREDENTIALS');
    }

    const isMatch = await bcrypt.compare(inputPassword, admin.password_hash);
    if (!isMatch) {
      throw AppError.unauthorized('Invalid email or password', 'INVALID_CREDENTIALS');
    }

    // Sign JWT token
    const token = jwt.sign(
      {
        id: admin.id,
        email: admin.email,
        role: admin.role || 'admin',
      },
      env.JWT_SECRET,
      { expiresIn: env.JWT_EXPIRES_IN || '7d' }
    );

    return {
      token,
      admin: {
        id: admin.id,
        email: admin.email,
        role: admin.role || 'admin',
      },
    };
  }

  /**
   * Validates JWT token
   */
  verifyToken(token) {
    try {
      return jwt.verify(token, env.JWT_SECRET);
    } catch (err) {
      if (err.name === 'TokenExpiredError') {
        throw AppError.unauthorized('Session has expired. Please login again.', 'TOKEN_EXPIRED');
      }
      throw AppError.unauthorized('Invalid authentication token', 'INVALID_TOKEN');
    }
  }

  /**
   * Retrieves sanitized profile of current admin
   */
  async getCurrentAdmin(adminId) {
    const admin = await authRepository.findById(adminId);
    if (!admin) {
      throw AppError.notFound('Admin account not found', 'ADMIN_NOT_FOUND');
    }
    return {
      id: admin.id,
      email: admin.email,
      role: admin.role || 'admin',
    };
  }
}

module.exports = new AuthService();

