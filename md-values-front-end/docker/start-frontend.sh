#!/bin/sh
set -e

echo "[FRONTEND] Starting Nginx forward proxy..."
cd /usr/src/app/forward-proxy
mkdir -p logs
nginx -p "$(pwd)/" -c nginx-docker.conf

echo "[FRONTEND] Starting Angular dev server..."
cd /usr/src/app/front-end
npm run start -- --host 0.0.0.0 --port 4200 --proxy-config proxy.conf.json
