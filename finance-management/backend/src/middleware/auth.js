const authService = require('../modules/auth/service');
const AppError = require('../utils/api-error');

/**
 * Authentication middleware to protect admin routes
 */
function authenticateAdmin(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw AppError.unauthorized('Authentication required. Missing Bearer token.', 'AUTH_REQUIRED');
    }

    const token = authHeader.split(' ')[1]?.trim();
    if (!token) {
      throw AppError.unauthorized('Authentication token is empty.', 'INVALID_TOKEN');
    }

    const decoded = authService.verifyToken(token);
    req.admin = decoded;
    next();
  } catch (err) {
    next(err);
  }
}

module.exports = {
  authenticateAdmin,
};

