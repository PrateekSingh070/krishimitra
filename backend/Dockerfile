# KrishiMitra API container image.
# node-oracledb runs in Thin mode, so no Oracle Instant Client is required.
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev --no-audit --no-fund

FROM node:20-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app

# Run as a non-root user.
RUN addgroup -S app && adduser -S app -G app

COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src

# ATP wallet is mounted at runtime (read-only) and TNS_ADMIN points to it.
# Secrets (DB password, JWT) are injected from OCI Vault as env vars.
ENV TNS_ADMIN=/app/wallet
EXPOSE 3000
USER app

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1

CMD ["node", "src/server.js"]
