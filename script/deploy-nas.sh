#!/bin/bash
# Build Chatwoot images on this Mac (ARM64) for linux/amd64, transfer to the
# Synology DS220+ NAS, and deploy the stack there.
#
# Usage: ./script/deploy-nas.sh [OPTIONS]
#   --force, -f        Force image rebuild even if git HEAD is unchanged
#   --no-cache         Rebuild from scratch (implies --force)
#   --skip-transfer    Build locally but do not transfer to NAS
#   --skip-build       Skip build, re-transfer the last locally built image
#   --env-file FILE    Use a different env file (default: .env.production)
#   --nas-user USER    Override NAS SSH user (default: mdu, or $NAS_USER env)
set -euo pipefail

NAS_HOST="taborator.rhaps.net"
NAS_PORT="24"
NAS_USER="${NAS_USER:-mdu}"
NAS_DATA_DIR="/volume1/docker/chatwoot"
NAS_COMPOSE_FILE="docker-compose.nas.yml"
ENV_FILE=".env.production"
CERTS_DIR="certs/apple_pay"
BUILD_STAMP_FILE="tmp/.docker-nas-build"
WEB_TAG="chatwoot:nas-web"
WORKER_TAG="chatwoot:nas-worker"
PLATFORM="linux/amd64"
FORCE_BUILD=false
NO_CACHE=false
SKIP_TRANSFER=false
SKIP_BUILD=false

GIT_HEAD="$(git rev-parse HEAD)"
DOCKER_CONFIG_SOURCE="${DOCKER_CONFIG:-$HOME/.docker}"
DOCKER_CONFIG_OVERRIDE=""
BUILDX_CONFIG_OVERRIDE=""

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

die() {
  echo "=== ERROR: $* ===" >&2
  exit 1
}

cleanup() {
  if [ -n "$DOCKER_CONFIG_OVERRIDE" ] && [ -d "$DOCKER_CONFIG_OVERRIDE" ]; then
    rm -rf "$DOCKER_CONFIG_OVERRIDE"
  fi
}
trap cleanup EXIT

# Create a temporary Docker config without credsStore so buildx can pull base
# images in a non-interactive context (avoids macOS keychain prompts).
setup_docker_config_fallback() {
  local config_file="$DOCKER_CONFIG_SOURCE/config.json"
  [ -f "$config_file" ] || return 0

  local creds_store
  creds_store="$(sed -n 's/.*"credsStore"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$config_file" | head -n 1)"
  [ -n "$creds_store" ] || return 0

  local helper_bin="docker-credential-$creds_store"
  if command -v "$helper_bin" >/dev/null 2>&1; then
    echo "=== Docker credsStore ($creds_store) detected; using temporary Docker config without credsStore ==="
  else
    echo "=== Docker credential helper $helper_bin is missing; using temporary Docker config without credsStore ==="
  fi

  DOCKER_CONFIG_OVERRIDE="$(mktemp -d /tmp/chatwoot-nas-docker-config.XXXXXX)"
  sed '/"credsStore"[[:space:]]*:/d' "$config_file" > "$DOCKER_CONFIG_OVERRIDE/config.json"

  # Symlink existing buildx state so the current builder remains available.
  if [ -d "$DOCKER_CONFIG_SOURCE/buildx" ]; then
    BUILDX_CONFIG_OVERRIDE="$DOCKER_CONFIG_SOURCE/buildx"
    ln -s "$DOCKER_CONFIG_SOURCE/buildx" "$DOCKER_CONFIG_OVERRIDE/buildx"
  else
    BUILDX_CONFIG_OVERRIDE="$DOCKER_CONFIG_OVERRIDE/buildx"
    mkdir -p "$BUILDX_CONFIG_OVERRIDE"
  fi

  if [ -d "$DOCKER_CONFIG_SOURCE/cli-plugins" ]; then
    ln -s "$DOCKER_CONFIG_SOURCE/cli-plugins" "$DOCKER_CONFIG_OVERRIDE/cli-plugins"
  fi
  if [ -d "$DOCKER_CONFIG_SOURCE/contexts" ]; then
    ln -s "$DOCKER_CONFIG_SOURCE/contexts" "$DOCKER_CONFIG_OVERRIDE/contexts"
  fi
}

docker_cmd() {
  if [ -n "$DOCKER_CONFIG_OVERRIDE" ]; then
    DOCKER_CONFIG="$DOCKER_CONFIG_OVERRIDE" BUILDX_CONFIG="$BUILDX_CONFIG_OVERRIDE" \
      docker --config "$DOCKER_CONFIG_OVERRIDE" "$@"
  else
    docker "$@"
  fi
}

ssh_cmd() {
  ssh -p "$NAS_PORT" "$NAS_USER@$NAS_HOST" "$@"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

while [ $# -gt 0 ]; do
  case "$1" in
    --force|-f)
      FORCE_BUILD=true; shift ;;
    --no-cache)
      NO_CACHE=true; FORCE_BUILD=true; shift ;;
    --skip-transfer)
      SKIP_TRANSFER=true; shift ;;
    --skip-build)
      SKIP_BUILD=true; shift ;;
    --env-file)
      [ $# -ge 2 ] || die "Missing value for --env-file"
      ENV_FILE="$2"; shift 2 ;;
    --nas-user)
      [ $# -ge 2 ] || die "Missing value for --nas-user"
      NAS_USER="$2"; shift 2 ;;
    *)
      echo "Usage: $0 [--force|-f] [--no-cache] [--skip-transfer] [--skip-build] [--env-file FILE] [--nas-user USER]"
      exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------

[ -f "$ENV_FILE" ]         || die "Missing $ENV_FILE"
[ -f "$NAS_COMPOSE_FILE" ] || die "Missing $NAS_COMPOSE_FILE"

echo "=== Checking buildx linux/amd64 support ==="
_buildx_info="$(docker buildx inspect --bootstrap 2>&1 || true)"
case "$_buildx_info" in
  *linux/amd64*) ;;
  *) die "No buildx builder with linux/amd64 support. Run: docker buildx create --use --bootstrap" ;;
esac
unset _buildx_info

echo "=== Checking SSH connectivity to $NAS_USER@$NAS_HOST:$NAS_PORT ==="
ssh -p "$NAS_PORT" -o ConnectTimeout=10 -o BatchMode=yes "$NAS_USER@$NAS_HOST" true \
  || die "Cannot SSH to NAS. Authorize your key first: ssh-copy-id -p $NAS_PORT $NAS_USER@$NAS_HOST"

echo "=== Detecting docker path on NAS ==="
NAS_DOCKER="$(ssh_cmd '
  command -v docker 2>/dev/null && exit
  for p in /usr/local/bin/docker /var/packages/ContainerManager/target/usr/bin/docker; do
    [ -x "$p" ] && echo "$p" && exit
  done
  find /usr/local/bin /var/packages -maxdepth 6 -name docker 2>/dev/null | head -1
')"
[ -n "$NAS_DOCKER" ] || die "docker not found on NAS — is Container Manager installed and running?"
echo "=== NAS docker: $NAS_DOCKER ==="

setup_docker_config_fallback

# ---------------------------------------------------------------------------
# Build stamp check
# ---------------------------------------------------------------------------

should_build=true
if [ "$FORCE_BUILD" = false ] && [ "$SKIP_BUILD" = false ]; then
  if [ -f "$BUILD_STAMP_FILE" ] && [ "$(cat "$BUILD_STAMP_FILE")" = "$GIT_HEAD" ] \
     && docker_cmd image inspect "$WEB_TAG" >/dev/null 2>&1; then
    should_build=false
    echo "=== Skipping build: $WEB_TAG is already up-to-date for $GIT_HEAD ==="
  fi
fi

[ "$SKIP_BUILD" = true ] && should_build=false

# ---------------------------------------------------------------------------
# Build (linux/amd64 via QEMU on Apple Silicon)
# First run: 30-90 minutes. Subsequent runs: 2-5 minutes (layer cache hits).
# ---------------------------------------------------------------------------

if [ "$should_build" = true ]; then
  build_args=(
    buildx build
    --platform "$PLATFORM"
    --build-arg "GIT_SHA=$GIT_HEAD"
    --load
    -t "$WEB_TAG"
    -f Dockerfile.production
    .
  )
  [ "$NO_CACHE" = true ] && build_args+=(--no-cache)

  echo "=== Building $WEB_TAG (linux/amd64) ==="
  docker_cmd "${build_args[@]}"

  # Worker uses the same image; tag it separately so compose can reference both names.
  docker_cmd tag "$WEB_TAG" "$WORKER_TAG"
  echo "=== Tagged $WEB_TAG → $WORKER_TAG ==="

  mkdir -p "$(dirname "$BUILD_STAMP_FILE")"
  echo "$GIT_HEAD" > "$BUILD_STAMP_FILE"
fi

# ---------------------------------------------------------------------------
# Transfer images to NAS
# Both tags share layers, so docker save deduplicates them (~4-5 GB on wire).
# ---------------------------------------------------------------------------

if [ "$SKIP_TRANSFER" = false ]; then
  echo "=== Transferring images to NAS — this takes 1-3 minutes on a gigabit LAN ==="
  docker_cmd save "$WEB_TAG" "$WORKER_TAG" \
    | gzip -1 \
    | ssh -p "$NAS_PORT" "$NAS_USER@$NAS_HOST" "$NAS_DOCKER load"
  echo "=== Transfer complete ==="
fi

# ---------------------------------------------------------------------------
# Sync config files
# scp uses the SFTP subsystem which Synology disables by default; use
# "ssh cat >" for plain files and tar-over-ssh for directories instead.
# ---------------------------------------------------------------------------

echo "=== Creating $NAS_DATA_DIR on NAS ==="
ssh_cmd "mkdir -p $NAS_DATA_DIR/certs/apple_pay"

echo "=== Syncing .env.production → NAS ==="
ssh_cmd "cat > $NAS_DATA_DIR/.env.production" < "$ENV_FILE"

echo "=== Syncing $NAS_COMPOSE_FILE → NAS ==="
ssh_cmd "cat > $NAS_DATA_DIR/docker-compose.nas.yml" < "$NAS_COMPOSE_FILE"

if [ -d "$CERTS_DIR" ]; then
  echo "=== Syncing Apple Pay certs → NAS ==="
  tar czf - -C "$CERTS_DIR" . \
    | ssh_cmd "tar xzf - -C $NAS_DATA_DIR/certs/apple_pay && chmod 644 $NAS_DATA_DIR/certs/apple_pay/*.key 2>/dev/null || true"
else
  echo "=== WARNING: $CERTS_DIR not found — Apple Pay certs NOT synced ==="
fi

# ---------------------------------------------------------------------------
# Remote deploy
# ---------------------------------------------------------------------------

echo "=== Deploying on NAS ==="
ssh_cmd "bash -s" <<REMOTE
set -euo pipefail

# Ensure data dirs exist before postgres/redis start (bind-mounted volumes require this).
mkdir -p \
  "$NAS_DATA_DIR/storage" \
  "$NAS_DATA_DIR/certs/apple_pay" \
  "$NAS_DATA_DIR/postgres-data" \
  "$NAS_DATA_DIR/redis-data"

# Create the shared Docker network if it does not exist yet.
# cloudflared must be connected to this network to reach http://web:8080.
$NAS_DOCKER network inspect cloudflare_rhaps_prod_net >/dev/null 2>&1 \
  || $NAS_DOCKER network create cloudflare_rhaps_prod_net

cd "$NAS_DATA_DIR"

echo "=== Pulling postgres and redis (native AMD64 — fast) ==="
$NAS_DOCKER compose -f docker-compose.nas.yml --env-file .env.production pull postgres redis 2>/dev/null || true

echo "=== Starting postgres and redis ==="
$NAS_DOCKER compose -f docker-compose.nas.yml --env-file .env.production up -d postgres redis

echo "=== Waiting for postgres and redis to be healthy (max 60s) ==="
for i in \$(seq 1 12); do
  pg=\$($NAS_DOCKER inspect chatwoot-postgres --format '{{.State.Health.Status}}' 2>/dev/null || echo starting)
  rd=\$($NAS_DOCKER inspect chatwoot-redis   --format '{{.State.Health.Status}}' 2>/dev/null || echo starting)
  [ "\$pg" = "healthy" ] && [ "\$rd" = "healthy" ] && break
  echo "  postgres: \$pg  redis: \$rd  (attempt \$i/12)"
  sleep 5
done

echo "=== Starting web and worker ==="
$NAS_DOCKER compose -f docker-compose.nas.yml --env-file .env.production up -d web worker

echo "=== Container status ==="
$NAS_DOCKER compose -f docker-compose.nas.yml --env-file .env.production ps
REMOTE

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

echo ""
echo "=== NAS deploy complete ==="
echo "=== Chatwoot: https://msp.rhaps.net ==="
echo ""
echo "=== One-time cloudflared setup (if not done yet) ==="
echo "  Connect cloudflared to the shared network:"
echo "    ssh -p $NAS_PORT $NAS_USER@$NAS_HOST '$NAS_DOCKER network connect cloudflare_rhaps_prod_net <cloudflared-container-name>'"
echo "  Point the tunnel ingress to: http://web:8080"
echo ""
echo "=== Useful NAS commands ==="
echo "  Web logs:  ssh -p $NAS_PORT $NAS_USER@$NAS_HOST '$NAS_DOCKER logs -f chatwoot-web'"
echo "  Worker:    ssh -p $NAS_PORT $NAS_USER@$NAS_HOST '$NAS_DOCKER logs -f chatwoot-worker'"
echo "  Shell:     ssh -p $NAS_PORT $NAS_USER@$NAS_HOST '$NAS_DOCKER exec -it chatwoot-web bash'"
echo "  Status:    ssh -p $NAS_PORT $NAS_USER@$NAS_HOST 'cd $NAS_DATA_DIR && $NAS_DOCKER compose -f docker-compose.nas.yml --env-file .env.production ps'"
echo ""
echo "=== Data migration (first-time only) ==="
echo "  If moving data from this Mac, copy postgres/storage volumes before first run."
echo "  See: script/migrate-data-to-nas.sh (create separately if needed)"
