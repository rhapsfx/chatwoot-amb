# Chatwoot Deployment Guide

This guide explains the **simplified deployment workflow** for the Chatwoot production environment after cleanup and optimization.

## Overview

We have **2 primary deployment scripts** for different scenarios:

1. **`script/deploy-production-docker.sh`** - Full Docker image rebuild (Dockerfile/dependencies/frontend changes)
2. **`script/deploy-production-docker.sh`** - Hot-patch backend code (Ruby-only changes)

Plus **2 specialized utilities**:
3. **`script/deploy-production-docker.sh`** - Comprehensive backend + Apple Pay + n8n + bots
4. **`script/deploy-apple-pay-certs.sh`** - Apple Pay certificate deployment

---

## Decision Flowchart

```
Need to deploy changes?
│
├─ Changed Dockerfile.production? ────────────────────────→ deploy-production-docker.sh
├─ Changed Gemfile/package.json dependencies? ────────────→ deploy-production-docker.sh
├─ Changed Vue/JavaScript/CSS (frontend)? ────────────────→ deploy-production-docker.sh
├─ Changed Node.js or Ruby versions? ─────────────────────→ deploy-production-docker.sh
│
├─ Changed Ruby code ONLY (services/controllers/models)? ─→ deploy-production-docker.sh
├─ Changed routes or initializers? ───────────────────────→ deploy-production-docker.sh
├─ Need to run database migrations? ──────────────────────→ deploy-production-docker.sh
│
├─ Deploying Apple Pay/n8n/bot templates together? ───────→ deploy-production-docker.sh
└─ Updating Apple Pay certificates? ──────────────────────→ deploy-apple-pay-certs.sh
```

---

## 1. deploy-production-docker.sh - Full Docker Rebuild

### When to Use

Use this when you've changed:
- ✅ `Dockerfile.production` (any Docker configuration)
- ✅ Dependencies (`Gemfile`, `Gemfile.lock`, `package.json`, `pnpm-lock.yaml`)
- ✅ Frontend code (Vue components, JavaScript, TypeScript, CSS)
- ✅ Vite configuration or build process
- ✅ System packages (Node.js, Ruby versions)
- ✅ **Any code that affects the Docker image**

### Usage

```bash
# Standard rebuild (uses Docker layer cache)
./script/deploy-production-docker.sh

# Clean rebuild (no cache - for infrastructure changes)
./script/deploy-production-docker.sh --no-cache
```

### What It Does

1. Syncs `Dockerfile.production` to production server
2. Builds Docker image **on the server** (AMD64 architecture)
3. Compiles frontend assets with Vite
4. Installs Ruby gems and Node.js packages
5. Stops existing containers
6. Removes old containers
7. Starts new containers with fresh image
8. Verifies container health

### Execution Time

- **With cache**: 5-10 minutes
- **Without cache** (`--no-cache`): 15-20 minutes

### Server Requirements

- **Memory**: 2.0GB free RAM + 3.5GB free swap (currently available)
- **Disk**: 11GB available (currently at 86% usage)
- **Note**: Builds on server because it's AMD64 architecture (Mac is ARM64)

### Important Notes

⚠️ **Volume Mounts**: The production server uses bind mounts for `/app/public/vite`. After rebuilding, you may need to extract new assets from the image to the host if the button or assets don't appear:

```bash
# If assets don't update after rebuild, run this on server:
ssh root@msp.rhaps.net 'bash -s' << 'SCRIPT'
cd /opt/chatwoot
docker run --rm --user root -v /opt/chatwoot/public:/host_public chatwoot:production \
  bash -c "cp -r /app/public/vite /host_public/ && chown -R $(stat -c '%u:%g' /opt/chatwoot/public) /host_public/vite"
docker compose -f docker-compose.production.yml restart web worker
SCRIPT
```

---

## 2. deploy-production-docker.sh - Hot-Patch Backend

### When to Use

Use this when you've changed **Ruby code ONLY**:
- ✅ Services (`app/services/`)
- ✅ Controllers (`app/controllers/`)
- ✅ Models (`app/models/`)
- ✅ Background jobs (`app/jobs/`)
- ✅ Routes (`config/routes.rb`)
- ✅ Initializers (`config/initializers/`)
- ✅ Database migrations (`.rb` files in `db/migrate/`)

### Usage

```bash
./script/deploy-production-docker.sh
```

### What It Does

1. Syncs Ruby code to production server via rsync
2. Copies code into running containers (hot-patch)
3. Runs pending database migrations
4. Restarts web and worker containers
5. Verifies deployment

### Execution Time

- **Typical**: 1-3 minutes

### Requirements

- Containers must already be running
- Docker image must be up-to-date with dependencies

### When NOT to Use

❌ **Do NOT use for**:
- Frontend changes (Vue/JS/CSS)
- Dependency changes (Gemfile/package.json)
- Dockerfile changes
- Node.js or Ruby version updates

---

## 3. deploy-production-docker.sh - Comprehensive Deployment

### When to Use

Use this for **complex deployments** involving multiple subsystems:
- ✅ Backend code changes + Apple Pay configuration
- ✅ Backend code changes + n8n custom nodes
- ✅ Backend code changes + Acoustic House Bot templates
- ✅ Backend code changes + Apple Maps tokens
- ✅ **Any feature requiring multiple component updates**

### Usage

```bash
./script/deploy-production-docker.sh
```

### What It Does

Everything in `deploy-production-docker.sh` PLUS:
- Deploys Apple Pay certificates and configuration
- Updates n8n custom AMB nodes
- Syncs bot templates
- Updates Apple Maps API tokens
- Comprehensive verification checks

### Execution Time

- **Typical**: 3-5 minutes

---

## 4. deploy-apple-pay-certs.sh - Certificate Management

### When to Use

Use this **only** when updating Apple Pay certificates:
- ✅ Renewing Apple Pay merchant certificates
- ✅ Updating payment processing certificates

### Usage

```bash
./script/deploy-apple-pay-certs.sh
```

---

## Deployment Workflow Examples

### Scenario 1: Added "Copy for Custom Payload" Button

**Changes**:
- Modified `ApplePayloadModal.vue` (frontend Vue component)
- Modified `MessageList.vue` (frontend Vue component)
- Added 8 circle.png images to `public/apple-messages/`

**Script**: `deploy-production-docker.sh`

**Why**: Frontend (Vue) changes require Vite build, which is baked into Docker image.

**Time**: 15-20 minutes (no-cache recommended for Dockerfile fixes)

```bash
# Ensure circle.png images are committed
git add public/apple-messages/*.png
git commit -m "feat: add circle.png images for Apple Messages modal"

# Deploy
./script/deploy-production-docker.sh --no-cache
```

**Post-deployment**:
- Hard refresh browser: `Cmd+Shift+R` (Mac) or `Ctrl+Shift+R` (Windows)
- Verify button appears in modal
- Verify images load without 404 errors

---

### Scenario 2: Fixed Bot Timeout Issue

**Changes**:
- Modified `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`

**Script**: `deploy-production-docker.sh`

**Why**: Ruby service change only, no Docker or frontend changes.

**Time**: 1-3 minutes

```bash
./script/deploy-production-docker.sh
```

---

### Scenario 3: Added New Gem Dependency

**Changes**:
- Added `gem 'new_gem'` to `Gemfile`
- Ran `bundle install` (updated `Gemfile.lock`)
- Created new service using the gem

**Script**: `deploy-production-docker.sh`

**Why**: Gemfile changes require rebuilding Docker image to install dependencies.

**Time**: 5-10 minutes (with cache)

```bash
./script/deploy-production-docker.sh
```

---

### Scenario 4: Updated Dockerfile Memory Settings

**Changes**:
- Modified `Dockerfile.production` line 72: `NODE_OPTIONS="--max-old-space-size=4096"`

**Script**: `deploy-production-docker.sh --no-cache`

**Why**: Dockerfile infrastructure change requires clean rebuild.

**Time**: 15-20 minutes

```bash
./script/deploy-production-docker.sh --no-cache
```

---

### Scenario 5: Added New API Endpoint

**Changes**:
- Added `app/controllers/api/v1/new_feature_controller.rb`
- Updated `config/routes.rb`

**Script**: `deploy-production-docker.sh`

**Why**: Backend code and routes only, no Docker or dependency changes.

**Time**: 1-3 minutes

```bash
./script/deploy-production-docker.sh
```

---

## Troubleshooting

### Issue: Frontend Changes Don't Appear After `deploy-production-docker.sh`

**Cause**: Docker bind mount `/app/public/vite` is overriding image assets with old host files.

**Solution**: Extract new Vite assets from image to host:

```bash
ssh root@msp.rhaps.net 'bash -s' << 'SCRIPT'
cd /opt/chatwoot
# Backup old assets
[ -d "public/vite" ] && mv public/vite public/vite.backup.$(date +%Y%m%d_%H%M%S)
# Extract from image
docker run --rm --user root -v /opt/chatwoot/public:/host_public chatwoot:production \
  bash -c "cp -r /app/public/vite /host_public/ && chown -R $(stat -c '%u:%g' /opt/chatwoot/public) /host_public/vite"
# Restart
docker compose -f docker-compose.production.yml restart web worker
SCRIPT
```

Then hard refresh browser: `Cmd+Shift+R`

---

### Issue: "Container not running" with `deploy-production-docker.sh`

**Cause**: Containers aren't running.

**Solution**:
```bash
# Start containers
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml up -d'

# Or rebuild if image is missing
./script/deploy-production-docker.sh
```

---

### Issue: Build fails with "exit code 134" (Out of Memory)

**Cause**: Server ran out of memory during build.

**Solution**:
```bash
# Check memory
ssh root@msp.rhaps.net 'free -h'

# If low, restart containers to free memory
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml restart web worker'

# Then rebuild
./script/deploy-production-docker.sh
```

---

## Verification Steps

After ANY deployment:

### 1. Check Container Status

```bash
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml ps'
```

**Expected**:
- `web`: Up, healthy
- `worker`: Up
- `postgres`: Up, healthy
- `redis`: Up, healthy

### 2. Check Application Health

```bash
curl https://msp.rhaps.net/health
```

**Expected**: `{"status":"ok"}` or similar

### 3. View Recent Logs

```bash
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs --tail=50 web'
```

**Look for**:
- ✅ No error messages
- ✅ Application started successfully
- ❌ Exceptions or error traces

### 4. Test Specific Features

- Access the deployed feature
- Verify functionality works
- Check browser console for errors
- Verify no 404 errors for assets

---

## Best Practices

1. **Always commit changes before deploying**
   ```bash
   git add .
   git commit -m "feat: description of changes"
   git push
   ```

2. **Test locally first** (when possible)
   ```bash
   bundle exec rspec
   pnpm test
   ./script/dev-server.sh start
   ```

3. **Monitor logs during deployment**
   ```bash
   # In separate terminal
   ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs -f web'
   ```

4. **Use appropriate script for change type**
   - Dockerfile/dependencies/frontend → `deploy-production-docker.sh`
   - Ruby code only → `deploy-production-docker.sh`
   - Don't use rebuild for simple code changes

5. **Hard refresh browser after frontend deployments**
   - Mac: `Cmd+Shift+R`
   - Windows: `Ctrl+Shift+R`
   - Or use incognito/private window

---

## Server Specifications

**Production Server**: `msp.rhaps.net` (root@msp.rhaps.net)

### Resources

```
Memory:  3.7GB RAM (2.0GB free)
Swap:    4.0GB (3.5GB free)
Disk:    75GB total (11GB available, 86% used)
```

### Architecture

- **Server**: AMD64 (Intel x86_64)
- **Docker**: Standard Docker (not vessel/buildx)
- **Build Location**: On server (local Mac is ARM64)

### Bind Mounts

The production setup uses bind mounts:
- `./storage:/app/storage`
- `./log:/app/log`
- `./tmp:/app/tmp`
- `./public/vite:/app/public/vite:ro` ⚠️ **Can cause asset issues**

---

## Changelog

- **2024-12-14**: Complete rewrite after deployment workflow optimization
  - Removed 28 deprecated scripts (vessel/container experiments)
  - Established `deploy-production-docker.sh` + `deploy-production-docker.sh` as core workflow
  - Documented bind mount asset extraction workaround
  - Added comprehensive troubleshooting section
  - Aligned with actual working deployment process

- **2024-12-13**: Added deploy-local-build.sh workflow (deprecated - vessel issues)

- **2024-12-02**: Initial deployment guide created
