const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const apiRouter = require('./routes');
const { errorHandler, notFoundHandler } = require('./middleware/error-handler');

const app = express();

// Security middleware
app.use(helmet());

// CORS configuration
app.use(cors());

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Root welcome route
app.get('/', (req, res) => {
  res.status(200).json({
    name: 'Finance Management Backend API',
    version: '1.0.0',
    documentation: '/api/v1/health',
    endpoints: {
      health: '/api/v1/health',
      dbHealth: '/api/v1/health/db',
    },
  });
});

// Root /health convenience alias (maps to /api/v1/health)
app.get('/health', (req, res, next) => {
  req.url = '/health';
  apiRouter(req, res, next);
});

// Mount modular API v1 routes
app.use('/api/v1', apiRouter);

// 404 handler for unmatched routes
app.use(notFoundHandler);

// Centralized error handling middleware
app.use(errorHandler);

module.exports = app;
