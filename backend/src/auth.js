import jwt from 'jsonwebtoken';
import { AppError } from './errors.js';
import { USER_ID } from './ids.js';
import { parseName } from './validate.js';

const FALLBACK_NAME = 'Player';

/** Signs and verifies the HS256 session tokens: `{ sub: userId, name }`, valid for `tokenTtlSec`. */
export function createTokens({ jwtSecret, tokenTtlSec }) {
  return {
    sign(user) {
      return jwt.sign({ sub: user.id, name: user.name }, jwtSecret, {
        algorithm: 'HS256',
        expiresIn: tokenTtlSec,
      });
    },

    /** Returns `{ id, name }`, or `null` when the token is missing, forged, malformed or expired. */
    verify(token) {
      if (typeof token !== 'string' || token === '') return null;
      try {
        const claims = jwt.verify(token, jwtSecret, { algorithms: ['HS256'] });
        if (typeof claims.sub !== 'string' || !USER_ID.test(claims.sub)) return null;
        return { id: claims.sub, name: safeName(claims.name) };
      } catch {
        return null;
      }
    },
  };
}

/** The name stored in a token is only used to recreate a user the server has forgotten. */
function safeName(value) {
  try {
    return parseName(value);
  } catch {
    return FALLBACK_NAME;
  }
}

export function bearerToken(req) {
  const match = /^Bearer\s+(\S+)\s*$/i.exec(req.get('authorization') ?? '');
  return match ? match[1] : null;
}

/**
 * Express middleware: resolves the bearer token to a user and sets `req.user`.
 * A valid token for a user the server has forgotten (restart, idle sweep) recreates that user.
 */
export function createRequireAuth({ tokens, registry }) {
  return (req, res, next) => {
    const claims = tokens.verify(bearerToken(req));
    if (!claims) {
      next(new AppError('unauthorized', 'Please sign in again.'));
      return;
    }
    req.user = registry.ensureUser(claims.id, claims.name);
    registry.touch(req.user);
    next();
  };
}
