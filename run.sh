#!/bin/bash

# -------------------------------------------
# CONFIG
# -------------------------------------------

BACKEND_DIR="md-values-back-end/back-end"
BACKEND_PROXY_DIR="md-values-back-end/reverse-proxy"
FRONTEND_DIR="md-values-front-end/front-end"
FRONTEND_PROXY_DIR="md-values-front-end/forward-proxy"

BACKEND_PORT=3000
REVERSE_PROXY_PORT=8080
FORWARD_PROXY_PORT=3128
FRONTEND_PORT=4200

# -------------------------------------------
# FUNCTIONS
# -------------------------------------------

kill_port() {
  local PORT=$1
  echo "Checking for existing processes on port $PORT..."
  PIDS=$(lsof -t -i:"$PORT" 2>/dev/null || echo "")

  if [ -n "$PIDS" ]; then
    echo "Killing processes on port $PORT: $PIDS"
    kill -9 $PIDS 2>/dev/null || true
  else
    echo "No process running on port $PORT."
  fi
}

ctrl_c() {
  echo ""
  echo "Stopping backend, proxies & frontend..."
  kill "$BACKEND_PID" "$BACKEND_PROXY_PID" "$FRONTEND_PROXY_PID" \
       "$BACKEND_PROXY_LOG_PID" "$FRONTEND_PROXY_LOG_PID" "$FRONTEND_PID" \
       2>/dev/null || true
  echo "Shutdown complete."
  exit 0
}

wait_for_frontend() {
  echo "Waiting for Angular at http://localhost:${FRONTEND_PORT} ..."

  while true; do
    if ! kill -0 "$FRONTEND_PID" 2>/dev/null; then
      echo "Angular process exited unexpectedly."
      return
    fi

    if curl -sSf "http://localhost:${FRONTEND_PORT}" >/dev/null 2>&1; then
      echo "Angular is running."

      if command -v open >/dev/null 2>&1; then
        echo "Opening browser at http://localhost:${FRONTEND_PORT}"
        open "http://localhost:${FRONTEND_PORT}"
      fi
      return
    fi

    sleep 1
  done
}

# -------------------------------------------
# MAIN
# -------------------------------------------

echo "=== MedicalValues Dev Runner ==="

kill_port "$BACKEND_PORT"
kill_port "$REVERSE_PROXY_PORT"
kill_port "$FORWARD_PROXY_PORT"
kill_port "$FRONTEND_PORT"

echo ""

# Start Backend (NestJS)
(
  cd "$BACKEND_DIR" || exit
  echo "[BACKEND] Starting NestJS..."
  npm run start:dev 2>&1 | sed -e "s/^/[BACKEND] /"
) &
BACKEND_PID=$!

# Start Backend Reverse Proxy (Nginx on 8080)
(
  cd "$BACKEND_PROXY_DIR" || exit
  echo "[BACKEND_PROXY] Preparing Nginx reverse proxy..."
  mkdir -p logs

  # Test config first
  nginx -p "$(pwd)/" -c nginx.conf -t 2>&1 | sed -e "s/^/[BACKEND_PROXY_TEST] /"

  echo "[BACKEND_PROXY] Starting Nginx reverse proxy (daemon off)..."
  nginx -p "$(pwd)/" -c nginx.conf -g 'daemon off;' 2>&1 | sed -e "s/^/[BACKEND_PROXY] /"
) &
BACKEND_PROXY_PID=$!

# Live stream logs for reverse proxy
(
  cd "$BACKEND_PROXY_DIR" || exit
  mkdir -p logs
  touch logs/error.log logs/access.log
  tail -F logs/error.log logs/access.log 2>&1 | sed -e "s/^/[BACKEND_PROXY_LOG] /"
) &
BACKEND_PROXY_LOG_PID=$!

# Start Frontend (Angular)
(
  cd "$FRONTEND_DIR" || exit
  echo "[FRONTEND] Starting Angular..."
  ng serve --port "$FRONTEND_PORT" --proxy-config proxy.conf.json 2>&1 | sed -e "s/^/[FRONTEND] /"
) &
FRONTEND_PID=$!

# Start Frontend Forward Proxy (Nginx on 3128)
(
  cd "$FRONTEND_PROXY_DIR" || exit
  echo "[FRONTEND_PROXY] Preparing Nginx forward proxy..."
  mkdir -p logs

  # Test config first
  nginx -p "$(pwd)/" -c nginx.conf -t 2>&1 | sed -e "s/^/[FRONTEND_PROXY_TEST] /"

  echo "[FRONTEND_PROXY] Starting Nginx forward proxy (daemon off)..."
  nginx -p "$(pwd)/" -c nginx.conf -g 'daemon off;' 2>&1 | sed -e "s/^/[FRONTEND_PROXY] /"
) &
FRONTEND_PROXY_PID=$!

# Live stream logs for forward proxy
(
  cd "$FRONTEND_PROXY_DIR" || exit
  mkdir -p logs
  touch logs/error.log logs/access.log
  tail -F logs/error.log logs/access.log 2>&1 | sed -e "s/^/[FRONTEND_PROXY_LOG] /"
) &
FRONTEND_PROXY_LOG_PID=$!

echo ""
echo "Backend PID:             $BACKEND_PID"
echo "Backend Proxy PID:       $BACKEND_PROXY_PID"
echo "Backend Proxy Log PID:   $BACKEND_PROXY_LOG_PID"
echo "Frontend Proxy PID:      $FRONTEND_PROXY_PID"
echo "Frontend Proxy Log PID:  $FRONTEND_PROXY_LOG_PID"
echo "Frontend PID:            $FRONTEND_PID"
echo ""

# Trap CTRL-C
trap ctrl_c INT

# Wait for frontend to become available, then open browser
wait_for_frontend &

echo "Press CTRL+C to stop all servers."
wait
