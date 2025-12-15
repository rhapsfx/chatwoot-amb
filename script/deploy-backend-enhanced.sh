#!/bin/bash
# Enhanced backend deployment script
# Syncs code changes to running containers without rebuilding Docker image
# Use this for quick backend-only updates (services, controllers, configs)
# For Docker image changes, use quick_rebuild.sh instead

set -e

echo "======================================================================="
echo "📦 BACKEND CODE DEPLOYMENT (Hot-patch to Running Containers)"
echo "======================================================================="
echo ""
echo "This script deploys backend code changes WITHOUT rebuilding the Docker image."
echo ""
echo "✅ USE THIS SCRIPT FOR:"
echo "  - Ruby code changes (services, controllers, models, jobs)"
echo "  - Configuration changes (routes, initializers)"
echo "  - Database migrations"
echo "  - Backend library updates"
echo ""
echo "❌ DO NOT USE FOR:"
echo "  - Dockerfile.production changes"
echo "  - Gemfile/Gemfile.lock changes"
echo "  - System dependencies (apt packages, Node.js version)"
echo "  - Frontend assets (JavaScript, CSS, Vite config)"
echo ""
echo "For those changes, use: ./script/quick_rebuild.sh"
echo ""

# Configuration
REMOTE_USER="root"
REMOTE_HOST="msp.rhaps.net"
REMOTE_PATH="/opt/chatwoot"
COMPOSE_FILE="docker-compose.production.yml"

# Step 1: Sync backend code
echo "Step 1: Syncing backend code to server..."
echo "→ Transferring: app/, lib/, config/, db/migrate/"
rsync -avz --delete \
    --exclude='node_modules' \
    --exclude='tmp' \
    --exclude='log' \
    --exclude='.git' \
    --exclude='storage' \
    --exclude='public/vite*' \
    --exclude='.env' \
    --exclude='certs' \
    --include='app/***' \
    --include='lib/***' \
    --include='config/***' \
    --include='db/migrate/***' \
    --include='Gemfile' \
    --include='Gemfile.lock' \
    ./ ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/

if [ $? -eq 0 ]; then
    echo "✅ Code synced successfully"
else
    echo "❌ Code sync failed"
    exit 1
fi
echo ""

# Step 2: Deploy to containers
echo "Step 2: Deploying code to running containers..."
ssh ${REMOTE_USER}@${REMOTE_HOST} 'bash -s' << REMOTE_DEPLOY
set -e
cd ${REMOTE_PATH}

echo "→ Getting container IDs..."
WEB_CONTAINER=\$(docker compose -f ${COMPOSE_FILE} ps -q web)
WORKER_CONTAINER=\$(docker compose -f ${COMPOSE_FILE} ps -q worker)

if [ -z "\$WEB_CONTAINER" ]; then
    echo "  ⚠️  Web container not running"
    echo "  ❌ ERROR: Containers must be running for hot-patch deployment"
    echo ""
    echo "  Start containers with:"
    echo "    docker compose -f ${COMPOSE_FILE} up -d"
    echo ""
    echo "  Or use quick_rebuild.sh to rebuild and start fresh."
    exit 1
fi

echo "  ✅ Web container: \${WEB_CONTAINER:0:12}"
if [ -n "\$WORKER_CONTAINER" ]; then
    echo "  ✅ Worker container: \${WORKER_CONTAINER:0:12}"
fi
echo ""

# Copy code to web container
echo "→ Copying code to web container..."
docker cp app/. \$WEB_CONTAINER:/app/app/
docker cp lib/. \$WEB_CONTAINER:/app/lib/
docker cp config/routes.rb \$WEB_CONTAINER:/app/config/
docker cp config/initializers/. \$WEB_CONTAINER:/app/config/initializers/
echo "  ✅ Code copied to web container"

# Copy code to worker container if it exists
if [ -n "\$WORKER_CONTAINER" ]; then
    echo "→ Copying code to worker container..."
    docker cp app/. \$WORKER_CONTAINER:/app/app/
    docker cp lib/. \$WORKER_CONTAINER:/app/lib/
    echo "  ✅ Code copied to worker container"
fi
echo ""

# Run migrations
echo "→ Running database migrations..."
MIGRATION_OUTPUT=\$(docker exec \$WEB_CONTAINER bundle exec rails db:migrate RAILS_ENV=production 2>&1)
MIGRATION_EXIT=\$?

if [ \$MIGRATION_EXIT -eq 0 ]; then
    if echo "\$MIGRATION_OUTPUT" | grep -qE "migrated|Migrating"; then
        echo "  ✅ Migrations completed successfully"
    else
        echo "  ✅ Database already up to date (no pending migrations)"
    fi
else
    echo "  ❌ Migration failed - check output:"
    echo "\$MIGRATION_OUTPUT" | tail -10
    exit 1
fi
echo ""

# Restart services to apply changes
echo "→ Restarting services to apply code changes..."
docker compose -f ${COMPOSE_FILE} restart web worker
echo "  ✅ Services restarted"
echo ""

# Wait for services to be ready
echo "→ Waiting for services to stabilize..."
sleep 10
echo "  ✅ Services stabilized"

REMOTE_DEPLOY

if [ $? -ne 0 ]; then
    echo "❌ Deployment failed"
    exit 1
fi
echo ""

# Step 3: Verification
echo "Step 3: Verifying deployment..."
ssh ${REMOTE_USER}@${REMOTE_HOST} 'bash -s' << REMOTE_VERIFY
cd ${REMOTE_PATH}

WEB_CONTAINER=\$(docker compose -f ${COMPOSE_FILE} ps -q web)
WORKER_CONTAINER=\$(docker compose -f ${COMPOSE_FILE} ps -q worker)

# Check container status
echo "→ Container status:"
docker compose -f ${COMPOSE_FILE} ps | grep -E "web|worker" || true
echo ""

# Check container health if health checks are defined
echo "→ Container health:"
if docker inspect \$WEB_CONTAINER --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; then
    echo "  ✅ Web container: healthy"
elif docker inspect \$WEB_CONTAINER --format='{{.State.Status}}' 2>/dev/null | grep -q "running"; then
    echo "  ✅ Web container: running (no health check defined)"
else
    echo "  ⚠️  Web container: status unclear"
fi

if [ -n "\$WORKER_CONTAINER" ]; then
    if docker inspect \$WORKER_CONTAINER --format='{{.State.Status}}' 2>/dev/null | grep -q "running"; then
        echo "  ✅ Worker container: running"
    else
        echo "  ⚠️  Worker container: status unclear"
    fi
fi
echo ""

# Check recent logs for errors
echo "→ Recent logs (checking for errors):"
if docker logs --tail 20 \$WEB_CONTAINER 2>&1 | grep -iE "error|exception|fatal" | head -5; then
    echo "  ⚠️  Errors detected in logs - please review"
else
    echo "  ✅ No recent errors in logs"
fi

REMOTE_VERIFY

echo ""
echo "======================================================================="
echo "✅ DEPLOYMENT COMPLETE!"
echo "======================================================================="
echo ""
echo "Services:"
echo "  → Application: https://${REMOTE_HOST}"
echo "  → Health check: https://${REMOTE_HOST}/health"
echo ""
echo "Next steps:"
echo "  1. Test the changes in the application"
echo "  2. Monitor logs for any issues:"
echo "     ssh ${REMOTE_USER}@${REMOTE_HOST} 'docker compose -f ${COMPOSE_FILE} logs -f web'"
echo ""
echo "Troubleshooting:"
echo "  • View web logs:    ssh ${REMOTE_USER}@${REMOTE_HOST} 'cd ${REMOTE_PATH} && docker compose -f ${COMPOSE_FILE} logs web'"
echo "  • View worker logs: ssh ${REMOTE_USER}@${REMOTE_HOST} 'cd ${REMOTE_PATH} && docker compose -f ${COMPOSE_FILE} logs worker'"
echo "  • Check status:     ssh ${REMOTE_USER}@${REMOTE_HOST} 'cd ${REMOTE_PATH} && docker compose -f ${COMPOSE_FILE} ps'"
echo ""
