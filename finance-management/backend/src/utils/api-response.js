/**
 * Standardized API response utilities
 */

/**
 * Sends a successful JSON response
 * @param {import('express').Response} res
 * @param {any} data
 * @param {number} [statusCode=200]
 * @param {string|null} [message=null]
 * @param {object} [meta=null]
 */
function sendSuccess(res, data, statusCode = 200, message = null, meta = null) {
  const response = {
    success: true,
    ...(message && { message }),
    ...(data !== undefined && { data }),
    ...(meta && { meta }),
  };

  return res.status(statusCode).json(response);
}

/**
 * Sends an error JSON response
 * @param {import('express').Response} res
 * @param {string} message
 * @param {number} [statusCode=500]
 * @param {string} [code='INTERNAL_ERROR']
 * @param {any} [details=null]
 */
function sendError(res, message, statusCode = 500, code = 'INTERNAL_ERROR', details = null) {
  const response = {
    success: false,
    error: {
      message,
      code,
      ...(details && { details }),
    },
  };

  return res.status(statusCode).json(response);
}

module.exports = {
  sendSuccess,
  sendError,
};
