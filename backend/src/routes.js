import express from 'express';
import { rateLimit } from 'express-rate-limit';
import { AppError } from './errors.js';
import { newId } from './ids.js';
import { createRequireAuth, bearerToken } from './auth.js';
import { createValidators, parseName } from './validate.js';
import { cryptoRng } from './rng.js';
import {
  createGame,
  placeBid,
  challenge,
  peek,
  forfeit,
  otherPlayer,
} from './game/engine.js';
import { toView } from './game/view.js';
import { getStatusData } from './status.js';

function projectGame(game, viewerId, nowMs) {
  if (!game) return null;
  return {
    ...toView(game, viewerId),
    version: game.version || 1,
    updatedAt: new Date(nowMs).toISOString(),
  };
}

export function createRoutes({ config, registry, tokens, wsHub, db, now }) {
  const router = express.Router();
  const requireAuth = createRequireAuth({ tokens, registry });
  const validators = createValidators({ diceCount: config.diceCount });

  // Rate limiter factory
  const makeLimiter = (options, keyGen = null) =>
    rateLimit({
      windowMs: options.windowMs,
      limit: options.limit,
      standardHeaders: true,
      legacyHeaders: false,
      validate: { keyGeneratorIpFallback: false },
      keyGenerator: keyGen || ((req) => req.ip),
      handler: (req, res, next, opts) => {
        const retryAfter = Math.ceil(opts.windowMs / 1000);
        next(new AppError('rate_limited', 'Too many requests. Please slow down.', { retryAfter }));
      },
    });

  const registerLimiter = makeLimiter(config.limits.register);
  const rollLimiter = makeLimiter(config.limits.roll, (req) => req.user?.id || req.ip);
  const matchLimiter = makeLimiter(config.limits.match, (req) => req.user?.id || req.ip);
  const gameLimiter = makeLimiter(config.limits.game, (req) => req.user?.id || req.ip);

  // Operations and status dashboard API
  router.get('/admin/status', async (req, res, next) => {
    try {
      res.json(await getStatusData({ config, registry, db, now }));
    } catch (err) {
      next(err);
    }
  });

  // 1. Register or rename / token refresh
  router.post('/register', registerLimiter, (req, res) => {
    const name = validators.registerName(req.body);
    const existing = tokens.verify(bearerToken(req));

    let user;
    if (existing) {
      user = registry.ensureUser(existing.id, name);
      user.name = name;
    } else {
      user = registry.createUser(name);
    }
    registry.touch(user);
    db?.saveUser(user);

    const token = tokens.sign(user);
    res.status(201).json({
      token,
      user: { id: user.id, name: user.name },
    });
  });

  // 2. Resync snapshot
  router.get('/me', requireAuth, (req, res) => {
    const user = req.user;
    const nowMs = now();

    const incomingId = registry.incomingInvite.get(user.id);
    const incoming = incomingId ? registry.invites.get(incomingId) ?? null : null;

    const outgoingId = registry.outgoingInvite.get(user.id);
    const outgoing = outgoingId ? registry.invites.get(outgoingId) ?? null : null;

    const gameId = registry.gameByUser.get(user.id);
    const game = gameId ? registry.games.get(gameId) ?? null : null;

    res.json({
      user: { id: user.id, name: user.name },
      rolls: user.rolls.map((r) => ({
        seq: r.seq,
        dice: r.dice,
        at: new Date(r.at).toISOString(),
      })),
      invites: { incoming, outgoing },
      game: projectGame(game, user.id, nowMs),
      config: {
        diceCount: config.diceCount,
        rollHistory: config.rollHistory,
        peeksPerGame: config.peeksPerGame,
        inviteTtlSec: Math.floor(config.inviteTtlMs / 1000),
        graceSec: Math.floor(config.disconnectGraceMs / 1000),
      },
    });
  });

  // 3. Roll
  router.post('/roll', requireAuth, rollLimiter, (req, res) => {
    const user = req.user;
    const activeGameId = registry.gameByUser.get(user.id);
    const activeGame = activeGameId ? registry.games.get(activeGameId) : null;
    if (activeGame && activeGame.status === 'playing') {
      throw new AppError('already_in_game', 'You cannot roll while a game is in progress.');
    }

    const dice = Array.from({ length: config.diceCount }, () => cryptoRng.int(6) + 1);
    const roll = registry.recordRoll(user, dice);
    db?.recordRoll({
      userId: user.id,
      userName: user.name,
      seq: roll.seq,
      dice: roll.dice,
      at: roll.at,
    });

    res.json({
      roll: {
        seq: roll.seq,
        dice: roll.dice,
        at: new Date(roll.at).toISOString(),
      },
      rolls: user.rolls.map((r) => ({
        seq: r.seq,
        dice: r.dice,
        at: new Date(r.at).toISOString(),
      })),
    });
  });

  // 4. Match
  router.post('/match', requireAuth, matchLimiter, (req, res) => {
    const user = req.user;
    const nowMs = now();

    const activeGameId = registry.gameByUser.get(user.id);
    const activeGame = activeGameId ? registry.games.get(activeGameId) : null;
    if (activeGame && activeGame.status === 'playing') {
      throw new AppError('already_in_game', 'You cannot match while in a game.');
    }

    // Check lockout
    let lockout = registry.lockouts.get(user.id);
    if (lockout && lockout.lockedUntil > nowMs) {
      const retryAfter = Math.ceil((lockout.lockedUntil - nowMs) / 1000);
      throw new AppError('rate_limited', 'Too many attempts. Please wait a moment.', { retryAfter });
    }

    const { dice, next } = validators.match(req.body);
    const diceMatch = (a, b) => a.length === b.length && a.every((v, i) => v === b[i]);

    const candidates = [];
    for (const onlineUser of registry.onlineUsers()) {
      if (onlineUser.id === user.id) continue;
      const history = onlineUser.rolls.slice(-config.rollHistory);
      const rIdx = history.findIndex((r) => diceMatch(r.dice, dice));
      if (rIdx === -1) continue;

      if (next) {
        const rSeq = history[rIdx].seq;
        const hasNext = history.some((r2) => r2.seq > rSeq && diceMatch(r2.dice, next));
        if (!hasNext) continue;
      }
      candidates.push(onlineUser);
    }

    if (candidates.length === 0) {
      if (!lockout || nowMs - lockout.windowStart > config.lockout.windowMs) {
        lockout = { misses: 1, windowStart: nowMs, lockedUntil: 0 };
      } else {
        lockout.misses += 1;
      }
      if (lockout.misses >= config.lockout.maxMisses) {
        lockout.lockedUntil = nowMs + config.lockout.durationMs;
      }
      registry.lockouts.set(user.id, lockout);
      return res.json({ status: 'not_found' });
    }

    // Reset lockout on non-empty match
    registry.lockouts.delete(user.id);

    if (candidates.length >= 2) {
      return res.json({ status: 'ambiguous', candidates: candidates.length });
    }

    const target = candidates[0];
    const grantKey = `${user.id}>${target.id}`;
    registry.grants.set(grantKey, nowMs + config.grantTtlMs);

    const targetGameId = registry.gameByUser.get(target.id);
    const targetGame = targetGameId ? registry.games.get(targetGameId) : null;
    const isBusy = (targetGame && targetGame.status === 'playing') || registry.incomingInvite.has(target.id);

    return res.json({
      status: isBusy ? 'busy' : 'matched',
      opponent: { id: target.id, name: target.name },
    });
  });

  // 5. Invites
  router.post('/invites', requireAuth, (req, res) => {
    const user = req.user;
    const nowMs = now();
    const { to: toId } = validators.invite(req.body);

    if (toId === user.id) {
      throw new AppError('self_invite', 'You cannot invite yourself.');
    }

    const target = registry.users.get(toId);
    if (!target || !registry.isOnline(toId)) {
      throw new AppError('opponent_offline', 'Player is currently offline.');
    }

    const targetGameId = registry.gameByUser.get(toId);
    const targetGame = targetGameId ? registry.games.get(targetGameId) : null;
    if ((targetGame && targetGame.status === 'playing') || registry.incomingInvite.has(toId)) {
      throw new AppError('opponent_busy', 'Player is currently busy.');
    }

    const grantKey = `${user.id}>${toId}`;
    const grantExp = registry.grants.get(grantKey) || 0;
    const pairKey = [user.id, toId].sort().join('|');
    const rematchAt = registry.finishedPairs.get(pairKey) || 0;
    const hasRematch = nowMs - rematchAt <= config.rematchWindowMs;

    if (grantExp < nowMs && !hasRematch) {
      throw new AppError('not_matched', 'You must match the player dice before inviting.');
    }

    // Cancel prior outgoing invite if any
    const oldOutId = registry.outgoingInvite.get(user.id);
    if (oldOutId) {
      const oldInv = registry.invites.get(oldOutId);
      if (oldInv && oldInv.status === 'pending') {
        oldInv.status = 'cancelled';
        registry.incomingInvite.delete(oldInv.to.id);
        wsHub.sendToUser(oldInv.to.id, { type: 'invite_update', invite: oldInv });
      }
    }

    const invite = {
      id: newId('inv'),
      status: 'pending',
      from: { id: user.id, name: user.name },
      to: { id: target.id, name: target.name },
      createdAt: new Date(nowMs).toISOString(),
      expiresAt: new Date(nowMs + config.inviteTtlMs).toISOString(),
    };

    registry.invites.set(invite.id, invite);
    registry.outgoingInvite.set(user.id, invite.id);
    registry.incomingInvite.set(target.id, invite.id);

    wsHub.sendToUser(target.id, { type: 'invite', invite });
    res.status(201).json({ invite });
  });

  router.post('/invites/:id/accept', requireAuth, (req, res) => {
    const user = req.user;
    const invite = registry.invites.get(req.params.id);
    if (!invite || invite.to.id !== user.id) {
      throw new AppError('invite_not_found', 'Invitation not found.');
    }
    if (invite.status !== 'pending') {
      throw new AppError('invite_expired', 'This invitation has expired or been cancelled.');
    }

    const fromUser = registry.users.get(invite.from.id);
    if (!fromUser || !registry.isOnline(fromUser.id)) {
      throw new AppError('opponent_offline', 'The challenger has gone offline.');
    }

    const myGame = registry.gameByUser.get(user.id);
    const oppGame = registry.gameByUser.get(fromUser.id);
    if ((myGame && registry.games.get(myGame)?.status === 'playing') ||
        (oppGame && registry.games.get(oppGame)?.status === 'playing')) {
      throw new AppError('already_in_game', 'A player is already in a game.');
    }

    invite.status = 'accepted';
    registry.outgoingInvite.delete(invite.from.id);
    registry.incomingInvite.delete(user.id);

    // Cancel recipient's own outgoing invite if any
    const myOutId = registry.outgoingInvite.get(user.id);
    if (myOutId) {
      const myOut = registry.invites.get(myOutId);
      if (myOut && myOut.status === 'pending') {
        myOut.status = 'cancelled';
        registry.incomingInvite.delete(myOut.to.id);
        wsHub.sendToUser(myOut.to.id, { type: 'invite_update', invite: myOut });
      }
      registry.outgoingInvite.delete(user.id);
    }

    const nowMs = now();
    const game = createGame({
      id: newId('gam'),
      players: [invite.from, { id: user.id, name: user.name }],
      config,
      rng: cryptoRng,
      now: nowMs,
    });
    game.version = 1;

    registry.games.set(game.id, game);
    registry.gameByUser.set(invite.from.id, game.id);
    registry.gameByUser.set(user.id, game.id);

    wsHub.sendToUser(invite.from.id, { type: 'invite_update', invite });
    wsHub.broadcastGame(game, nowMs);

    res.json({ game: projectGame(game, user.id, nowMs) });
  });

  router.post('/invites/:id/decline', requireAuth, (req, res) => {
    const user = req.user;
    const invite = registry.invites.get(req.params.id);
    if (!invite || invite.to.id !== user.id) {
      throw new AppError('invite_not_found', 'Invitation not found.');
    }
    if (invite.status === 'pending') {
      invite.status = 'declined';
      registry.outgoingInvite.delete(invite.from.id);
      registry.incomingInvite.delete(user.id);
      wsHub.sendToUser(invite.from.id, { type: 'invite_update', invite });
    }
    res.json({ ok: true });
  });

  router.delete('/invites/:id', requireAuth, (req, res) => {
    const user = req.user;
    const invite = registry.invites.get(req.params.id);
    if (!invite || invite.from.id !== user.id) {
      throw new AppError('invite_not_found', 'Invitation not found.');
    }
    if (invite.status === 'pending') {
      invite.status = 'cancelled';
      registry.outgoingInvite.delete(user.id);
      registry.incomingInvite.delete(invite.to.id);
      wsHub.sendToUser(invite.to.id, { type: 'invite_update', invite });
    }
    res.json({ ok: true });
  });

  // 6. Game actions
  const getMyGame = (userId) => {
    const gameId = registry.gameByUser.get(userId);
    if (!gameId) throw new AppError('no_active_game', 'You are not in a game.');
    const game = registry.games.get(gameId);
    if (!game) throw new AppError('no_active_game', 'Game not found.');
    return game;
  };

  const updateGame = (nextGame, nowMs) => {
    nextGame.version = (nextGame.version || 1) + 1;
    registry.games.set(nextGame.id, nextGame);
    if (nextGame.status === 'finished') {
      const pairKey = [...nextGame.players].sort().join('|');
      registry.finishedPairs.set(pairKey, nowMs);
      db?.saveFinishedGame(nextGame, nowMs);
    }
    wsHub.broadcastGame(nextGame, nowMs);
  };

  router.get('/game', requireAuth, (req, res) => {
    const gameId = registry.gameByUser.get(req.user.id);
    const game = gameId ? registry.games.get(gameId) : null;
    res.json({ game: projectGame(game, req.user.id, now()) });
  });

  router.post('/game/bid', requireAuth, gameLimiter, (req, res) => {
    const game = getMyGame(req.user.id);
    const { quantity, face } = validators.bid(req.body);
    const nowMs = now();
    const { game: nextGame } = placeBid(game, req.user.id, quantity, face, { now: nowMs });
    nextGame.version = game.version;
    updateGame(nextGame, nowMs);
    res.json({ game: projectGame(nextGame, req.user.id, nowMs) });
  });

  router.post('/game/challenge', requireAuth, gameLimiter, (req, res) => {
    const game = getMyGame(req.user.id);
    const nowMs = now();
    const { game: nextGame } = challenge(game, req.user.id, { rng: cryptoRng, now: nowMs });
    nextGame.version = game.version;
    updateGame(nextGame, nowMs);
    res.json({ game: projectGame(nextGame, req.user.id, nowMs) });
  });

  router.post('/game/peek', requireAuth, gameLimiter, (req, res) => {
    const game = getMyGame(req.user.id);
    const nowMs = now();
    const { game: nextGame, peek: peekResult } = peek(game, req.user.id, {
      rng: cryptoRng,
      now: nowMs,
      caughtChance: config.peekCaughtChance,
    });
    nextGame.version = game.version;
    updateGame(nextGame, nowMs);
    res.json({
      game: projectGame(nextGame, req.user.id, nowMs),
      peek: peekResult,
    });
  });

  router.post('/game/leave', requireAuth, (req, res) => {
    const user = req.user;
    const gameId = registry.gameByUser.get(user.id);
    if (!gameId) return res.json({ game: null });

    const game = registry.games.get(gameId);
    if (!game) {
      registry.gameByUser.delete(user.id);
      return res.json({ game: null });
    }

    const nowMs = now();
    if (game.status === 'playing') {
      const { game: nextGame } = forfeit(game, user.id, 'forfeit', { now: nowMs });
      nextGame.version = game.version;
      registry.gameByUser.delete(user.id);
      updateGame(nextGame, nowMs);
      return res.json({ game: null });
    }

    // If already finished, leave means dismiss
    registry.gameByUser.delete(user.id);
    return res.json({ game: null });
  });

  return router;
}
