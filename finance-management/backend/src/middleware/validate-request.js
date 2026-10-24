const AppError = require('../utils/api-error');

/**
 * Validates request data against specified rules or a validator function.
 * 
 * Example usage:
 * validateRequest({
 *   body: {
 *     email: { type: 'string', required: true, pattern: /^[^\s@]+@[^\s@]+\.[^\s@]+$/ },
 *     amount: { type: 'number', required: true, min: 0 }
 *   },
 *   params: {
 *     id: { type: 'uuid', required: true }
 *   }
 * })
 * 
 * Or with a function:
 * validateRequest((req) => {
 *   const errors = [];
 *   if (!req.body.title) errors.push({ field: 'title', message: 'Title is required' });
 *   return errors;
 * })
 */
function validateRequest(schemaOrFn) {
  return (req, res, next) => {
    // If a custom validator function is provided
    if (typeof schemaOrFn === 'function') {
      try {
        const errors = schemaOrFn(req);
        if (errors && errors.length > 0) {
          return next(
            AppError.badRequest('Validation failed', errors, 'VALIDATION_ERROR')
          );
        }
        return next();
      } catch (err) {
        return next(err);
      }
    }

    // Schema object validation
    if (typeof schemaOrFn === 'object' && schemaOrFn !== null) {
      const errors = [];
      const targets = ['body', 'query', 'params', 'headers'];

      for (const target of targets) {
        const targetRules = schemaOrFn[target];
        if (!targetRules) continue;

        const data = req[target] || {};

        for (const [field, rules] of Object.entries(targetRules)) {
          const value = data[field];

          // Check required
          if (rules.required && (value === undefined || value === null || value === '')) {
            errors.push({
              target,
              field,
              message: rules.message || `${field} is required`,
            });
            continue;
          }

          // If optional and not provided, skip further checks
          if (value === undefined || value === null || value === '') {
            continue;
          }

          // Check type
          if (rules.type) {
            const actualType = typeof value;
            if (rules.type === 'number') {
              if (isNaN(Number(value))) {
                errors.push({
                  target,
                  field,
                  message: `${field} must be a valid number`,
                });
              }
            } else if (rules.type === 'integer') {
              if (!Number.isInteger(Number(value))) {
                errors.push({
                  target,
                  field,
                  message: `${field} must be an integer`,
                });
              }
            } else if (rules.type === 'uuid') {
              const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
              if (typeof value !== 'string' || !uuidRegex.test(value)) {
                errors.push({
                  target,
                  field,
                  message: `${field} must be a valid UUID`,
                });
              }
            } else if (rules.type === 'date') {
              if (isNaN(Date.parse(value))) {
                errors.push({
                  target,
                  field,
                  message: `${field} must be a valid ISO date`,
                });
              }
            } else if (rules.type === 'array') {
              if (!Array.isArray(value)) {
                errors.push({
                  target,
                  field,
                  message: `${field} must be an array`,
                });
              }
            } else if (actualType !== rules.type) {
              errors.push({
                target,
                field,
                message: `${field} must be of type ${rules.type}`,
              });
            }
          }

          // Check min / max for numbers or length for strings/arrays
          if (rules.min !== undefined) {
            if (typeof value === 'number' && value < rules.min) {
              errors.push({
                target,
                field,
                message: `${field} cannot be less than ${rules.min}`,
              });
            } else if (
              (typeof value === 'string' || Array.isArray(value)) &&
              value.length < rules.min
            ) {
              errors.push({
                target,
                field,
                message: `${field} must have at least ${rules.min} characters/items`,
              });
            }
          }

          if (rules.max !== undefined) {
            if (typeof value === 'number' && value > rules.max) {
              errors.push({
                target,
                field,
                message: `${field} cannot be greater than ${rules.max}`,
              });
            } else if (
              (typeof value === 'string' || Array.isArray(value)) &&
              value.length > rules.max
            ) {
              errors.push({
                target,
                field,
                message: `${field} must have at most ${rules.max} characters/items`,
              });
            }
          }

          // Check enum
          if (Array.isArray(rules.enum) && !rules.enum.includes(value)) {
            errors.push({
              target,
              field,
              message: `${field} must be one of: ${rules.enum.join(', ')}`,
            });
          }

          // Check regex pattern
          if (rules.pattern instanceof RegExp && !rules.pattern.test(String(value))) {
            errors.push({
              target,
              field,
              message: rules.message || `${field} format is invalid`,
            });
          }

          // Custom validator function on the field
          if (typeof rules.custom === 'function') {
            const customResult = rules.custom(value, req);
            if (customResult !== true && customResult !== undefined) {
              errors.push({
                target,
                field,
                message:
                  typeof customResult === 'string'
                    ? customResult
                    : `${field} is invalid`,
              });
            }
          }
        }
      }

      if (errors.length > 0) {
        return next(
          AppError.badRequest('Validation failed', errors, 'VALIDATION_ERROR')
        );
      }
    }

    next();
  };
}

module.exports = {
  validateRequest,
};
