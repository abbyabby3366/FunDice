import http from 'node:http';
import express from 'express';
import helmet from 'helmet';
import { rateLimit } from 'express-rate-limit';
import { loadConfig } from './config.js';
import { Registry } from './state.js';
import { createTokens } from './auth.js';
import { createTimers } from './timers.js';
import { createErrorHandler, notFoundHandler, AppError } from './errors.js';
import { createWsHub } from './ws.js';
import { createRoutes } from './routes.js';

export function createApp({ config, registry, tokens, wsHub, now }) {
  const app = express();

  app.set('trust proxy', 1);
  app.disable('x-powered-by');
  app.use(helmet());
  app.use(express.json({ limit: '10kb' }));

  // Health check endpoint (SPEC 3.2: no auth)
  app.get('/healthz', (req, res) => {
    res.json({
      ok: true,
      uptime: Math.round(process.uptime() * 10) / 10,
      version: '1.0.0',
    });
  });

  // Global rate limiter (300 req / 5 min / IP)
  app.use(
    rateLimit({
      windowMs: config.limits.global.windowMs,
      limit: config.limits.global.limit,
      standardHeaders: true,
      legacyHeaders: false,
      handler: (req, res, next, opts) => {
        const retryAfter = Math.ceil(opts.windowMs / 1000);
        next(new AppError('rate_limited', 'Too many requests. Please slow down.', { retryAfter }));
      },
    }),
  );

  // Mount API endpoints
  app.use('/api', createRoutes({ config, registry, tokens, wsHub, now }));

  // 404 & Central Error Handling
  app.use(notFoundHandler);
  app.use(createErrorHandler(console));

  return app;
}

export function startServer(env = process.env) {
  const config = loadConfig(env);
  const now = () => Date.now();
  const timers = createTimers({ onError: console.error });
  const registry = new Registry({ config, now });
  const tokens = createTokens({ jwtSecret: config.jwtSecret, tokenTtlSec: config.tokenTtlSec });

  let wsHub;
  const hubProxy = {
    sendToUser: (...args) => wsHub?.sendToUser(...args),
    broadcastGame: (...args) => wsHub?.broadcastGame(...args),
  };

  const app = createApp({ config, registry, tokens, wsHub: hubProxy, now });
  const server = http.createServer(app);

  wsHub = createWsHub({ config, registry, tokens, timers, now });

  // Handle WebSocket upgrade at /ws
  server.on('upgrade', (req, socket, head) => {
    const { pathname } = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
    if (pathname === '/ws') {
      wsHub.wss.handleUpgrade(req, socket, head, (ws) => {
        wsHub.wss.emit('connection', ws, req);
      });
    } else {
      socket.destroy();
    }
  });

  // Periodic sweep of idle users and expired invites
  timers.every(config.sweepIntervalMs, () => {
    registry.sweepUsers();

    const nowMs = now();
    for (const [id, inv] of registry.invites.entries()) {
      if (inv.status === 'pending' && new Date(inv.expiresAt).getTime() <= nowMs) {
        inv.status = 'expired';
        registry.outgoingInvite.delete(inv.from.id);
        registry.incomingInvite.delete(inv.to.id);
        wsHub.sendToUser(inv.from.id, { type: 'invite_update', invite: inv });
        wsHub.sendToUser(inv.to.id, { type: 'invite_update', invite: inv });
      }
    }
  });

  server.listen(config.port, () => {
    console.log(`FunDice backend running on port ${config.port} (env: ${config.nodeEnv})`);
  });

  const shutdown = () => {
    console.log('Shutting down FunDice backend...');
    timers.clearAll();
    wsHub.closeAll(1012, 'Service Restart');
    server.close(() => {
      console.log('Server stopped.');
      process.exit(0);
    });
  };

  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);

  return { server, app, config, registry, wsHub, timers };
}

// Start immediately when executed directly
startServer();
