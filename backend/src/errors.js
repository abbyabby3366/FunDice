/** HTTP status for every error code in SPEC 3.1 (plus `not_found` for unknown routes). */
const STATUS_BY_CODE = {
  bad_request: 400,
  invalid_name: 400,
  invalid_dice: 400,
  invalid_bid: 400,
  self_invite: 400,
  unauthorized: 401,
  not_matched: 403,
  not_found: 404,
  invite_not_found: 404,
  no_active_game: 404,
  already_in_game: 409,
  opponent_busy: 409,
  opponent_offline: 409,
  invite_expired: 409,
  not_your_turn: 409,
  no_bid_to_challenge: 409,
  no_peeks_left: 409,
  nothing_to_peek: 409,
  game_over: 409,
  rate_limited: 429,
  server_error: 500,
};

/** An error that is safe to show to the client: `code` is stable, `message` is human readable. */
export class AppError extends Error {
  constructor(code, message, { retryAfter } = {}) {
    super(message);
    if (!(code in STATUS_BY_CODE)) throw new Error(`Unknown error code "${code}"`);
    this.name = 'AppError';
    this.code = code;
    this.status = STATUS_BY_CODE[code];
    this.retryAfter = retryAfter;
  }
}

/** The JSON body for an error response (SPEC 3.1). */
export function errorBody({ code, message, retryAfter }) {
  return { error: { code, message, ...(retryAfter === undefined ? {} : { retryAfter }) } };
}

/** Turns anything thrown into an AppError; unexpected failures are logged and hidden behind `server_error`. */
function toAppError(error, logger) {
  if (error instanceof AppError) return error;
  if (error?.type === 'entity.too.large') {
    return new AppError('bad_request', 'The request is too large.');
  }
  if (error?.type === 'entity.parse.failed') {
    return new AppError('bad_request', 'The request body is not valid JSON.');
  }
  if (Number.isInteger(error?.status) && error.status >= 400 && error.status < 500) {
    return new AppError('bad_request', 'The request could not be understood.');
  }
  logger.error(error);
  return new AppError('server_error', 'Something went wrong on our side. Please try again.');
}

export function notFoundHandler(req, res, next) {
  next(new AppError('not_found', 'There is no such endpoint.'));
}

/** Express error middleware: always answers with the SPEC error shape, never with a stack trace. */
export function createErrorHandler(logger) {
  return (error, req, res, next) => {
    if (res.headersSent) {
      next(error);
      return;
    }
    const appError = toAppError(error, logger);
    if (appError.retryAfter !== undefined) res.set('Retry-After', String(appError.retryAfter));
    res.status(appError.status).json(errorBody(appError));
  };
}
