/**
 * Log texts, written from the point of view of `viewer` ("You bid 3 × 4" / "Sam bid 3 × 4").
 * Everything here is pure: it only reads names from the game state.
 */

const nameOf = (game, id) => game.seats[id].name;
const otherOf = (game, id) => game.players.find((player) => player !== id);
const subject = (game, viewer, id) => (id === viewer ? 'You' : nameOf(game, id));

export const say = {
  roundStart: (game, viewer, starter) =>
    `Round ${game.round}: ${starter === viewer ? 'you start' : `${nameOf(game, starter)} starts`}`,

  bid: (game, viewer, bid) => `${subject(game, viewer, bid.by)} bid ${bid.quantity} × ${bid.face}`,

  challenge: (game, viewer, challenger) => `${subject(game, viewer, challenger)} called Liar!`,

  roundResult: (game, viewer, { total, bid, bidHeld, loser }) => {
    const found = `${total} × ${bid.face} on the table`;
    const verdict = bidHeld ? `The bid held: ${found}.` : `It was a bluff: only ${found}.`;
    const penalty = loser === viewer ? 'You lose a die.' : `${nameOf(game, loser)} loses a die.`;
    return `${verdict} ${penalty}`;
  },

  peek: (game, peeker) => `You peeked at one of ${nameOf(game, otherOf(game, peeker))}'s dice.`,

  peekCaught: (game, viewer, peeker) =>
    viewer === peeker
      ? `Caught! ${nameOf(game, otherOf(game, peeker))} saw you peek and can now see one of your dice.`
      : `You caught ${nameOf(game, peeker)} peeking! One of their dice is now visible to you.`,

  opponentOffline: (game, offline, graceMs) =>
    `${nameOf(game, offline)} lost connection. They have ${Math.ceil(graceMs / 1000)} seconds to come back.`,

  opponentOnline: (game, returned) => `${nameOf(game, returned)} is back.`,

  forfeit: (game, viewer, forfeiter, reason) => {
    const you = forfeiter === viewer;
    if (reason === 'disconnect') {
      return you ? 'You were offline for too long.' : `${nameOf(game, forfeiter)} did not come back in time.`;
    }
    return you ? 'You left the game.' : `${nameOf(game, forfeiter)} left the game.`;
  },

  gameOver: (game, viewer, winner) =>
    winner === viewer ? 'You won the game!' : `${nameOf(game, winner)} won the game.`,
};
