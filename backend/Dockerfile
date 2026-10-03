# Multi-stage production Dockerfile for FunDice backend (from backend directory context)

# ------------------------------------------------------------------------------
# Stage 1: Install production dependencies
# ------------------------------------------------------------------------------
FROM node:22-alpine AS deps

WORKDIR /app

# Copy dependency definitions only to leverage Docker layer caching
COPY package*.json ./

# Install production dependencies only with audit and fund telemetry disabled
RUN npm ci --omit=dev --no-audit --no-fund \
    && npm cache clean --force

# ------------------------------------------------------------------------------
# Stage 2: Minimal Production Runtime
# ------------------------------------------------------------------------------
FROM node:22-alpine AS runner

WORKDIR /app

# Production environment defaults
ENV NODE_ENV=production
ENV PORT=3000

# Security: Run as unprivileged node user built into alpine
USER node

# Copy installed production node_modules from deps stage
COPY --chown=node:node --from=deps /app/node_modules ./node_modules

# Copy only relevant backend application source and static dashboard
COPY --chown=node:node package.json ./
COPY --chown=node:node src/ ./src/
COPY --chown=node:node public/ ./public/

# Expose default port (Render will override PORT at runtime)
EXPOSE 3000

# Health check using built-in busybox wget
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:${PORT}/healthz || exit 1

# Start backend server
CMD ["node", "src/server.js"]
