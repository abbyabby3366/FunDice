import WebSocket from 'ws';

const BASE_URL = process.env.BASE_URL || 'http://localhost:3000';
const WS_URL = BASE_URL.replace(/^http/, 'ws') + '/ws';
const BOT_NAME = 'Bot Benny';

async function main() {
  console.log(`🤖 Starting ${BOT_NAME}... connecting to ${BASE_URL}`);

  // 1. Register or get token
  const regRes = await fetch(`${BASE_URL}/api/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name: BOT_NAME }),
  });
  if (!regRes.ok) {
    throw new Error(`Bot registration failed: ${regRes.status}`);
  }
  const { token, user } = await regRes.json();
  console.log(`🤖 Logged in as ${user.name} (${user.id})`);

  // Helper for authed API calls
  async function api(path, opts = {}) {
    const res = await fetch(`${BASE_URL}${path}`, {
      ...opts,
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
        ...(opts.headers || {}),
      },
    });
    return res.json();
  }

  // 2. Connect WebSocket
  const ws = new WebSocket(WS_URL);
  let activeGame = null;

  async function rollDice() {
    if (activeGame && activeGame.status === 'playing') return;
    try {
      const res = await api('/api/roll', { method: 'POST' });
      if (res.roll) {
        console.log(`\n🎲 --------------------------------------------------`);
        console.log(`🎲 ${BOT_NAME}'s Current Dice: [ ${res.roll.dice.join('  ')} ]`);
        console.log(`🎲 👉 Type these on the Play tab: ${res.roll.dice.join(' ')}`);
        console.log(`🎲 --------------------------------------------------\n`);
      }
    } catch (e) {
      console.error('Error rolling dice:', e.message);
    }
  }

  ws.on('open', () => {
    ws.send(JSON.stringify({ type: 'auth', token }));
  });

  ws.on('message', async (data) => {
    try {
      const msg = JSON.parse(data.toString());
      if (msg.type === 'hello') {
        console.log(`🤖 WebSocket online! Server time: ${msg.serverTime}`);
        await rollDice();
      } else if (msg.type === 'invite') {
        console.log(`🤖 Received challenge from ${msg.invite.from.name}! Auto-accepting...`);
        const acc = await api(`/api/invites/${msg.invite.id}/accept`, { method: 'POST' });
        activeGame = acc.game;
        console.log(`🤖 Game started! ID: ${activeGame?.id}`);
      } else if (msg.type === 'game') {
        activeGame = msg.game;
        onGameUpdate(activeGame);
      }
    } catch (err) {
      console.error('Bot WS error:', err.message);
    }
  });

  // Re-roll every 10 min while idle (stable for user matching)
  setInterval(async () => {
    if (!activeGame || activeGame.status !== 'playing') {
      await rollDice();
    }
  }, 600000);

  async function onGameUpdate(game) {
    if (!game || game.status !== 'playing') {
      if (game?.status === 'finished') {
        console.log(`🤖 Game finished! Winner: ${game.winner === 'you' ? BOT_NAME : 'Player'}`);
        await api('/api/game/leave', { method: 'POST' });
        activeGame = null;
        await rollDice();
      }
      return;
    }

    if (game.turn !== 'you') {
      console.log(`🤖 Opponent's turn... (${game.opponent.name})`);
      return;
    }

    // It is Bot Benny's turn!
    console.log(`🤖 Bot Benny's turn to play!`);
    await new Promise((r) => setTimeout(r, 1500)); // Pondering delay

    const myDice = game.myDice;
    const currentBid = game.bid;

    if (!currentBid) {
      // First bid of the round: pick most frequent die in hand
      const counts = {};
      for (const d of myDice) counts[d] = (counts[d] || 0) + 1;
      let bestFace = 1;
      let maxC = 0;
      for (const [f, c] of Object.entries(counts)) {
        if (c > maxC) {
          maxC = c;
          bestFace = Number(f);
        }
      }
      console.log(`🤖 Benny placing opening bid: ${maxC} × ${bestFace}`);
      await api('/api/game/bid', {
        method: 'POST',
        body: JSON.stringify({ quantity: Math.max(1, maxC), face: bestFace }),
      });
      return;
    }

    // Heuristic: Expected count on table = own matches + (opponentDice / 6)
    const matchingInHand = myDice.filter((d) => d === currentBid.face).length;
    const expectedTotal = matchingInHand + (game.opponent.diceCount / 6);

    console.log(`🤖 Bid is ${currentBid.quantity} × ${currentBid.face}. Benny has ${matchingInHand}, expected: ${expectedTotal.toFixed(1)}`);

    if (currentBid.quantity > expectedTotal + 1.2) {
      console.log(`🤖 Benny calls LIAR!`);
      await api('/api/game/challenge', { method: 'POST' });
    } else {
      // Raise minimally
      let nextQ = currentBid.quantity;
      let nextF = currentBid.face + 1;
      if (nextF > 6) {
        nextQ += 1;
        nextF = 1;
      }
      console.log(`🤖 Benny raises bid to ${nextQ} × ${nextF}`);
      await api('/api/game/bid', {
        method: 'POST',
        body: JSON.stringify({ quantity: nextQ, face: nextF }),
      });
    }
  }
}

main().catch(console.error);
