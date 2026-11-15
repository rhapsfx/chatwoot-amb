#!/bin/bash
# Build Chatwoot images on this Mac (ARM64) for linux/amd64, transfer to the
# Synology DS220+ NAS, and deploy the stack there.
#
# Usage: ./script/deploy-nas.sh [OPTIONS]
#   --force, -f        Force image rebuild even if git HEAD is unchanged
#   --no-cache         Rebuild from scratch (implies --force)
#   --skip-transfer    Build locally only — do not transfer or touch the NAS
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

# The stamp must cover what `docker build .` actually consumes: the working
# tree, not just HEAD. Otherwise local edits with an unchanged HEAD reuse a
# stale image.
build_fingerprint() {
  local input_files=(Dockerfile.production)
  if [ -f .dockerignore ]; then
    input_files+=(.dockerignore)
  fi
  {
    git rev-parse HEAD
    git hash-object -- "${input_files[@]}"
    git status --porcelain
  } | shasum -a 256 | awk '{print $1}'
}

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

# Write a local file to the NAS atomically (upload as .tmp, then rename) so a
# dropped connection can never truncate the live env/compose file.
push_file() {
  local src="$1" dest="$2" mode="${3:-600}"
  ssh_cmd "umask 077; cat > '$dest.tmp' && chmod '$mode' '$dest.tmp' && mv -f '$dest.tmp' '$dest'" < "$src"
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

# Must run before any docker invocation, otherwise the very first one can still
# trigger a macOS keychain prompt.
setup_docker_config_fallback

echo "=== Checking buildx linux/amd64 support ==="
_buildx_info="$(docker_cmd buildx inspect --bootstrap 2>&1 || true)"
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

echo "=== Detecting docker compose on NAS ==="
NAS_COMPOSE_CMD="$(ssh_cmd "
  if $NAS_DOCKER compose version >/dev/null 2>&1; then echo '$NAS_DOCKER compose'; exit 0; fi
  if command -v docker-compose >/dev/null 2>&1; then command -v docker-compose; exit 0; fi
" || true)"
[ -n "$NAS_COMPOSE_CMD" ] || die "docker compose not found on NAS — install the compose plugin or docker-compose"
echo "=== NAS compose: $NAS_COMPOSE_CMD ==="

COMPOSE_SUPPORTS_WAIT=false
if ssh_cmd "$NAS_COMPOSE_CMD up --help 2>&1 | grep -q -- '--wait'"; then
  COMPOSE_SUPPORTS_WAIT=true
  echo "=== compose 'up --wait' supported: will let compose gate readiness ==="
else
  echo "=== compose 'up --wait' NOT supported: falling back to manual health polling ==="
fi

# ---------------------------------------------------------------------------
# Build stamp check
# ---------------------------------------------------------------------------

should_build=true
BUILD_FINGERPRINT="$(build_fingerprint)"

if [ "$FORCE_BUILD" = false ] && [ "$SKIP_BUILD" = false ]; then
  if [ -f "$BUILD_STAMP_FILE" ] && [ "$(cat "$BUILD_STAMP_FILE")" = "$BUILD_FINGERPRINT" ] \
     && docker_cmd image inspect "$WEB_TAG" >/dev/null 2>&1 \
     && docker_cmd image inspect "$WORKER_TAG" >/dev/null 2>&1; then
    should_build=false
    echo "=== Skipping build: $WEB_TAG is already up-to-date for $GIT_HEAD (tree matches stamp) ==="
  fi
fi

if [ "$SKIP_BUILD" = true ]; then
  should_build=false
  for img in "$WEB_TAG" "$WORKER_TAG"; do
    docker_cmd image inspect "$img" >/dev/null 2>&1 \
      || die "--skip-build: $img is not present locally — run a build first"
  done
  echo "=== --skip-build: reusing $WEB_TAG / $WORKER_TAG ==="
fi

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
  echo "$BUILD_FINGERPRINT" > "$BUILD_STAMP_FILE"
fi

# ---------------------------------------------------------------------------
# Transfer images to NAS
# Both tags share layers, so docker save deduplicates them (~4-5 GB on wire).
# ---------------------------------------------------------------------------

if [ "$SKIP_TRANSFER" = true ]; then
  echo "=== --skip-transfer: image built locally for $GIT_HEAD; NAS untouched (no image, config or container changes) ==="
  exit 0
fi

echo "=== Transferring images to NAS — this takes 1-3 minutes on a gigabit LAN ==="
docker_cmd save "$WEB_TAG" "$WORKER_TAG" \
  | gzip -1 \
  | ssh -p "$NAS_PORT" "$NAS_USER@$NAS_HOST" "$NAS_DOCKER load"
echo "=== Transfer complete ==="

# ---------------------------------------------------------------------------
# Sync config files
# scp uses the SFTP subsystem which Synology disables by default; use
# "ssh cat >" for plain files and tar-over-ssh for directories instead.
# ---------------------------------------------------------------------------

echo "=== Creating $NAS_DATA_DIR on NAS ==="
ssh_cmd "mkdir -p $NAS_DATA_DIR/certs/apple_pay"

echo "=== Syncing .env.production → NAS (mode 600) ==="
push_file "$ENV_FILE" "$NAS_DATA_DIR/.env.production" 600

echo "=== Syncing $NAS_COMPOSE_FILE → NAS ==="
push_file "$NAS_COMPOSE_FILE" "$NAS_DATA_DIR/$NAS_COMPOSE_FILE" 644

if [ -d "$CERTS_DIR" ]; then
  echo "=== Syncing Apple Pay certs → NAS ==="
  tar czf - -C "$CERTS_DIR" . \
    | ssh_cmd "tar xzf - -C $NAS_DATA_DIR/certs/apple_pay"
  # This path is bind-mounted read-only into the app container, which runs as
  # uid 1000 (chatwoot), so the files must stay readable by that uid. Locking
  # them to the SSH user requires a root chown on the NAS (see tail note).
  ssh_cmd "chmod 755 $NAS_DATA_DIR/certs/apple_pay \
    && find $NAS_DATA_DIR/certs/apple_pay -maxdepth 1 -type f -exec chmod 644 {} \\;"
else
  echo "=== WARNING: $CERTS_DIR not found — Apple Pay certs NOT synced ==="
fi

# ---------------------------------------------------------------------------
# Remote deploy
# ---------------------------------------------------------------------------

echo "=== Deploying on NAS ==="
ssh_cmd "bash -s" <<REMOTE
set -euo pipefail

compose() { $NAS_COMPOSE_CMD -f $NAS_COMPOSE_FILE --env-file .env.production "\$@"; }

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

if [ "$COMPOSE_SUPPORTS_WAIT" = true ]; then
  echo "=== Starting stack (compose up --wait: fails unless every healthcheck passes) ==="
  compose up -d --wait
else
  echo "=== Pulling postgres and redis (native AMD64 — fast) ==="
  compose pull postgres redis 2>/dev/null || true

  echo "=== Starting postgres and redis ==="
  compose up -d postgres redis

  echo "=== Waiting for postgres and redis to be healthy (max 60s) ==="
  healthy=false
  for i in \$(seq 1 12); do
    pg=\$($NAS_DOCKER inspect chatwoot-postgres --format '{{.State.Health.Status}}' 2>/dev/null || echo starting)
    rd=\$($NAS_DOCKER inspect chatwoot-redis   --format '{{.State.Health.Status}}' 2>/dev/null || echo starting)
    if [ "\$pg" = "healthy" ] && [ "\$rd" = "healthy" ]; then
      healthy=true
      break
    fi
    echo "  postgres: \$pg  redis: \$rd  (attempt \$i/12)"
    sleep 5
  done
  [ "\$healthy" = true ] || { echo "=== ERROR: postgres/redis not healthy after 60s — not starting web/worker ===" >&2; exit 1; }

  echo "=== Starting web and worker ==="
  compose up -d web worker
fi

echo "=== Container status ==="
compose ps
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
echo "  Status:    ssh -p $NAS_PORT $NAS_USER@$NAS_HOST 'cd $NAS_DATA_DIR && $NAS_COMPOSE_CMD -f $NAS_COMPOSE_FILE --env-file .env.production ps'"
echo ""
echo "=== Secret permissions ==="
echo "  .env.production is pushed mode 600 and read by compose as $NAS_USER."
echo "  certs/apple_pay stays 644: the app container runs as uid 1000 (chatwoot) and"
echo "  a bind mount gives it no access to owner-only perms held by $NAS_USER."
echo "  To lock the Apple Pay private key to the container user (needs root, and"
echo "  future cert syncs would then have to run as root too):"
echo "    ssh -p $NAS_PORT $NAS_USER@$NAS_HOST 'sudo chown -R 1000:1000 $NAS_DATA_DIR/certs/apple_pay && sudo chmod -R go-rwx $NAS_DATA_DIR/certs/apple_pay'"
echo ""
echo "=== Data migration (first-time only) ==="
echo "  If moving data from this Mac, copy postgres/storage volumes before first run."
echo "  See: script/migrate-data-to-nas.sh (create separately if needed)"
