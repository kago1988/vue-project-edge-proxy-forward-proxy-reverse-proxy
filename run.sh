#!/bin/bash
set -euo pipefail

# -------------------------------------------
# CONFIG
# -------------------------------------------

BACKEND_DIR="md-values-back-end/back-end"
BACKEND_PROXY_DIR="md-values-back-end/reverse-proxy"

FRONTEND_DIR="md-values-front-end/front-end"
FRONTEND_PROXY_DIR="md-values-front-end/forward-proxy"
FRONTEND_EDGE_DIR="md-values-front-end/edge-proxy"  # HTTPS edge proxy for mdvalues.test

BACKEND_PORT=3000
REVERSE_PROXY_PORT=8080
FORWARD_PROXY_PORT=3128
FRONTEND_PORT=4200
FRONTEND_EDGE_PORT=443   # nginx-mdvalues.conf listens here (mdvalues.test)

BACKEND_PID=""
BACKEND_PROXY_PID=""
BACKEND_PROXY_LOG_PID=""
FRONTEND_PID=""
FRONTEND_PROXY_PID=""
FRONTEND_PROXY_LOG_PID=""
FRONTEND_EDGE_PID=""
FRONTEND_EDGE_LOG_PID=""
FRONTEND_BUILD_DIR=""

# -------------------------------------------
# FUNCTIONS
# -------------------------------------------

kill_port() {
  local PORT=$1
  echo "Checking for existing processes on port $PORT..."
  local PIDS
  PIDS=$(lsof -t -i:"$PORT" 2>/dev/null || echo "")

  if [[ -n "$PIDS" ]]; then
    echo "Killing processes on port $PORT: $PIDS"
    kill -9 $PIDS 2>/dev/null || true
  else
    echo "No process running on port $PORT."
  fi
}

ctrl_c() {
  echo ""
  echo "Stopping backend, proxies, edge & frontend..."
  set +e

  [[ -n "$FRONTEND_EDGE_LOG_PID" ]]    && kill "$FRONTEND_EDGE_LOG_PID" 2>/dev/null || true
  [[ -n "$FRONTEND_PROXY_LOG_PID" ]]   && kill "$FRONTEND_PROXY_LOG_PID" 2>/dev/null || true
  [[ -n "$BACKEND_PROXY_LOG_PID" ]]    && kill "$BACKEND_PROXY_LOG_PID" 2>/dev/null || true

  [[ -n "$FRONTEND_EDGE_PID" ]]        && sudo kill "$FRONTEND_EDGE_PID" 2>/dev/null || true
  [[ -n "$FRONTEND_PROXY_PID" ]]       && kill "$FRONTEND_PROXY_PID" 2>/dev/null || true
  [[ -n "$BACKEND_PROXY_PID" ]]        && kill "$BACKEND_PROXY_PID" 2>/dev/null || true

  [[ -n "$FRONTEND_PID" ]]             && kill "$FRONTEND_PID" 2>/dev/null || true
  [[ -n "$BACKEND_PID" ]]              && kill "$BACKEND_PID" 2>/dev/null || true

  echo "Shutdown complete."
  exit 0
}

wait_for_frontend() {
  echo "Waiting for frontend at http://127.0.0.1:${FRONTEND_PORT} ..."

  while true; do
    if [[ -n "$FRONTEND_PID" ]] && ! kill -0 "$FRONTEND_PID" 2>/dev/null; then
      echo "Frontend process exited unexpectedly."
      return
    fi

    if curl -sSf "http://127.0.0.1:${FRONTEND_PORT}" >/dev/null 2>&1; then
      echo "Frontend is responding."

      if command -v open >/dev/null 2>&1; then
        echo "Opening browser at https://mdvalues.test"
        open "https://mdvalues.test"
      elif command -v xdg-open >/dev/null 2>&1; then
        xdg-open "https://mdvalues.test" >/dev/null 2>&1 || true
      else
        echo "Please open https://mdvalues.test manually in your browser."
      fi
      return
    fi

    sleep 1
  done
}

# -------------------------------------------
# MAIN
# -------------------------------------------

echo "=== MedicalValues Dev Runner (build + static frontend) ==="

echo "→ Priming sudo (for Nginx on port 443)..."
sudo -v

kill_port "$BACKEND_PORT"
kill_port "$REVERSE_PROXY_PORT"
kill_port "$FORWARD_PROXY_PORT"
kill_port "$FRONTEND_PORT"
kill_port "$FRONTEND_EDGE_PORT"

echo ""

# 1) Build Angular frontend (blocking)
(
  cd "$FRONTEND_DIR" || exit
  echo "[FRONTEND_BUILD] Running 'ng build'..."
  ng build 2>&1 | sed -e "s/^/[FRONTEND_BUILD] /"
)

# Your structure:
# md-values-front-end/front-end/dist/medicalvalues-front-end[/browser]
FRONTEND_BUILD_ROOT="${FRONTEND_DIR}/dist/medicalvalues-front-end"
if [[ -d "${FRONTEND_BUILD_ROOT}/browser" ]]; then
  FRONTEND_BUILD_DIR="${FRONTEND_BUILD_ROOT}/browser"
else
  FRONTEND_BUILD_DIR="${FRONTEND_BUILD_ROOT}"
fi

if [[ ! -d "$FRONTEND_BUILD_DIR" ]]; then
  echo "✖ Built frontend directory not found: $FRONTEND_BUILD_DIR"
  echo "  Check outputPath in angular.json and adjust run.sh if needed."
  exit 1
fi

echo "[FRONTEND_BUILD] Build finished. Serving from: $FRONTEND_BUILD_DIR"
echo ""

# 2) Start Backend (NestJS)
(
  cd "$BACKEND_DIR" || exit
  echo "[BACKEND] Starting NestJS..."
  npm run start:dev 2>&1 | sed -e "s/^/[BACKEND] /"
) &
BACKEND_PID=$!
echo "BACKEND_PID = $BACKEND_PID"

# 3) Backend Reverse Proxy (Nginx on 8080)
(
  cd "$BACKEND_PROXY_DIR" || exit
  echo "[BACKEND_PROXY] Preparing Nginx reverse proxy..."
  mkdir -p logs

  nginx -p "$(pwd)/" -c nginx.conf -t 2>&1 | sed -e "s/^/[BACKEND_PROXY_TEST] /"

  echo "[BACKEND_PROXY] Starting Nginx reverse proxy (daemon off)..."
  nginx -p "$(pwd)/" -c nginx.conf -g 'daemon off;' 2>&1 | sed -e "s/^/[BACKEND_PROXY] /"
) &
BACKEND_PROXY_PID=$!
echo "BACKEND_PROXY_PID = $BACKEND_PROXY_PID"

(
  cd "$BACKEND_PROXY_DIR" || exit
  mkdir -p logs
  touch logs/error.log logs/access.log
  tail -F logs/error.log logs/access.log 2>&1 | sed -e "s/^/[BACKEND_PROXY_LOG] /"
) &
BACKEND_PROXY_LOG_PID=$!
echo "BACKEND_PROXY_LOG_PID = $BACKEND_PROXY_LOG_PID"

# 4) Static frontend on 127.0.0.1:4200
(
  cd "$FRONTEND_BUILD_DIR" || exit
  echo "[FRONTEND] Serving built frontend on http://127.0.0.1:${FRONTEND_PORT} ..."
  # Requires: npm install --save-dev http-server   (in FRONTEND_DIR)
  npx http-server . -a 127.0.0.1 -p "$FRONTEND_PORT" 2>&1 | sed -e "s/^/[FRONTEND] /"
) &
FRONTEND_PID=$!
echo "FRONTEND_PID = $FRONTEND_PID"

# 5) Frontend Forward Proxy (Nginx on 3128)
(
  cd "$FRONTEND_PROXY_DIR" || exit
  echo "[FRONTEND_PROXY] Preparing Nginx forward proxy..."
  mkdir -p logs

  nginx -p "$(pwd)/" -c nginx.conf -t 2>&1 | sed -e "s/^/[FRONTEND_PROXY_TEST] /"

  echo "[FRONTEND_PROXY] Starting Nginx forward proxy (daemon off)..."
  nginx -p "$(pwd)/" -c nginx.conf -g 'daemon off;' 2>&1 | sed -e "s/^/[FRONTEND_PROXY] /"
) &
FRONTEND_PROXY_PID=$!
echo "FRONTEND_PROXY_PID = $FRONTEND_PROXY_PID"

(
  cd "$FRONTEND_PROXY_DIR" || exit
  mkdir -p logs
  touch logs/error.log logs/access.log
  tail -F logs/error.log logs/access.log 2>&1 | sed -e "s/^/[FRONTEND_PROXY_LOG] /"
) &
FRONTEND_PROXY_LOG_PID=$!
echo "FRONTEND_PROXY_LOG_PID = $FRONTEND_PROXY_LOG_PID"

# 6) Edge Reverse Proxy (HTTPS mdvalues.test → 4200) on 443 via sudo
(
  cd "$FRONTEND_EDGE_DIR" || exit
  echo "[FRONTEND_EDGE] Preparing Nginx edge reverse proxy (mdvalues.test)..."
  mkdir -p logs

  nginx -p "$(pwd)/" -c nginx-mdvalues.conf -t 2>&1 | sed -e "s/^/[FRONTEND_EDGE_TEST] /"

  echo "[FRONTEND_EDGE] Starting Nginx edge reverse proxy on 443 (requires sudo)..."
  sudo nginx -p "$(pwd)/" -c nginx-mdvalues.conf -g 'daemon off;' 2>&1 | sed -e "s/^/[FRONTEND_EDGE] /"
) &
FRONTEND_EDGE_PID=$!
echo "FRONTEND_EDGE_PID = $FRONTEND_EDGE_PID"

(
  cd "$FRONTEND_EDGE_DIR" || exit
  mkdir -p logs
  touch logs/error.log logs/access.log
  tail -F logs/error.log logs/access.log 2>&1 | sed -e "s/^/[FRONTEND_EDGE_LOG] /"
) &
FRONTEND_EDGE_LOG_PID=$!
echo "FRONTEND_EDGE_LOG_PID = $FRONTEND_EDGE_LOG_PID"

echo ""
echo "Backend PID:               $BACKEND_PID"
echo "Backend Proxy PID:         $BACKEND_PROXY_PID"
echo "Backend Proxy Log PID:     $BACKEND_PROXY_LOG_PID"
echo "Frontend Proxy PID:        $FRONTEND_PROXY_PID"
echo "Frontend Proxy Log PID:    $FRONTEND_PROXY_LOG_PID"
echo "Frontend Edge PID:         $FRONTEND_EDGE_PID"
echo "Frontend Edge Log PID:     $FRONTEND_EDGE_LOG_PID"
echo "Frontend PID (static):     $FRONTEND_PID"
echo ""

trap ctrl_c INT

wait_for_frontend &

echo "Press CTRL+C to stop all servers."
wait
