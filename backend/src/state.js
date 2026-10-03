import { newId } from './ids.js';

/**
 * All in-memory state of the server. Nothing is persisted: a restart forgets games and invites
 * and clients resync. The services (matching, invites, games) read and write these maps.
 */
export class Registry {
  constructor({ config, now }) {
    this.config = config;
    this.now = now;
    /** userId -> { id, name, createdAt, lastSeenAt, rollSeq, rolls, viewVersion } */
    this.users = new Map();
    /** userId -> Set of authenticated WebSockets. A user is online while the set is non-empty. */
    this.sockets = new Map();
    /** "fromId>toId" -> expiry (ms): `from` found `to` by dice and may invite them. */
    this.grants = new Map();
    /** userId -> { misses, windowStart, lockedUntil } for consecutive `not_found` matches. */
    this.lockouts = new Map();
    /** inviteId -> invite record */
    this.invites = new Map();
    /** userId -> id of that user's pending outgoing invite */
    this.outgoingInvite = new Map();
    /** userId -> id of that user's pending incoming invite */
    this.incomingInvite = new Map();
    /** gameId -> game record (engine state plus per-viewer bookkeeping) */
    this.games = new Map();
    /** userId -> gameId of the game they are in (playing, or finished and not yet dismissed) */
    this.gameByUser = new Map();
    /** "idA|idB" -> when the pair last finished a game together (ms), for rematch invites */
    this.finishedPairs = new Map();
  }

  createUser(name) {
    return this.#insertUser(newId('usr'), name);
  }

  /** Returns the user with this id, recreating them when the server has forgotten them. */
  ensureUser(id, name) {
    return this.users.get(id) ?? this.#insertUser(id, name);
  }

  #insertUser(id, name) {
    const at = this.now();
    const user = { id, name, createdAt: at, lastSeenAt: at, rollSeq: 0, rolls: [], viewVersion: 0 };
    this.users.set(id, user);
    return user;
  }

  touch(user) {
    user.lastSeenAt = this.now();
  }

  /** Stores a roll as the user's newest and keeps only the last `rollHistory` rolls. */
  recordRoll(user, dice) {
    user.rollSeq += 1;
    const roll = { seq: user.rollSeq, dice, at: this.now() };
    user.rolls.push(roll);
    const overflow = user.rolls.length - this.config.rollHistory;
    if (overflow > 0) user.rolls.splice(0, overflow);
    return roll;
  }

  isOnline(userId) {
    return this.sockets.has(userId);
  }

  *onlineUsers() {
    for (const userId of this.sockets.keys()) {
      const user = this.users.get(userId);
      if (user) yield user;
    }
  }

  /** Returns true when this socket made the user come online. */
  addSocket(userId, socket) {
    const existing = this.sockets.get(userId);
    if (existing) {
      existing.add(socket);
      return false;
    }
    this.sockets.set(userId, new Set([socket]));
    return true;
  }

  /** Returns true when this socket was the user's last one, so they just went offline. */
  removeSocket(userId, socket) {
    const sockets = this.sockets.get(userId);
    if (!sockets?.delete(socket) || sockets.size > 0) return false;
    this.sockets.delete(userId);
    return true;
  }

  /** Forgets users nobody has heard from for a long time. They are recreated from their token. */
  sweepUsers() {
    const cutoff = this.now() - this.config.userIdleTtlMs;
    for (const user of this.users.values()) {
      const inUse =
        this.isOnline(user.id) ||
        this.gameByUser.has(user.id) ||
        this.outgoingInvite.has(user.id) ||
        this.incomingInvite.has(user.id);
      if (!inUse && user.lastSeenAt < cutoff) this.users.delete(user.id);
    }
  }
}
