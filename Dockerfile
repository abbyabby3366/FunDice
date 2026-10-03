# Production Dockerfile for FunDice backend (from monorepo root)
FROM node:22-alpine

WORKDIR /app

# Install backend production dependencies only
COPY backend/package*.json ./
RUN npm ci --omit=dev

# Copy backend application source
COPY backend/src/ ./src/

# Environment defaults
ENV NODE_ENV=production

# Expose default port (Render will override PORT at runtime)
EXPOSE 3000

# Start backend server
CMD ["node", "src/server.js"]
