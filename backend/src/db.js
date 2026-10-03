import dns from 'node:dns';
import { MongoClient } from 'mongodb';

// Ensure reliable SRV lookup across varied router/DNS configurations
try {
  dns.setServers(['8.8.8.8', '1.1.1.1', ...dns.getServers()]);
} catch {
  // Ignore DNS override errors if in restricted environment
}

/**
 * MongoDB persistence layer for FunDice.
 * Persists registered player profiles, lifetime statistics, global roll histories,
 * and finished match records.
 */
export class Database {
  constructor(uri) {
    this.uri = uri;
    this.client = null;
    this.db = null;
    this.status = uri ? 'connecting' : 'disabled';
    this.error = null;
  }

  async connect() {
    if (!this.uri) {
      this.status = 'disabled';
      return;
    }
    try {
      this.client = new MongoClient(this.uri, {
        serverSelectionTimeoutMS: 5000,
        connectTimeoutMS: 10000,
      });
      await this.client.connect();
      this.db = this.client.db();
      this.status = 'connected';
      this.error = null;
      console.log(`Connected to MongoDB Atlas: database "${this.db.databaseName}"`);
      await this._initIndexes();
    } catch (err) {
      this.status = 'error';
      this.error = err.message;
      console.error('MongoDB Atlas connection error:', err.message);
    }
  }

  async _initIndexes() {
    if (!this.db) return;
    try {
      await this.db.collection('users').createIndex({ id: 1 }, { unique: true });
      await this.db.collection('rolls').createIndex({ userId: 1, at: -1 });
      await this.db.collection('games').createIndex({ id: 1 }, { unique: true });
      await this.db.collection('games').createIndex({ finishedAt: -1 });
    } catch (err) {
      console.warn('MongoDB index initialization note:', err.message);
    }
  }

  async saveUser(user) {
    if (!this.db) return;
    try {
      const atIso = new Date(user.lastSeenAt || Date.now()).toISOString();
      const createdIso = new Date(user.createdAt || Date.now()).toISOString();
      await this.db.collection('users').updateOne(
        { id: user.id },
        {
          $set: {
            name: user.name,
            lastSeenAt: atIso,
          },
          $setOnInsert: {
            id: user.id,
            createdAt: createdIso,
            stats: {
              gamesPlayed: 0,
              gamesWon: 0,
              gamesLost: 0,
              totalRolls: 0,
            },
          },
        },
        { upsert: true },
      );
    } catch (err) {
      console.error('db.saveUser error:', err.message);
    }
  }

  async loadUser(id) {
    if (!this.db) return null;
    try {
      return await this.db.collection('users').findOne({ id });
    } catch (err) {
      console.error('db.loadUser error:', err.message);
      return null;
    }
  }

  async recordRoll({ userId, userName, seq, dice, at }) {
    if (!this.db) return;
    try {
      const atIso = new Date(at).toISOString();
      await this.db.collection('rolls').insertOne({
        userId,
        userName,
        seq,
        dice,
        at: atIso,
      });
      await this.db.collection('users').updateOne(
        { id: userId },
        {
          $inc: { 'stats.totalRolls': 1 },
          $set: { lastSeenAt: atIso },
        },
      );
    } catch (err) {
      console.error('db.recordRoll error:', err.message);
    }
  }

  async saveFinishedGame(game, nowMs) {
    if (!this.db || game.status !== 'finished') return;
    try {
      const finishedIso = new Date(nowMs).toISOString();
      const winnerId = game.winner;
      const loserId = game.players.find((id) => id !== winnerId);

      const record = {
        id: game.id,
        round: game.round,
        players: game.players.map((id) => ({
          id,
          name: game.seats[id]?.name || id,
          finalDiceCount: game.seats[id]?.diceCount ?? 0,
        })),
        winner: winnerId
          ? { id: winnerId, name: game.seats[winnerId]?.name || winnerId }
          : null,
        loser: loserId
          ? { id: loserId, name: game.seats[loserId]?.name || loserId }
          : null,
        endReason: game.endReason,
        createdAt: new Date(game.createdAt).toISOString(),
        finishedAt: finishedIso,
      };

      await this.db.collection('games').updateOne(
        { id: game.id },
        { $set: record },
        { upsert: true },
      );

      if (winnerId) {
        await this.db.collection('users').updateOne(
          { id: winnerId },
          { $inc: { 'stats.gamesPlayed': 1, 'stats.gamesWon': 1 } },
        );
      }
      if (loserId) {
        await this.db.collection('users').updateOne(
          { id: loserId },
          { $inc: { 'stats.gamesPlayed': 1, 'stats.gamesLost': 1 } },
        );
      }
    } catch (err) {
      console.error('db.saveFinishedGame error:', err.message);
    }
  }

  async getStats() {
    if (!this.db) {
      return {
        status: this.status,
        database: null,
        usersCount: 0,
        rollsCount: 0,
        gamesCount: 0,
        error: this.error,
      };
    }
    try {
      const [usersCount, rollsCount, gamesCount] = await Promise.all([
        this.db.collection('users').countDocuments(),
        this.db.collection('rolls').countDocuments(),
        this.db.collection('games').countDocuments(),
      ]);
      return {
        status: this.status,
        database: this.db.databaseName,
        usersCount,
        rollsCount,
        gamesCount,
        error: null,
      };
    } catch (err) {
      return {
        status: 'error',
        database: this.db?.databaseName || null,
        usersCount: 0,
        rollsCount: 0,
        gamesCount: 0,
        error: err.message,
      };
    }
  }

  async close() {
    if (this.client) {
      await this.client.close();
      this.status = 'disconnected';
    }
  }
}
