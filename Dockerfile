# Use official Bun image as builder
FROM oven/bun:1-alpine AS builder
LABEL org.opencontainers.image.source=https://github.com/delorenj/mcp-server-trello

# Set the working directory to /app
WORKDIR /app

# Install build dependencies
RUN apk add --no-cache python3 make g++

# Copy package files first to leverage Docker cache
COPY package.json bun.lock ./

# Install all dependencies (including dev dependencies)
RUN bun install --frozen

# Copy the rest of the code
COPY . .

# Build TypeScript
RUN bun run build

# Use official Bun image for runtime
FROM oven/bun:1-alpine AS release

# Set the working directory to /app
WORKDIR /app

# Copy only the necessary files from builder
COPY --from=builder /app/build ./build
COPY --from=builder /app/package.json ./
COPY --from=builder /app/bun.lock ./

# Install only production dependencies without running scripts
RUN bun install --production --frozen

# Install supergateway -- wraps stdio MCP server as HTTP/SSE for Railway
RUN bun add -g supergateway

# The environment variables should be passed at runtime, not baked into the image
ENV NODE_ENV=production

# Expose port for Railway HTTP routing
EXPOSE 8000

# Run supergateway wrapping the Trello MCP stdio server
# supergateway listens on HTTP/SSE, spawns the stdio server per connection
# TRELLO_API_KEY and TRELLO_TOKEN come from Railway env vars
CMD ["sh", "-c", "supergateway --stdio 'bun /app/build/index.js' --outputTransport sse --port ${PORT:-8000}"]
