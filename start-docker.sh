#!/bin/bash
set -euo pipefail

echo "=== MedicalValues Multi-Service Start ==="

BACKEND_COMPOSE="./md-values-back-end/docker/docker-compose.yml"
FRONTEND_COMPOSE="./md-values-front-end/docker/docker-compose.yml"

# Ports that might have stray host processes
PORTS_TO_KILL=(3000 4200 8080 3128)

BACKEND_LOG_PID=""
FRONTEND_LOG_PID=""

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
# Helper: open browser on localhost:4200 when ready
# --------------------------------------------
open_frontend_when_ready() {
  local URL="http://localhost:4200"

  if ! command -v curl >/dev/null 2>&1; then
    echo "curl not installed; cannot wait for frontend. Please open $URL manually."
    return
  fi

  echo ""
  echo "--- Waiting for frontend at $URL ---"

  while true; do
    # 'set -e' does not abort on failed commands inside 'if' condition bodies
    if curl -sSf "$URL" >/dev/null 2>&1; then
      echo "→ Frontend is responding at $URL"

      # macOS
      if command -v open >/dev/null 2>&1; then
        echo "→ Opening browser (macOS 'open')..."
        open "$URL" >/dev/null 2>&1 || true
      # Linux / others
      elif command -v xdg-open >/dev/null 2>&1; then
        echo "→ Opening browser (xdg-open)..."
        xdg-open "$URL" >/dev/null 2>&1 || true
      else
        echo "Please open this URL in your browser: $URL"
      fi

      return
    fi

    sleep 1
  done
}

# --------------------------------------------
# Graceful shutdown on CTRL+C
# --------------------------------------------
shutdown() {
  echo ""
  echo "=== Shutting down MedicalValues containers ==="

  trap - INT

  set +e
  if [[ -n "${BACKEND_LOG_PID}" ]]; then
    kill "${BACKEND_LOG_PID}" 2>/dev/null || true
  fi
  if [[ -n "${FRONTEND_LOG_PID}" ]]; then
    kill "${FRONTEND_LOG_PID}" 2>/dev/null || true
  fi

  docker-compose -f "$BACKEND_COMPOSE" down --remove-orphans || true
  docker-compose -f "$FRONTEND_COMPOSE" down --remove-orphans || true
  set -e

  echo "All containers stopped."
  exit 0
}

trap shutdown INT

# --------------------------------------------
# MAIN
# --------------------------------------------

ensure_docker_context
ensure_docker

echo ""
echo "--- Cleaning old host processes on 3000, 4200, 8080, 3128 ---"
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
