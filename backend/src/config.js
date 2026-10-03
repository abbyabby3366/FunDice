import { randomBytes } from 'node:crypto';

const SECOND = 1000;
const MINUTE = 60 * SECOND;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;

/**
 * Defaults for every setting. The first block is configurable through environment variables
 * (SPEC 3.8); the rest is fixed by the spec and only overridden by tests.
 */
export const DEFAULTS = Object.freeze({
  nodeEnv: 'development',
  port: 3000,
  jwtSecret: undefined,
  mongodbUri: undefined,
  rollHistory: 5,
  diceCount: 5,
  peeksPerGame: 3,
  peekCaughtChance: 0.3,
  inviteTtlMs: MINUTE,
  disconnectGraceMs: MINUTE,

  tokenTtlSec: 30 * 24 * 60 * 60,
  grantTtlMs: 5 * MINUTE,
  rematchWindowMs: 10 * MINUTE,
  finishedGameTtlMs: 10 * MINUTE,
  resolvedInviteTtlMs: 5 * MINUTE,
  userIdleTtlMs: 6 * HOUR,
  sweepIntervalMs: MINUTE,
  authTimeoutMs: 5 * SECOND,
  pingIntervalMs: 25 * SECOND,
  maxSocketsPerUser: 5,
  maxPayloadBytes: 4096,
  lockout: Object.freeze({ maxMisses: 8, windowMs: 2 * MINUTE, durationMs: MINUTE }),
  limits: Object.freeze({
    global: Object.freeze({ windowMs: 5 * MINUTE, limit: 300 }),
    register: Object.freeze({ windowMs: 60 * MINUTE, limit: 10 }),
    roll: Object.freeze({ windowMs: MINUTE, limit: 60 }),
    match: Object.freeze({ windowMs: MINUTE, limit: 30 }),
    invite: Object.freeze({ windowMs: MINUTE, limit: 30 }),
    game: Object.freeze({ windowMs: MINUTE, limit: 120 }),
  }),
});

/** Fills in defaults for anything `overrides` leaves out. Used directly by tests. */
export function resolveConfig(overrides = {}) {
  const limits = Object.fromEntries(
    Object.entries(DEFAULTS.limits).map(([name, defaults]) => [
      name,
      { ...defaults, ...overrides.limits?.[name] },
    ]),
  );
  return {
    ...DEFAULTS,
    ...overrides,
    lockout: { ...DEFAULTS.lockout, ...overrides.lockout },
    limits,
    jwtSecret: overrides.jwtSecret ?? randomBytes(32).toString('hex'),
  };
}

function readNumber(env, key, { min, max, integer = true }) {
  const raw = env[key]?.trim();
  if (!raw) return undefined;
  const value = Number(raw);
  if (!Number.isFinite(value) || (integer && !Number.isInteger(value)) || value < min || value > max) {
    throw new Error(`${key} must be ${integer ? 'an integer' : 'a number'} between ${min} and ${max}, got "${raw}".`);
  }
  return value;
}

/** Reads the environment (SPEC 3.8) and returns a complete, validated config. */
export function loadConfig(env = process.env, logger = console) {
  const nodeEnv = env.NODE_ENV?.trim() || DEFAULTS.nodeEnv;
  const jwtSecret = env.JWT_SECRET?.trim() || undefined;
  if (!jwtSecret) {
    if (nodeEnv === 'production') throw new Error('JWT_SECRET is required when NODE_ENV=production.');
    logger.warn('JWT_SECRET is not set: using a random secret for this run, so sign-ins will not survive a restart.');
  }

  const fromEnv = {
    port: readNumber(env, 'PORT', { min: 0, max: 65535 }),
    rollHistory: readNumber(env, 'ROLL_HISTORY', { min: 1, max: 50 }),
    diceCount: readNumber(env, 'DICE_COUNT', { min: 1, max: 10 }),
    peeksPerGame: readNumber(env, 'PEEKS_PER_GAME', { min: 0, max: 20 }),
    peekCaughtChance: readNumber(env, 'PEEK_CAUGHT_CHANCE', { min: 0, max: 1, integer: false }),
    inviteTtlMs: readNumber(env, 'INVITE_TTL_MS', { min: 1, max: DAY }),
    disconnectGraceMs: readNumber(env, 'DISCONNECT_GRACE_MS', { min: 1, max: DAY }),
  };
  const defined = Object.fromEntries(Object.entries(fromEnv).filter(([, value]) => value !== undefined));
  const mongodbUri = env.MONGODB_URI?.trim() || undefined;
  return resolveConfig({ ...defined, nodeEnv, jwtSecret, mongodbUri });
}
