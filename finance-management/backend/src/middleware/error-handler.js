const AppError = require('../utils/api-error');
const env = require('../config/env');

/**
 * 404 Not Found Middleware for handling unmatched routes
 */
function notFoundHandler(req, res, next) {
  next(
    AppError.notFound(
      `Route ${req.method} ${req.originalUrl} not found`,
      'ROUTE_NOT_FOUND'
    )
  );
}

/**
 * Centralized error-handling middleware
 */
function errorHandler(err, req, res, next) {
  let error = err;

  // Handle express JSON body parser syntax errors
  if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
    error = AppError.badRequest('Malformed JSON in request body', null, 'INVALID_JSON');
  }

  // Fallback for unhandled non-AppError exceptions
  if (!(error instanceof AppError)) {
    const statusCode = error.statusCode || error.status || 500;
    const message = error.message || 'An unexpected internal error occurred';
    error = new AppError(
      message,
      statusCode,
      error.code || 'INTERNAL_ERROR',
      error.details || null
    );
    error.isOperational = false;
  }

  // Log server errors (avoid logging in tests if needed, never log secrets)
  if (!error.isOperational || error.statusCode >= 500) {
    console.error(`[Server Error] ${req.method} ${req.originalUrl}:`, {
      message: error.message,
      code: error.code,
      stack: env.isDev ? error.stack : undefined,
    });
  }

  const response = {
    success: false,
    error: {
      message:
        !error.isOperational && env.isProd
          ? 'Internal server error'
          : error.message,
      code: error.code || 'ERROR',
      ...(error.details && { details: error.details }),
      ...(env.isDev && error.stack && { stack: error.stack }),
    },
  };

  res.status(error.statusCode || 500).json(response);
}

module.exports = {
  notFoundHandler,
  errorHandler,
};
