import { z } from 'zod';
import { AppError } from './errors.js';
import { USER_ID } from './ids.js';

const NAME_MIN = 2;
const NAME_MAX = 16;
const NAME_CHARACTERS = /^[\p{L}\p{M}\p{N} _.-]+$/u;

/**
 * Trims and collapses whitespace, then enforces 2-16 characters made of letters, digits,
 * space, `_`, `-` and `.`. Throws `invalid_name` otherwise.
 */
export function parseName(value) {
  const name = typeof value === 'string' ? value.normalize('NFC').replace(/\s+/gu, ' ').trim() : '';
  const length = [...name].length;
  if (length < NAME_MIN || length > NAME_MAX || !NAME_CHARACTERS.test(name)) {
    throw new AppError('invalid_name', 'Names are 2 to 16 characters: letters, numbers, spaces, and _ - .');
  }
  return name;
}

/** Request body validators. Each throws the SPEC error code that fits the endpoint. */
export function createValidators({ diceCount }) {
  const dice = z.array(z.number().int().min(1).max(6)).length(diceCount);
  const schemas = {
    match: z.object({ dice, next: dice.nullish() }),
    bid: z.object({ quantity: z.number(), face: z.number() }),
    invite: z.object({ to: z.string().regex(USER_ID) }),
    register: z.object({ name: z.string() }),
  };

  const parse = (schema, body, failure) => {
    const result = schema.safeParse(body);
    if (!result.success) throw failure;
    return result.data;
  };

  return {
    match: (body) =>
      parse(
        schemas.match,
        body,
        new AppError('invalid_dice', `Enter ${diceCount} dice, each showing 1 to 6.`),
      ),
    bid: (body) =>
      parse(schemas.bid, body, new AppError('invalid_bid', 'A bid needs a quantity and a face from 1 to 6.')),
    invite: (body) =>
      parse(schemas.invite, body, new AppError('bad_request', 'Say who you want to invite.')),
    registerName: (body) => {
      const result = schemas.register.safeParse(body);
      return parseName(result.success ? result.data.name : undefined);
    },
  };
}
