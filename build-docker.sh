#!/bin/bash
set -euo pipefail

echo "=== MedicalValues Docker Builder ==="

BACKEND_COMPOSE="./md-values-back-end/docker/docker-compose.yml"
FRONTEND_COMPOSE="./md-values-front-end/docker/docker-compose.yml"

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
  # First quick check
  if docker info >/dev/null 2>&1; then
    return
  fi

  if command -v colima >/dev/null 2>&1; then
    echo "✖ Docker daemon not reachable. Trying to (re)start colima..."

    # Simple best-effort start
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
  echo "  then re-run ./build-docker.sh"
  exit 1
}

# --------------------------------------------
# MAIN
# --------------------------------------------

# Make sure docker CLI talks to colima, if it exists
ensure_docker_context

# Make sure the daemon is actually reachable
ensure_docker

echo ""
echo "--- Removing old containers/images (if exist) ---"
docker-compose -f "$BACKEND_COMPOSE" down --rmi all --volumes --remove-orphans || true
docker-compose -f "$FRONTEND_COMPOSE" down --rmi all --volumes --remove-orphans || true

echo ""
echo "--- Building backend image ---"
docker-compose -f "$BACKEND_COMPOSE" build

echo ""
echo "--- Building frontend image ---"
docker-compose -f "$FRONTEND_COMPOSE" build

echo ""
echo "=== Build complete ==="
