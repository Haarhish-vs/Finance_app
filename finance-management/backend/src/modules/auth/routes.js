const { Router } = require('express');
const authController = require('./controller');
const { authenticateAdmin } = require('../../middleware/auth');

const router = Router();

// Public login route
router.post('/login', authController.login);

// Protected routes
router.get('/me', authenticateAdmin, authController.getMe);
router.post('/logout', authenticateAdmin, authController.logout);

module.exports = router;

