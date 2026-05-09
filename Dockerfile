# syntax=docker/dockerfile:1.7

# ---------- Builder stage ----------
FROM node:22-bookworm-slim AS builder

WORKDIR /kutt

# Install heavy build dependencies needed for compiling native node modules
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 make g++ \
    && rm -rf /var/lib/apt/lists/*

# Copy package files
COPY package.json package-lock.json ./

# Install ONLY production dependencies (this matches Kutt's original setup)
RUN --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev

# Copy the rest of the source code
COPY . .

# ---------- Runtime stage ----------
FROM node:22-bookworm-slim AS runtime

# Install tini (for signal handling) and curl (for the healthcheck)
RUN apt-get update && apt-get install -y --no-install-recommends \
    tini curl \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for security
RUN groupadd --system --gid 1001 nodejs \
    && useradd --system --uid 1001 --gid nodejs nodejs

WORKDIR /kutt

# Create Kutt's required directory and give our new user ownership
RUN mkdir -p /var/lib/kutt && chown -R nodejs:nodejs /var/lib/kutt

# Copy everything from the builder stage, changing ownership to our non-root user
COPY --from=builder --chown=nodejs:nodejs /kutt ./

# Switch to the non-root user
USER nodejs

# Set production environment variables
ENV NODE_ENV=production

EXPOSE 3000

# Let AWS know if the container is healthy
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Use tini as PID 1 for proper graceful shutdown
ENTRYPOINT ["/usr/bin/tini", "--"]

# Start the app
CMD ["npm", "start"]
