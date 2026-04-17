# =============================================================================
# Stage 1 — Builder (Bun for fast TypeScript compilation)
# =============================================================================
FROM oven/bun:1-alpine AS builder
LABEL org.opencontainers.image.source=https://github.com/delorenj/mcp-server-trello

WORKDIR /app

# Build dependencies (only needed at compile time)
RUN apk add --no-cache python3 make g++

COPY package.json bun.lock ./
RUN bun install --frozen

COPY . .
RUN bun run build

# =============================================================================
# Stage 2 — Runtime (Node.js 18 Alpine — ~60MB idle vs Bun's ~200MB)
# =============================================================================
FROM node:18-alpine AS release

WORKDIR /app

# Copy compiled output and lockfile from builder
COPY --from=builder /app/build ./build
COPY --from=builder /app/package.json ./
COPY --from=builder /app/package-lock.json ./

# Install production dependencies with npm
RUN npm ci --omit=dev

# Install supergateway — pinned to stable version
RUN npm install -g supergateway@3.4.3

ENV NODE_ENV=production

EXPOSE 8000

# supergateway bridges Streamable HTTP <-> MCP stdio
# Both processes run on Node.js — single runtime, minimal and predictable footprint
# TRELLO_API_KEY and TRELLO_TOKEN come from Railway env vars
CMD ["sh", "-c", "supergateway --stdio 'node /app/build/index.js' --outputTransport streamableHttp --port ${PORT:-8000}"]
