#!/bin/bash
set -euo pipefail

echo "=== MedicalValues Multi-Service Start ==="

BACKEND_COMPOSE="./md-values-back-end/docker/docker-compose.yml"
FRONTEND_COMPOSE="./md-values-front-end/docker/docker-compose.yml"

# Local HTTPS edge proxy (non-container)
FRONTEND_EDGE_DIR="md-values-front-end/edge-proxy"

# Ports that might have stray host processes
PORTS_TO_KILL=(3000 4200 8080 3128 443)

BACKEND_LOG_PID=""
FRONTEND_LOG_PID=""
FRONTEND_EDGE_PID=""
FRONTEND_EDGE_LOG_PID=""

# --------------------------------------------
# Helper: switch docker context to colima if available
# --------------------------------------------
ensure_docker_context() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "✖ 'docker' CLI not found. Install Docker first."
    exit 1
  fi

  local current
  current=$(docker context show 2>/dev/null || echo "default")

  if docker context ls 2>/dev/null | grep -q '^colima'; then
    if [[ "$current" != "colima" ]]; then
      echo "→ Switching Docker context to 'colima'..."
      docker context use colima >/dev/null 2>&1 || true
    fi
  fi
}

# --------------------------------------------
# Helper: ensure Docker daemon is reachable
# Tries colima start, then colima stop+start if needed
# --------------------------------------------
ensure_docker() {
  if docker info >/dev/null 2>&1; then
    return
  fi

  if command -v colima >/dev/null 2>&1; then
    echo "✖ Docker daemon not reachable. Trying to (re)start colima..."

    colima start >/dev/null 2>&1 || true

    if docker info >/dev/null 2>&1; then
      echo "→ Docker is now reachable via colima."
      return
    fi

    echo "… colima reported running but Docker is still unreachable."
    echo "→ Trying 'colima stop' followed by 'colima start'..."

    colima stop >/dev/null 2>&1 || true
    colima start >/dev/null 2>&1 || true

    if docker info >/dev/null 2>&1; then
      echo "→ Docker is now reachable after restart."
      return
    fi
  fi

  echo "✖ Docker daemon is not running or not reachable."
  echo "  Please run 'colima stop; colima start' (or start your Docker engine) manually,"
  echo "  then re-run ./start-docker.sh"
  exit 1
}

# --------------------------------------------
# Pre-flight: ensure we have sudo for nginx on 443
# --------------------------------------------
ensure_sudo_for_nginx() {
  if ! command -v nginx >/dev/null 2>&1; then
    echo "✖ 'nginx' not found on host. Install nginx to use https://mdvalues.test."
    exit 1
  fi

  echo ""
  echo "→ We need sudo once to bind nginx to port 443 for mdvalues.test"
  echo "  (you will be prompted for your password, then it is cached for a while)..."
  sudo -v || { echo "✖ sudo authentication failed"; exit 1; }
}

# --------------------------------------------
# Helper: kill any host process on a given port
# --------------------------------------------
kill_port() {
  local PORT=$1

  if ! command -v lsof >/dev/null 2>&1; then
    echo "lsof not installed; cannot auto-kill port $PORT."
    return
  fi

  local PIDS
  PIDS=$(lsof -t -i:"$PORT" 2>/dev/null || true)

  if [[ -n "$PIDS" ]]; then
    echo "→ Killing host processes on port $PORT: $PIDS"
    kill $PIDS 2>/dev/null || true
  else
    echo "→ No host process on port $PORT."
  fi
}

# --------------------------------------------
# Helper: open browser on https://mdvalues.test when frontend is ready
# --------------------------------------------
open_frontend_when_ready() {
  local HEALTH_URL="http://localhost:4200"
  local BROWSER_URL="https://mdvalues.test"

  if ! command -v curl >/dev/null 2>&1; then
    echo "curl not installed; cannot wait for frontend. Please open $BROWSER_URL manually."
    return
  fi

  echo ""
  echo "--- Waiting for frontend container at $HEALTH_URL ---"

  while true; do
    if curl -sSf "$HEALTH_URL" >/dev/null 2>&1; then
      echo "→ Frontend is responding at $HEALTH_URL"

      if command -v open >/dev/null 2>&1; then
        echo "→ Opening browser (macOS 'open') at $BROWSER_URL"
        open "$BROWSER_URL" >/dev/null 2>&1 || true
      elif command -v xdg-open >/dev/null 2>&1; then
        echo "→ Opening browser (xdg-open) at $BROWSER_URL"
        xdg-open "$BROWSER_URL" >/dev/null 2>&1 || true
      else
        echo "Please open this URL in your browser: $BROWSER_URL"
      fi

      return
    fi

    sleep 1
  done
}

# --------------------------------------------
# Start local HTTPS edge proxy (mdvalues.test)
# --------------------------------------------
start_frontend_edge_proxy() {
  (
    cd "$FRONTEND_EDGE_DIR" || exit
    echo "[FRONTEND_EDGE] Preparing Nginx edge proxy (mdvalues.test)..."
    mkdir -p logs

    # Test config
    nginx -p "$(pwd)/" -c nginx-mdvalues.conf -t 2>&1 | sed -e "s/^/[FRONTEND_EDGE_TEST] /"

    echo "[FRONTEND_EDGE] Starting Nginx edge proxy on 443..."
    # sudo auth is already cached by ensure_sudo_for_nginx
    sudo nginx -p "$(pwd)/" -c nginx-mdvalues.conf -g 'daemon off;' \
      2>&1 | sed -e "s/^/[FRONTEND_EDGE] /"
  ) &
  FRONTEND_EDGE_PID=$!

  # Log tailer
  (
    cd "$FRONTEND_EDGE_DIR" || exit
    mkdir -p logs
    touch logs/mdvalues-error.log logs/mdvalues-access.log
    tail -F logs/mdvalues-error.log logs/mdvalues-access.log 2>&1 | sed -e "s/^/[FRONTEND_EDGE_LOG] /"
  ) &
  FRONTEND_EDGE_LOG_PID=$!
}

# --------------------------------------------
# Graceful shutdown on CTRL+C
# --------------------------------------------
shutdown() {
  echo ""
  echo "=== Shutting down MedicalValues containers & edge proxy ==="

  trap - INT

  set +e
  if [[ -n "${BACKEND_LOG_PID}" ]]; then
    kill "${BACKEND_LOG_PID}" 2>/dev/null || true
  fi
  if [[ -n "${FRONTEND_LOG_PID}" ]]; then
    kill "${FRONTEND_LOG_PID}" 2>/dev/null || true
  fi
  if [[ -n "${FRONTEND_EDGE_LOG_PID}" ]]; then
    kill "${FRONTEND_EDGE_LOG_PID}" 2>/dev/null || true
  fi
  if [[ -n "${FRONTEND_EDGE_PID}" ]]; then
    kill "${FRONTEND_EDGE_PID}" 2>/dev/null || true
  fi

  docker-compose -f "$BACKEND_COMPOSE" down --remove-orphans || true
  docker-compose -f "$FRONTEND_COMPOSE" down --remove-orphans || true
  set -e

  echo "All containers and local proxies stopped."
  exit 0
}

trap shutdown INT

# --------------------------------------------
# MAIN
# --------------------------------------------

ensure_docker_context
ensure_docker
ensure_sudo_for_nginx   # <-- clean, foreground sudo prompt here

echo ""
echo "--- Cleaning old host processes on 3000, 4200, 8080, 3128, 443 ---"
for PORT in "${PORTS_TO_KILL[@]}"; do
  kill_port "$PORT"
done

echo ""
echo "--- Starting backend container ---"
docker-compose -f "$BACKEND_COMPOSE" up -d

echo ""
echo "--- Starting frontend container ---"
docker-compose -f "$FRONTEND_COMPOSE" up -d

echo ""
echo "--- Starting local HTTPS edge proxy (mdvalues.test → localhost:4200) ---"
start_frontend_edge_proxy

echo ""
echo "=== All containers running ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Kick off background watcher that opens browser once 4200 responds
open_frontend_when_ready &

echo ""
echo "=== Streaming logs (press CTRL+C to stop all) ==="

docker-compose -f "$BACKEND_COMPOSE" logs -f &
BACKEND_LOG_PID=$!

docker-compose -f "$FRONTEND_COMPOSE" logs -f &
FRONTEND_LOG_PID=$!

# Wait until logs exit or user hits CTRL+C (which triggers shutdown)
wait "$BACKEND_LOG_PID" "$FRONTEND_LOG_PID"
