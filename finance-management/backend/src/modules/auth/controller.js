const authService = require('./service');
const { sendSuccess } = require('../../utils/api-response');

class AuthController {
  /**
   * POST /api/v1/auth/login
   */
  login = async (req, res, next) => {
    try {
      const result = await authService.login(req.body);
      return sendSuccess(res, result, 200, 'Login successful');
    } catch (err) {
      next(err);
    }
  };

  /**
   * GET /api/v1/auth/me
   */
  getMe = async (req, res, next) => {
    try {
      const admin = await authService.getCurrentAdmin(req.admin.id);
      return sendSuccess(res, admin, 200, 'Profile retrieved successfully');
    } catch (err) {
      next(err);
    }
  };

  /**
   * POST /api/v1/auth/logout
   */
  logout = async (req, res, next) => {
    try {
      return sendSuccess(res, { logged_out: true }, 200, 'Logout successful');
    } catch (err) {
      next(err);
    }
  };
}

module.exports = new AuthController();

