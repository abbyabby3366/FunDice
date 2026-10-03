/**
 * Aggregates runtime statistics, active game states, player histories,
 * and safe configuration parameters for the monitoring dashboard.
 */
export async function getStatusData({ config, registry, db, now }) {
  const nowMs = now();
  const uptime = Math.round(process.uptime() * 10) / 10;
  const dbStats = db ? await db.getStats() : { status: 'disabled' };

  const mem = process.memoryUsage();
  const memory = {
    heapUsedMB: Math.round((mem.heapUsed / 1024 / 1024) * 10) / 10,
    heapTotalMB: Math.round((mem.heapTotal / 1024 / 1024) * 10) / 10,
    rssMB: Math.round((mem.rss / 1024 / 1024) * 10) / 10,
  };

  const safeConfig = {
    nodeEnv: config.nodeEnv,
    port: config.port,
    jwtSecretConfigured: Boolean(config.jwtSecret),
    diceCount: config.diceCount,
    rollHistory: config.rollHistory,
    peeksPerGame: config.peeksPerGame,
    peekCaughtChance: config.peekCaughtChance,
    inviteTtlSec: Math.floor(config.inviteTtlMs / 1000),
    disconnectGraceSec: Math.floor(config.disconnectGraceMs / 1000),
    tokenTtlDays: Math.floor(config.tokenTtlSec / (24 * 3600)),
    rematchWindowMin: Math.floor(config.rematchWindowMs / 60000),
    userIdleTtlHours: Math.floor(config.userIdleTtlMs / 3600000),
    sweepIntervalSec: Math.floor(config.sweepIntervalMs / 1000),
    pingIntervalSec: Math.floor(config.pingIntervalMs / 1000),
    maxSocketsPerUser: config.maxSocketsPerUser,
    limits: config.limits,
    lockout: config.lockout,
  };

  const users = [];
  for (const user of registry.users.values()) {
    const isOnline = registry.isOnline(user.id);
    const socketCount = registry.sockets.get(user.id)?.size || 0;
    users.push({
      id: user.id,
      name: user.name,
      createdAt: user.createdAt,
      lastSeenAt: user.lastSeenAt,
      isOnline,
      socketCount,
      rollCount: user.rollSeq,
    });
  }

  const games = [];
  for (const game of registry.games.values()) {
    const playerSummaries = game.players.map((id) => {
      const seat = game.seats[id];
      return {
        id,
        name: seat?.name || id,
        diceCount: seat?.diceCount ?? 0,
        peeksLeft: seat?.peeksLeft ?? 0,
        online: seat?.online ?? false,
      };
    });

    games.push({
      id: game.id,
      status: game.status,
      round: game.round,
      players: playerSummaries,
      turnPlayer: game.turn ? game.seats[game.turn]?.name || game.turn : null,
      currentBid: game.bid ? { quantity: game.bid.quantity, face: game.bid.face, by: game.seats[game.bid.by]?.name || game.bid.by } : null,
      winner: game.winner ? game.seats[game.winner]?.name || game.winner : null,
      endReason: game.endReason,
      createdAt: game.createdAt,
      finishedAt: game.finishedAt,
    });
  }
  games.sort((a, b) => b.createdAt - a.createdAt);

  const invites = [];
  for (const inv of registry.invites.values()) {
    invites.push({
      id: inv.id,
      status: inv.status,
      from: inv.from,
      to: inv.to,
      createdAt: inv.createdAt,
      expiresAt: inv.expiresAt,
    });
  }
  invites.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

  return {
    server: {
      status: 'operational',
      uptime,
      nodeVersion: process.version,
      serverTime: new Date(nowMs).toISOString(),
      memory,
    },
    database: dbStats,
    config: safeConfig,
    metrics: {
      totalUsers: users.length,
      onlineUsers: users.filter((u) => u.isOnline).length,
      activeGames: games.filter((g) => g.status === 'playing').length,
      pendingInvites: invites.filter((i) => i.status === 'pending').length,
    },
    users,
    games,
    invites,
  };
}
