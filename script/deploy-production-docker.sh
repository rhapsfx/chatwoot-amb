#!/bin/bash
set -euo pipefail

COMPOSE_FILE="docker-compose.production.yml"
ENV_FILE=".env.production"
AUTO_ENV_FILE="tmp/.env.production.auto"
BUILD_STAMP_FILE="tmp/.docker-production-build"
GIT_HEAD="$(git rev-parse HEAD)"
CERTS_DIR="certs/apple_pay"
CERTS_BACKUP_DIR="tmp/apple_pay_certs_backup"
DOCKER_CONFIG_SOURCE="${DOCKER_CONFIG:-$HOME/.docker}"
DOCKER_CONFIG_OVERRIDE=""
BUILDX_CONFIG_OVERRIDE=""
GLOBAL_DOCKER_CONFIG_FILE=""
GLOBAL_DOCKER_CONFIG_BACKUP=""
FORCE_BUILD=false
NO_CACHE=false

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

compose_cmd() {
  docker_cmd compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

compose_cmd_legacy_build() {
  docker_cmd_legacy_build compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

ensure_auto_env_file() {
  local source_env=".env"
  local redis_password=""

  mkdir -p "$(dirname "$AUTO_ENV_FILE")"

  if [ -f "$AUTO_ENV_FILE" ]; then
    redis_password="$(sed -n 's/^REDIS_PASSWORD=//p' "$AUTO_ENV_FILE" | tail -n 1)"
  fi

  if [ -z "$redis_password" ]; then
    redis_password="$(openssl rand -hex 24)"
  fi

  cp "$source_env" "$AUTO_ENV_FILE"
  if grep -q '^REDIS_PASSWORD=' "$AUTO_ENV_FILE"; then
    sed -i.bak "s/^REDIS_PASSWORD=.*/REDIS_PASSWORD=$redis_password/" "$AUTO_ENV_FILE"
  else
    printf '\nREDIS_PASSWORD=%s\n' "$redis_password" >> "$AUTO_ENV_FILE"
  fi
  rm -f "$AUTO_ENV_FILE.bak"

  ENV_FILE="$AUTO_ENV_FILE"
  echo "=== .env.production not found; using $AUTO_ENV_FILE with a production Redis password ==="
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
  if [ "$NO_CACHE" = true ]; then
    DOCKER_BUILDKIT=0 COMPOSE_DOCKER_CLI_BUILD=0 docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" build --no-cache --build-arg "GIT_SHA=$GIT_HEAD" web worker
  else
    DOCKER_BUILDKIT=0 COMPOSE_DOCKER_CLI_BUILD=0 docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" build --build-arg "GIT_SHA=$GIT_HEAD" web worker
  fi
}

build_images() {
  local build_output
  local build_args=(build --build-arg "GIT_SHA=$GIT_HEAD")
  if [ "$NO_CACHE" = true ]; then
    build_args+=(--no-cache)
  fi
  build_args+=(web worker)

  if build_output="$(compose_cmd "${build_args[@]}" 2>&1)"; then
    printf '%s\n' "$build_output"
    return 0
  fi

  printf '%s\n' "$build_output"
  if printf '%s' "$build_output" | grep -qi "keychain cannot be accessed"; then
    echo "=== Retrying build with BuildKit disabled to bypass keychain-backed credential flow ==="
    local legacy_output
    if legacy_output="$(compose_cmd_legacy_build "${build_args[@]}" 2>&1)"; then
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

while [ $# -gt 0 ]; do
  case "$1" in
    --force|-f)
      FORCE_BUILD=true
      shift
      ;;
    --no-cache)
      NO_CACHE=true
      FORCE_BUILD=true
      shift
      ;;
    --env-file)
      if [ $# -lt 2 ]; then
        echo "=== Missing value for --env-file ==="
        exit 1
      fi
      ENV_FILE="$2"
      shift 2
      ;;
    *)
      echo "=== Unknown option: $1 ==="
      echo "Usage: $0 [--force|-f] [--no-cache] [--env-file FILE]"
      exit 1
      ;;
  esac
done

if [ ! -f "$ENV_FILE" ]; then
  if [ "$ENV_FILE" = ".env.production" ] && [ -f ".env" ]; then
    ensure_auto_env_file
  else
    echo "=== Missing $ENV_FILE ==="
    echo "Use --env-file FILE to point to a production env file."
    exit 1
  fi
fi

if [ ! -f "$ENV_FILE" ]; then
  echo "=== Missing $ENV_FILE ==="
  echo "Create $ENV_FILE for production Docker settings. Keep local dev values in .env."
  exit 1
fi

if [ -d "$CERTS_DIR" ]; then
  mkdir -p "$CERTS_BACKUP_DIR"
  cp -f "$CERTS_DIR"/* "$CERTS_BACKUP_DIR"/ 2>/dev/null || true
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
compose_cmd up -d postgres redis

echo "=== Starting services ==="
compose_cmd up -d web worker

# Hot-patch: copy any locally modified or new Ruby/config files into running containers.
# This ensures uncommitted changes are live without a full image rebuild.
# NOTE: JS/Vue/TS changes in app/javascript require a full image rebuild — they cannot be hot-patched.
hotpatch_ruby_files() {
  local changed_files=()
  local frontend_changed_files=()

  while IFS= read -r line; do
    local file="${line:3}"
    if [[ "$file" == *.rb ]] && [[ "$file" == app/* || "$file" == config/* ]]; then
      changed_files+=("$file")
    elif [[ "$file" == app/javascript/* ]] && [[ "$file" == *.js || "$file" == *.vue || "$file" == *.ts ]]; then
      frontend_changed_files+=("$file")
    fi
  done < <(git status --porcelain)

  if [ ${#frontend_changed_files[@]} -gt 0 ]; then
    echo "=== WARNING: ${#frontend_changed_files[@]} uncommitted frontend file(s) detected (JS/Vue/TS) ==="
    echo "=== These require a full image rebuild (--force) to take effect in production: ==="
    for file in "${frontend_changed_files[@]}"; do
      echo "  $file"
    done
    echo "=== Run: $0 --force to rebuild and redeploy with frontend changes ==="
  fi

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
  compose_cmd restart --timeout 60 web worker
}
hotpatch_ruby_files

if [ -f "$CERTS_DIR/apple_pay_cert.pem" ] && [ -f "$CERTS_DIR/apple_pay_private.key" ]; then
  echo "=== Apple Pay certs available via bind mount: $CERTS_DIR ==="
else
  echo "=== Apple Pay certs missing on host; containers will not have /app/certs/apple_pay merchant files ==="
fi

echo "=== Current container status ==="
compose_cmd ps

echo "=== Health checks (if defined) ==="
docker_cmd ps --format "table {{.Names}}\t{{.Status}}" | grep -E "chatwoot-(web|worker|postgres|redis)" || true

echo "=== Done ==="
