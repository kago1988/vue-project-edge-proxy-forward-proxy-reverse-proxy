#!/bin/sh
set -e

echo "[BACKEND] Starting Nginx reverse proxy..."
cd /usr/src/app/reverse-proxy
mkdir -p logs
nginx -p "$(pwd)/" -c nginx-docker.conf

echo "[BACKEND] Starting NestJS..."
cd /usr/src/app/back-end
node dist/main.js
