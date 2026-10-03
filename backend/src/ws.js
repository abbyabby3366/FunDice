import { WebSocketServer, WebSocket } from 'ws';
import { toView } from './game/view.js';
import { markOnline, markOffline, forfeit } from './game/engine.js';

export function createWsHub({ config, registry, tokens, timers, now }) {
  const disconnectTimers = new Map(); // userId -> cancelFn

  const send = (ws, message) => {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(message));
    }
  };

  const sendToUser = (userId, message) => {
    const sockets = registry.sockets.get(userId);
    if (!sockets) return;
    for (const ws of sockets) {
      send(ws, message);
    }
  };

  const broadcastGame = (game, nowMs) => {
    for (const playerId of game.players) {
      const view = {
        ...toView(game, playerId),
        version: game.version || 1,
        updatedAt: new Date(nowMs).toISOString(),
      };
      sendToUser(playerId, { type: 'game', game: view });
    }
  };

  const onUserCameOnline = (userId) => {
    // Cancel offline disconnect deadline timer if active
    const cancel = disconnectTimers.get(userId);
    if (cancel) {
      cancel();
      disconnectTimers.delete(userId);
    }

    const gameId = registry.gameByUser.get(userId);
    if (!gameId) return;
    const game = registry.games.get(gameId);
    if (!game || game.status !== 'playing') return;

    const nowMs = now();
    const { game: nextGame } = markOnline(game, userId, { now: nowMs });
    if (nextGame !== game) {
      nextGame.version = (game.version || 1) + 1;
      registry.games.set(nextGame.id, nextGame);
      broadcastGame(nextGame, nowMs);
    }
  };

  const onUserWentOffline = (userId) => {
    const gameId = registry.gameByUser.get(userId);
    if (!gameId) return;
    const game = registry.games.get(gameId);
    if (!game || game.status !== 'playing') return;

    const nowMs = now();
    const { game: nextGame } = markOffline(game, userId, { now: nowMs, graceMs: config.disconnectGraceMs });
    if (nextGame !== game) {
      nextGame.version = (game.version || 1) + 1;
      registry.games.set(nextGame.id, nextGame);
      broadcastGame(nextGame, nowMs);
    }

    // Start disconnect grace timer
    const cancel = timers.after(config.disconnectGraceMs, () => {
      disconnectTimers.delete(userId);
      if (!registry.isOnline(userId)) {
        const activeGameId = registry.gameByUser.get(userId);
        const currentGame = activeGameId ? registry.games.get(activeGameId) : null;
        if (currentGame && currentGame.status === 'playing') {
          const timeoutNow = now();
          const { game: forfeitedGame } = forfeit(currentGame, userId, 'disconnect', { now: timeoutNow });
          forfeitedGame.version = (currentGame.version || 1) + 1;
          registry.games.set(forfeitedGame.id, forfeitedGame);
          broadcastGame(forfeitedGame, timeoutNow);
        }
      }
    });
    disconnectTimers.set(userId, cancel);
  };

  const wss = new WebSocketServer({
    noServer: true,
    maxPayload: config.maxPayloadBytes,
  });

  wss.on('connection', (ws) => {
    let authenticatedUser = null;
    let isAlive = true;

    ws.on('pong', () => {
      isAlive = true;
    });

    // 5-second auth timeout
    const authTimeout = timers.after(config.authTimeoutMs, () => {
      if (!authenticatedUser) {
        send(ws, { type: 'error', code: 'unauthorized' });
        ws.close(4401, 'Unauthorized');
      }
    });

    ws.on('message', (raw) => {
      if (authenticatedUser) {
        // Client -> server messages are ignored after auth per SPEC 3.5
        return;
      }
      try {
        const data = JSON.parse(raw.toString());
        if (data?.type !== 'auth' || typeof data?.token !== 'string') {
          send(ws, { type: 'error', code: 'unauthorized' });
          ws.close(4401, 'Unauthorized');
          return;
        }

        const claims = tokens.verify(data.token);
        if (!claims) {
          send(ws, { type: 'error', code: 'unauthorized' });
          ws.close(4401, 'Unauthorized');
          return;
        }

        const user = registry.ensureUser(claims.id, claims.name);
        registry.touch(user);

        const currentSockets = registry.sockets.get(user.id);
        if (currentSockets && currentSockets.size >= config.maxSocketsPerUser) {
          send(ws, { type: 'error', code: 'rate_limited' });
          ws.close(4429, 'Too many connections');
          return;
        }

        authenticatedUser = user;
        authTimeout();

        const cameOnline = registry.addSocket(user.id, ws);
        if (cameOnline) {
          onUserCameOnline(user.id);
        }

        send(ws, {
          type: 'hello',
          userId: user.id,
          serverTime: new Date(now()).toISOString(),
        });
      } catch {
        send(ws, { type: 'error', code: 'unauthorized' });
        ws.close(4401, 'Unauthorized');
      }
    });

    ws.on('close', () => {
      authTimeout();
      if (authenticatedUser) {
        const wentOffline = registry.removeSocket(authenticatedUser.id, ws);
        if (wentOffline) {
          onUserWentOffline(authenticatedUser.id);
        }
      }
    });
  });

  // Heartbeat ping interval
  const pingInterval = timers.every(config.pingIntervalMs, () => {
    for (const ws of wss.clients) {
      if (ws.isAlive === false) {
        ws.terminate();
        continue;
      }
      ws.isAlive = false;
      ws.ping();
    }
  });

  const closeAll = (code = 1012, reason = 'Server shutting down') => {
    pingInterval();
    for (const ws of wss.clients) {
      try {
        ws.close(code, reason);
      } catch {
        ws.terminate();
      }
    }
    wss.close();
  };

  return {
    wss,
    sendToUser,
    broadcastGame,
    closeAll,
  };
}
