import { ApiError } from './error.js';

// Validate a request part (body/params/query) against a Zod schema and replace
// it with the parsed/coerced result.
export const validate = (schema, part = 'body') => (req, _res, next) => {
  const result = schema.safeParse(req[part]);
  if (!result.success) {
    const details = result.error.issues.map((i) => ({
      path: i.path.join('.'),
      message: i.message,
    }));
    return next(new ApiError(400, 'Validation failed', details));
  }
  req[part] = result.data;
  return next();
};
