import { AppError } from '../errors.js';
import { say } from './messages.js';

/**
 * The rules of a FunDice game (SPEC 3.7). Pure: no clock, no randomness and no I/O of its own.
 * Randomness comes from an injected `rng` ({ int(n), float() }) and time from an injected `now` (ms).
 *
 * A game is plain data. Every function below returns a new game and leaves the one it was given
 * untouched, so a failed action can never leave a half-applied change behind.
 *
 *   game = { id, status, round, players: [userId, userId], turn, bid, lastRound, winner, endReason,
 *            createdAt, finishedAt, seats: { [userId]: seat } }
 *   seat = { id, name, diceCount, dice, peeksLeft, seen, exposed, online, offlineDeadline, log, logSeq }
 *
 * `seat.seen` is what that player knows about the OTHER player's dice this round
 * (`{ index, value }`), `seat.exposed` lists their own dice indexes the other player saw because
 * they were caught peeking. Each seat has its own log, already worded for that player.
 */

export const FACES = 6;
const LOG_LIMIT = 30;

const clone = (value) => structuredClone(value);

export const otherPlayer = (game, userId) => game.players.find((id) => id !== userId);
export const totalDice = (game) => game.players.reduce((sum, id) => sum + game.seats[id].diceCount, 0);
export const countFace = (hand, face) => hand.filter((die) => die === face).length;
export const rollDice = (count, rng) => Array.from({ length: count }, () => rng.int(FACES) + 1);

const indexesNotSeen = (dice, seen) =>
  dice.map((_, index) => index).filter((index) => !seen.some((entry) => entry.index === index));

/** Appends a log entry to each viewer's own log; `text(viewer)` words it for that viewer. */
function record(game, at, { type, actor, notify = false, viewers = game.players }, text) {
  for (const viewer of viewers) {
    const seat = game.seats[viewer];
    seat.logSeq += 1;
    seat.log.push({ id: seat.logSeq, type, actor, text: text(viewer), notify, at });
    if (seat.log.length > LOG_LIMIT) seat.log.shift();
  }
}

function assertPlaying(game) {
  if (game.status !== 'playing') throw new AppError('game_over', 'This game is over.');
}

function assertTurn(game, userId) {
  if (game.turn !== userId) throw new AppError('not_your_turn', "It's not your turn.");
}

/**
 * Starts the game. Random draws, in order: who starts (`rng.int(2)`), then every player's dice
 * (first player first, one `rng.int(6)` per die).
 */
export function createGame({ id, players, config, rng, now }) {
  const seats = Object.fromEntries(
    players.map((player) => [
      player.id,
      {
        id: player.id,
        name: player.name,
        diceCount: config.diceCount,
        dice: [],
        peeksLeft: config.peeksPerGame,
        seen: [],
        exposed: [],
        online: true,
        offlineDeadline: null,
        log: [],
        logSeq: 0,
      },
    ]),
  );
  const game = {
    id,
    status: 'playing',
    round: 0,
    players: players.map((player) => player.id),
    seats,
    turn: null,
    bid: null,
    lastRound: null,
    winner: null,
    endReason: null,
    createdAt: now,
    finishedAt: null,
  };
  startRound(game, game.players[rng.int(game.players.length)], { rng, now });
  return game;
}

/** Rolls everyone's dice, clears what was seen and bid, and gives `starter` the first move. Mutates `game`. */
function startRound(game, starter, { rng, now }) {
  game.round += 1;
  game.bid = null;
  game.turn = starter;
  for (const id of game.players) {
    const seat = game.seats[id];
    seat.dice = rollDice(seat.diceCount, rng);
    seat.seen = [];
    seat.exposed = [];
  }
  record(game, now, { type: 'round_start', actor: starter }, (viewer) => say.roundStart(game, viewer, starter));
}

function finish(game, { winner, reason, at }) {
  game.status = 'finished';
  game.winner = winner;
  game.endReason = reason;
  game.finishedAt = at;
  for (const id of game.players) game.seats[id].offlineDeadline = null;
  record(game, at, { type: 'game_over', actor: winner }, (viewer) => say.gameOver(game, viewer, winner));
}

/** Why `quantity` x `face` is not a legal bid right now, or null when it is. */
export function bidProblem(game, quantity, face) {
  const max = totalDice(game);
  if (!Number.isInteger(quantity) || quantity < 1 || quantity > max) {
    return `Quantity must be a whole number from 1 to ${max}.`;
  }
  if (!Number.isInteger(face) || face < 1 || face > FACES) {
    return `Face must be a whole number from 1 to ${FACES}.`;
  }
  const { bid } = game;
  if (bid && !(quantity > bid.quantity || (quantity === bid.quantity && face > bid.face))) {
    return `Raise the bid: more dice, or the same number of a higher face (the bid is ${bid.quantity} × ${bid.face}).`;
  }
  return null;
}

export function placeBid(game, userId, quantity, face, { now }) {
  assertPlaying(game);
  assertTurn(game, userId);
  const problem = bidProblem(game, quantity, face);
  if (problem) throw new AppError('invalid_bid', problem);

  const next = clone(game);
  next.bid = { by: userId, quantity, face };
  next.turn = otherPlayer(next, userId);
  record(next, now, { type: 'bid', actor: userId }, (viewer) => say.bid(next, viewer, next.bid));
  return { game: next };
}

/**
 * "Liar!": counts the bid's face in both hands. The bid holds when there are at least as many
 * as it claims, and then the challenger loses a die, otherwise the bidder does. The loser starts
 * the next round, unless that was their last die.
 */
export function challenge(game, userId, { rng, now }) {
  assertPlaying(game);
  assertTurn(game, userId);
  if (!game.bid) throw new AppError('no_bid_to_challenge', 'There is no bid to challenge yet.');

  const next = clone(game);
  const bid = { ...next.bid };
  const hands = Object.fromEntries(next.players.map((id) => [id, [...next.seats[id].dice]]));
  const total = next.players.reduce((sum, id) => sum + countFace(hands[id], bid.face), 0);
  const bidHeld = total >= bid.quantity;
  const loser = bidHeld ? userId : bid.by;
  const round = { round: next.round, bid, challenger: userId, total, bidHeld, loser, hands };
  next.lastRound = round;
  record(next, now, { type: 'challenge', actor: userId }, (viewer) => say.challenge(next, viewer, userId));
  record(next, now, { type: 'round_result', actor: loser }, (viewer) => say.roundResult(next, viewer, round));

  const loserSeat = next.seats[loser];
  loserSeat.diceCount -= 1;
  if (loserSeat.diceCount === 0) {
    loserSeat.dice = [];
    for (const id of next.players) {
      next.seats[id].seen = [];
      next.seats[id].exposed = [];
    }
    finish(next, { winner: otherPlayer(next, loser), reason: 'dice_lost', at: now });
  } else {
    startRound(next, loser, { rng, now });
  }
  return { game: next, round };
}

/**
 * Secretly looks at one random opponent die. Random draws, in order: which die, whether it was
 * caught (`rng.float() < caughtChance`) and, when caught, which of the peeker's own dice is exposed.
 * Being caught tells the opponent and shows them one of the peeker's dice; a clean peek is
 * only ever logged for the peeker.
 */
export function peek(game, userId, { rng, now, caughtChance }) {
  assertPlaying(game);
  if (game.seats[userId].peeksLeft <= 0) {
    throw new AppError('no_peeks_left', 'You have no peeks left in this game.');
  }
  const unseen = indexesNotSeen(game.seats[otherPlayer(game, userId)].dice, game.seats[userId].seen);
  if (unseen.length === 0) {
    throw new AppError('nothing_to_peek', "You've already seen all of their dice this round.");
  }

  const next = clone(game);
  const me = next.seats[userId];
  const other = next.seats[otherPlayer(next, userId)];
  const index = unseen[rng.int(unseen.length)];
  const value = other.dice[index];
  me.peeksLeft -= 1;
  me.seen.push({ index, value });

  const caught = rng.float() < caughtChance;
  if (caught) {
    const hidden = indexesNotSeen(me.dice, other.seen);
    if (hidden.length > 0) {
      const exposed = hidden[rng.int(hidden.length)];
      me.exposed.push(exposed);
      other.seen.push({ index: exposed, value: me.dice[exposed] });
    }
    record(next, now, { type: 'peek_caught', actor: userId, notify: true }, (viewer) =>
      say.peekCaught(next, viewer, userId),
    );
  } else {
    record(next, now, { type: 'peek', actor: userId, viewers: [userId] }, () => say.peek(next, userId));
  }
  return { game: next, peek: { index, value, caught } };
}

/** The player has no live connection: they forfeit at `now + graceMs` unless they come back. */
export function markOffline(game, userId, { now, graceMs }) {
  if (game.status !== 'playing' || !game.seats[userId].online) return { game };
  const next = clone(game);
  next.seats[userId].online = false;
  next.seats[userId].offlineDeadline = now + graceMs;
  record(
    next,
    now,
    { type: 'opponent_offline', actor: userId, notify: true, viewers: [otherPlayer(next, userId)] },
    () => say.opponentOffline(next, userId, graceMs),
  );
  return { game: next };
}

export function markOnline(game, userId, { now }) {
  if (game.status !== 'playing' || game.seats[userId].online) return { game };
  const next = clone(game);
  next.seats[userId].online = true;
  next.seats[userId].offlineDeadline = null;
  record(
    next,
    now,
    { type: 'opponent_online', actor: userId, notify: true, viewers: [otherPlayer(next, userId)] },
    () => say.opponentOnline(next, userId),
  );
  return { game: next };
}

/** `reason` is 'forfeit' (the player left) or 'disconnect' (they stayed offline too long). */
export function forfeit(game, userId, reason, { now }) {
  assertPlaying(game);
  const next = clone(game);
  record(next, now, { type: 'forfeit', actor: userId, notify: true }, (viewer) =>
    say.forfeit(next, viewer, userId, reason),
  );
  finish(next, { winner: otherPlayer(next, userId), reason, at: now });
  return { game: next };
}
