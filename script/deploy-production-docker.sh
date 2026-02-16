#!/bin/bash
set -euo pipefail

COMPOSE_FILE="docker-compose.production.yml"
BUILD_STAMP_FILE="tmp/.docker-production-build"
GIT_HEAD="$(git rev-parse HEAD)"

FORCE_BUILD=false
if [ "${1:-}" = "--force" ] || [ "${1:-}" = "-f" ]; then
  FORCE_BUILD=true
fi

should_build=true
if [ "$FORCE_BUILD" = true ]; then
  should_build=true
else
if [ -f "$BUILD_STAMP_FILE" ]; then
  LAST_BUILD_HEAD="$(cat "$BUILD_STAMP_FILE")"
  if [ "$LAST_BUILD_HEAD" = "$GIT_HEAD" ] && \
     docker image inspect chatwoot:production-web >/dev/null 2>&1 && \
     docker image inspect chatwoot:production-worker >/dev/null 2>&1; then
    should_build=false
  fi
fi
fi

if [ "$should_build" = true ]; then
  echo "=== Building production images (web, worker) ==="
  docker compose -f "$COMPOSE_FILE" build web worker
  mkdir -p "$(dirname "$BUILD_STAMP_FILE")"
  echo "$GIT_HEAD" > "$BUILD_STAMP_FILE"
else
  echo "=== Skipping build (images up-to-date for git HEAD $GIT_HEAD) ==="
fi

echo "=== Starting dependencies (postgres, redis) ==="
docker compose -f "$COMPOSE_FILE" up -d postgres redis

echo "=== Starting services ==="
docker compose -f "$COMPOSE_FILE" up -d web worker

echo "=== Deploying Apple Pay certificates ==="
./script/deploy_apple_pay_certs.sh

echo "=== Current container status ==="
docker compose -f "$COMPOSE_FILE" ps

echo "=== Health checks (if defined) ==="
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "chatwoot-(web|worker|postgres|redis)" || true

echo "=== Done ==="
