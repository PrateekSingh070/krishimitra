import jwt from 'jsonwebtoken';
import jwksClient from 'jwks-rsa';
import { config } from '../config/index.js';
import { ApiError } from './error.js';

// JWKS client is created lazily only when a JWKS URI is configured (e.g. when
// verifying Supabase/Auth0-issued RS256 tokens). For local dev or a shared
// HS256 secret (Supabase JWT secret) we verify with config.auth.secret.
let jwks = null;
function getKey(header, callback) {
  if (!jwks) {
    jwks = jwksClient({ jwksUri: config.auth.jwksUri, cache: true, rateLimit: true });
  }
  jwks.getSigningKey(header.kid, (err, key) => {
    if (err) return callback(err);
    callback(null, key.getPublicKey());
  });
}

function verifyToken(token) {
  const options = {};
  if (config.auth.issuer) options.issuer = config.auth.issuer;
  if (config.auth.audience) options.audience = config.auth.audience;

  return new Promise((resolve, reject) => {
    if (config.auth.jwksUri) {
      jwt.verify(token, getKey, { algorithms: ['RS256'], ...options }, (err, decoded) =>
        err ? reject(err) : resolve(decoded),
      );
    } else {
      jwt.verify(token, config.auth.secret, options, (err, decoded) =>
        err ? reject(err) : resolve(decoded),
      );
    }
  });
}

// Authenticate every /api/v1 request. Bypassed entirely when AUTH_DISABLED=true
// (local development), in which case a synthetic admin identity is attached.
export async function authenticate(req, _res, next) {
  if (config.auth.disabled) {
    req.user = { sub: 'dev', roles: ['admin'] };
    return next();
  }

  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) {
    return next(new ApiError(401, 'Missing or malformed Authorization header'));
  }

  try {
    const decoded = await verifyToken(token);
    // Roles may live in a custom claim or Supabase's `role` / `app_metadata`.
    const roles =
      decoded.roles ||
      decoded['https://krishimitra/roles'] ||
      (decoded.app_metadata && decoded.app_metadata.roles) ||
      (decoded.role ? [decoded.role] : []);
    req.user = { sub: decoded.sub, roles: Array.isArray(roles) ? roles : [roles] };
    return next();
  } catch (err) {
    return next(new ApiError(401, 'Invalid or expired token'));
  }
}

// Require a role on the authenticated user (e.g. admin-only dispatch endpoint).
export function requireRole(role) {
  return (req, _res, next) => {
    if (config.auth.disabled) return next();
    const roles = (req.user && req.user.roles) || [];
    if (!roles.includes(role)) {
      return next(new ApiError(403, `Requires '${role}' role`));
    }
    return next();
  };
}
