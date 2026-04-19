#!/bin/bash
set -euo pipefail

COMPOSE_FILE="docker-compose.production.yml"
BUILD_STAMP_FILE="tmp/.docker-production-build"
GIT_HEAD="$(git rev-parse HEAD)"
CERTS_DIR="certs/apple_pay"
CERTS_BACKUP_DIR="tmp/apple_pay_certs_backup"
DOCKER_CONFIG_SOURCE="${DOCKER_CONFIG:-$HOME/.docker}"
DOCKER_CONFIG_OVERRIDE=""
BUILDX_CONFIG_OVERRIDE=""
GLOBAL_DOCKER_CONFIG_FILE=""
GLOBAL_DOCKER_CONFIG_BACKUP=""

restore_certs_if_missing() {
  if [ -d "$CERTS_BACKUP_DIR" ]; then
    if [ ! -f "$CERTS_DIR/apple_pay_cert.pem" ] || [ ! -f "$CERTS_DIR/apple_pay_private.key" ]; then
      echo "=== Restoring Apple Pay certs from backup ==="
      mkdir -p "$CERTS_DIR"
      cp -f "$CERTS_BACKUP_DIR"/* "$CERTS_DIR"/ 2>/dev/null || true
    fi
  fi
}

cleanup() {
  restore_certs_if_missing
  if [ -n "$GLOBAL_DOCKER_CONFIG_BACKUP" ] && [ -n "$GLOBAL_DOCKER_CONFIG_FILE" ] && [ -f "$GLOBAL_DOCKER_CONFIG_BACKUP" ]; then
    cp -f "$GLOBAL_DOCKER_CONFIG_BACKUP" "$GLOBAL_DOCKER_CONFIG_FILE"
    rm -f "$GLOBAL_DOCKER_CONFIG_BACKUP"
  fi
  if [ -n "$DOCKER_CONFIG_OVERRIDE" ] && [ -d "$DOCKER_CONFIG_OVERRIDE" ]; then
    rm -rf "$DOCKER_CONFIG_OVERRIDE"
  fi
}

setup_docker_config_fallback() {
  local config_file="$DOCKER_CONFIG_SOURCE/config.json"
  if [ ! -f "$config_file" ]; then
    return
  fi

  local creds_store
  creds_store="$(sed -n 's/.*"credsStore"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$config_file" | head -n 1)"
  if [ -z "$creds_store" ]; then
    return
  fi

  local helper_bin="docker-credential-$creds_store"
  if command -v "$helper_bin" >/dev/null 2>&1; then
    echo "=== Docker credsStore ($creds_store) detected; using temporary Docker config without credsStore for non-interactive build ==="
  else
    echo "=== Docker credential helper $helper_bin is missing; using temporary Docker config without credsStore ==="
  fi

  DOCKER_CONFIG_OVERRIDE="$(mktemp -d /tmp/chatwoot-docker-config.XXXXXX)"
  BUILDX_CONFIG_OVERRIDE="$DOCKER_CONFIG_OVERRIDE/buildx"
  sed '/"credsStore"[[:space:]]*:/d' "$config_file" > "$DOCKER_CONFIG_OVERRIDE/config.json"
  mkdir -p "$BUILDX_CONFIG_OVERRIDE"

  # Keep Docker Desktop CLI plugins/context so `docker compose` and buildx remain available.
  if [ -d "$DOCKER_CONFIG_SOURCE/cli-plugins" ]; then
    ln -s "$DOCKER_CONFIG_SOURCE/cli-plugins" "$DOCKER_CONFIG_OVERRIDE/cli-plugins"
  fi
  if [ -d "$DOCKER_CONFIG_SOURCE/contexts" ]; then
    ln -s "$DOCKER_CONFIG_SOURCE/contexts" "$DOCKER_CONFIG_OVERRIDE/contexts"
  fi
}

docker_cmd() {
  if [ -n "$DOCKER_CONFIG_OVERRIDE" ]; then
    DOCKER_CONFIG="$DOCKER_CONFIG_OVERRIDE" BUILDX_CONFIG="$BUILDX_CONFIG_OVERRIDE" docker --config "$DOCKER_CONFIG_OVERRIDE" "$@"
  else
    docker "$@"
  fi
}

docker_cmd_legacy_build() {
  if [ -n "$DOCKER_CONFIG_OVERRIDE" ]; then
    DOCKER_CONFIG="$DOCKER_CONFIG_OVERRIDE" BUILDX_CONFIG="$BUILDX_CONFIG_OVERRIDE" DOCKER_BUILDKIT=0 COMPOSE_DOCKER_CLI_BUILD=0 docker --config "$DOCKER_CONFIG_OVERRIDE" "$@"
  else
    DOCKER_BUILDKIT=0 COMPOSE_DOCKER_CLI_BUILD=0 docker "$@"
  fi
}

build_images_with_global_config_fallback() {
  local config_file="$DOCKER_CONFIG_SOURCE/config.json"
  if [ ! -f "$config_file" ]; then
    return 1
  fi

  GLOBAL_DOCKER_CONFIG_FILE="$config_file"
  GLOBAL_DOCKER_CONFIG_BACKUP="$(mktemp /tmp/chatwoot-docker-config.backup.XXXXXX)"
  cp -f "$config_file" "$GLOBAL_DOCKER_CONFIG_BACKUP"
  sed '/"credsStore"[[:space:]]*:/d' "$GLOBAL_DOCKER_CONFIG_BACKUP" > "$config_file"

  echo "=== Retrying build with sanitized global Docker config and BuildKit disabled ==="
  DOCKER_BUILDKIT=0 COMPOSE_DOCKER_CLI_BUILD=0 docker compose -f "$COMPOSE_FILE" build web worker
}

build_images() {
  local build_output
  if build_output="$(docker_cmd compose -f "$COMPOSE_FILE" build web worker 2>&1)"; then
    printf '%s\n' "$build_output"
    return 0
  fi

  printf '%s\n' "$build_output"
  if printf '%s' "$build_output" | grep -qi "keychain cannot be accessed"; then
    echo "=== Retrying build with BuildKit disabled to bypass keychain-backed credential flow ==="
    local legacy_output
    if legacy_output="$(docker_cmd_legacy_build compose -f "$COMPOSE_FILE" build web worker 2>&1)"; then
      printf '%s\n' "$legacy_output"
      return 0
    fi

    printf '%s\n' "$legacy_output"
    if printf '%s' "$legacy_output" | grep -qi "keychain cannot be accessed"; then
      build_images_with_global_config_fallback
      return $?
    fi

    return 1
  fi

  return 1
}

trap cleanup EXIT
setup_docker_config_fallback

if [ -d "$CERTS_DIR" ]; then
  mkdir -p "$CERTS_BACKUP_DIR"
  cp -f "$CERTS_DIR"/* "$CERTS_BACKUP_DIR"/ 2>/dev/null || true
fi

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
     docker_cmd image inspect chatwoot:production-web >/dev/null 2>&1 && \
     docker_cmd image inspect chatwoot:production-worker >/dev/null 2>&1; then
    should_build=false
  fi
fi
fi

if [ "$should_build" = true ]; then
  echo "=== Building production images (web, worker) ==="
  build_images
  mkdir -p "$(dirname "$BUILD_STAMP_FILE")"
  echo "$GIT_HEAD" > "$BUILD_STAMP_FILE"
else
  echo "=== Skipping build (images up-to-date for git HEAD $GIT_HEAD) ==="
fi

echo "=== Starting dependencies (postgres, redis) ==="
docker_cmd compose -f "$COMPOSE_FILE" up -d postgres redis

echo "=== Starting services ==="
docker_cmd compose -f "$COMPOSE_FILE" up -d web worker

# Hot-patch: copy any locally modified or new Ruby/config files into running containers.
# This ensures uncommitted changes are live without a full image rebuild.
hotpatch_ruby_files() {
  local changed_files=()
  while IFS= read -r line; do
    local file="${line:3}"
    if [[ "$file" == *.rb ]] && [[ "$file" == app/* || "$file" == config/* ]]; then
      changed_files+=("$file")
    fi
  done < <(git status --porcelain)

  if [ ${#changed_files[@]} -eq 0 ]; then
    echo "=== No local Ruby changes to hot-patch ==="
    return
  fi

  echo "=== Hot-patching ${#changed_files[@]} Ruby file(s) into containers ==="
  for file in "${changed_files[@]}"; do
    echo "  Patching: $file"
    docker_cmd cp "$file" "chatwoot-web:/app/$file"
    docker_cmd cp "$file" "chatwoot-worker:/app/$file"
  done

  echo "=== Restarting web and worker to load patched code (60s timeout for Sidekiq graceful shutdown) ==="
  docker_cmd compose -f "$COMPOSE_FILE" restart --timeout 60 web worker
}
hotpatch_ruby_files

if [ -f "$CERTS_DIR/apple_pay_cert.pem" ] && [ -f "$CERTS_DIR/apple_pay_private.key" ]; then
  echo "=== Apple Pay certs available via bind mount: $CERTS_DIR ==="
else
  echo "=== Apple Pay certs missing on host; containers will not have /app/certs/apple_pay merchant files ==="
fi

echo "=== Current container status ==="
docker_cmd compose -f "$COMPOSE_FILE" ps

echo "=== Health checks (if defined) ==="
docker_cmd ps --format "table {{.Names}}\t{{.Status}}" | grep -E "chatwoot-(web|worker|postgres|redis)" || true

echo "=== Done ==="
