# Production Dockerfile for FunDice backend (Node >= 22)
FROM node:22-alpine

WORKDIR /app

# Install production dependencies only
COPY package*.json ./
RUN npm ci --omit=dev

# Copy application source
COPY src/ ./src/

# Environment defaults
ENV NODE_ENV=production

# Expose default port (Render will override PORT at runtime)
EXPOSE 3000

# Start backend server
CMD ["node", "src/server.js"]
