# Backend container: NestJS + Nginx reverse proxy

FROM node:20-alpine AS builder

WORKDIR /usr/src/app

# Install deps & build Nest app
COPY back-end/package*.json ./back-end/
WORKDIR /usr/src/app/back-end
RUN npm ci

COPY back-end ./
RUN npm run build

# --- Runtime image ---
FROM node:20-alpine

RUN apk add --no-cache nginx bash

WORKDIR /usr/src/app

# NestJS runtime deps
COPY back-end/package*.json ./back-end/
WORKDIR /usr/src/app/back-end
RUN npm ci --omit=dev

# Copy built dist from builder
COPY --from=builder /usr/src/app/back-end/dist ./dist

# Copy reverse proxy config
WORKDIR /usr/src/app
COPY reverse-proxy ./reverse-proxy
RUN mkdir -p reverse-proxy/logs

# Start script
COPY docker/start-backend.sh /usr/local/bin/start-backend.sh
RUN chmod +x /usr/local/bin/start-backend.sh

# Expose NestJS (3000) and reverse proxy (8080)
EXPOSE 3000 8080

CMD ["start-backend.sh"]
