import { otherPlayer } from './engine.js';

const iso = (ms) => new Date(ms).toISOString();

/**
 * Projects a game for one player (SPEC 3.6, without `version` and `updatedAt`).
 *
 * This is the only place game data leaves the engine, and it names every field it copies:
 * the opponent's dice are never read here. The opponent only shows up through what `viewer`
 * has legitimately learned (`peeks`) and through `lastRound.hands` after a challenge.
 */
export function toView(game, viewer) {
  const me = game.seats[viewer];
  const opponentId = otherPlayer(game, viewer);
  const opponent = game.seats[opponentId];
  const side = (id) => (id === viewer ? 'you' : 'opponent');
  const bid = (value) => value && { by: side(value.by), quantity: value.quantity, face: value.face };
  const last = game.lastRound;

  return {
    id: game.id,
    status: game.status,
    round: game.round,
    turn: side(game.turn),
    you: { id: me.id, name: me.name, diceCount: me.diceCount, peeksLeft: me.peeksLeft },
    opponent: {
      id: opponent.id,
      name: opponent.name,
      diceCount: opponent.diceCount,
      online: opponent.online,
      offlineDeadline: opponent.offlineDeadline === null ? null : iso(opponent.offlineDeadline),
    },
    myDice: [...me.dice],
    bid: bid(game.bid),
    peeks: me.seen.map(({ index, value }) => ({ index, value })),
    exposed: me.exposed.map((index) => ({ index, value: me.dice[index] })),
    lastRound: last && {
      round: last.round,
      bid: bid(last.bid),
      challenger: side(last.challenger),
      total: last.total,
      bidHeld: last.bidHeld,
      loser: side(last.loser),
      hands: { you: [...last.hands[viewer]], opponent: [...last.hands[opponentId]] },
    },
    winner: game.winner === null ? null : side(game.winner),
    endReason: game.endReason,
    log: me.log.map((entry) => ({
      id: entry.id,
      type: entry.type,
      actor: side(entry.actor),
      text: entry.text,
      notify: entry.notify,
      at: iso(entry.at),
    })),
  };
}
