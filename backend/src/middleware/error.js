import { logger } from '../config/logger.js';

export class ApiError extends Error {
  constructor(status, message, details) {
    super(message);
    this.status = status;
    this.details = details;
  }
}

// Wrap async route handlers so thrown/rejected errors reach Express' error path.
export const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);

// Translate common PostgreSQL SQLSTATE codes to HTTP statuses.
// https://www.postgresql.org/docs/current/errcodes-appendix.html
function mapPostgresError(err) {
  switch (err.code) {
    case '23505': // unique_violation
      if (err.constraint === 'uq_farmers_phone') {
        return new ApiError(409, 'Phone number already registered');
      }
      return new ApiError(409, 'Duplicate value violates a unique constraint');
    case '23503': // foreign_key_violation
      return new ApiError(400, 'Referenced record does not exist');
    case '23514': // check_violation
      return new ApiError(400, 'A value violates a check constraint');
    case '23502': // not_null_violation
      return new ApiError(400, 'A required value is missing');
    case '22P02': // invalid_text_representation (bad number/uuid/etc.)
    case '22003': // numeric_value_out_of_range
      return new ApiError(400, 'Invalid value for a field');
    default:
      return null;
  }
}

export function notFound(_req, _res, next) {
  next(new ApiError(404, 'Route not found'));
}

// Centralized error handler (must be registered last, with 4 args).
// eslint-disable-next-line no-unused-vars
export function errorHandler(err, req, res, _next) {
  let apiErr = err instanceof ApiError ? err : mapPostgresError(err);

  if (!apiErr) {
    apiErr = new ApiError(500, 'Internal server error');
    logger.error({ err }, 'Unhandled error');
  } else if (apiErr.status >= 500) {
    logger.error({ err }, 'Server error');
  }

  res.status(apiErr.status).json({
    error: {
      status: apiErr.status,
      message: apiErr.message,
      ...(apiErr.details ? { details: apiErr.details } : {}),
    },
  });
}
