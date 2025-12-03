# Chatwoot Deployment Guide

This guide explains the deployment workflows for the Chatwoot production environment.

## Overview

We have two primary deployment scripts for different scenarios:

1. **`script/quick_rebuild.sh`** - Full Docker image rebuild
2. **`script/deploy-backend-enhanced.sh`** - Hot-patch backend code to running containers

## When to Use Each Script

### Use `quick_rebuild.sh` When:

✅ **Docker Infrastructure Changes:**
- Modified `Dockerfile.production`
- Changed system dependencies (apt packages)
- Updated Node.js or Ruby versions
- Modified build process or multi-stage build steps

✅ **Dependency Changes:**
- Updated `Gemfile` or `Gemfile.lock`
- Changed gem versions
- Added/removed Ruby dependencies

✅ **Frontend Changes:**
- Modified JavaScript/TypeScript files
- Changed CSS/SCSS files
- Updated Vite configuration
- Modified frontend build process

✅ **Initial Deployment:**
- First time deploying the application
- After major refactoring
- When containers are not running

### Use `deploy-backend-enhanced.sh` When:

✅ **Backend Code Changes Only:**
- Modified Ruby services, controllers, models
- Updated background jobs
- Changed business logic
- Added/modified API endpoints

✅ **Configuration Changes:**
- Updated routes (`config/routes.rb`)
- Modified initializers
- Changed application configuration (non-Docker)

✅ **Database Changes:**
- New migrations to run
- Schema updates

✅ **Quick Iteration:**
- Developing and testing backend features
- Hot-fixing production issues
- Rapid deployment cycles

## Script Usage

### quick_rebuild.sh

**Basic usage:**
```bash
./script/quick_rebuild.sh
```

**Clean rebuild (no cache):**
```bash
./script/quick_rebuild.sh --no-cache
```

**What it does:**
1. Connects to remote server (msp.rhaps.net)
2. Stops running containers
3. Rebuilds Docker image from Dockerfile.production
4. Starts containers with new image
5. Verifies container health
6. Reports deployment status

**Typical execution time:** 5-15 minutes (depending on cache)

**Memory requirements:**
- Build needs 4GB+ heap for Node.js/Vite
- Server should have 3.7GB RAM + 4GB swap minimum

### deploy-backend-enhanced.sh

**Basic usage:**
```bash
./script/deploy-backend-enhanced.sh
```

**What it does:**
1. Syncs backend code to remote server via rsync
2. Copies code into running containers (hot-patch)
3. Runs database migrations
4. Restarts containers to apply changes
5. Verifies deployment

**Typical execution time:** 1-3 minutes

**Requirements:**
- Containers must already be running
- Docker image must be up-to-date with dependencies

## Deployment Workflow Examples

### Scenario 1: Fixing a Bot Timeout Issue

You've fixed blocking `sleep()` calls in the bot service.

**Changes:**
- Modified `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`

**Deployment:**
```bash
./script/deploy-backend-enhanced.sh
```

**Why:** Pure Ruby code change, no dependencies or Docker changes needed.

---

### Scenario 2: Adding New Gem Dependency

You've added a new gem to process images.

**Changes:**
- Added gem to `Gemfile`
- Updated `Gemfile.lock`
- Created new service using the gem

**Deployment:**
```bash
./script/quick_rebuild.sh
```

**Why:** Gemfile changes require rebuilding the Docker image to install new dependencies.

---

### Scenario 3: Memory Configuration Update

You need to increase Node.js heap size for builds.

**Changes:**
- Modified `Dockerfile.production` line 70: `NODE_OPTIONS="--max-old-space-size=4096"`

**Deployment:**
```bash
./script/quick_rebuild.sh --no-cache
```

**Why:** Dockerfile change requires rebuild. Use `--no-cache` to ensure build changes take effect.

---

### Scenario 4: Adding New API Endpoint

You've created a new controller and route.

**Changes:**
- Added `app/controllers/api/v1/new_feature_controller.rb`
- Updated `config/routes.rb`

**Deployment:**
```bash
./script/deploy-backend-enhanced.sh
```

**Why:** Backend code and route changes, no Docker or dependency changes.

---

### Scenario 5: Frontend UI Update

You've modified the dashboard interface.

**Changes:**
- Updated Vue components in `app/javascript/dashboard/`
- Modified CSS styles

**Deployment:**
```bash
./script/quick_rebuild.sh
```

**Why:** Frontend assets require Vite build, which happens during Docker image build.

## Troubleshooting

### Common Issues and Solutions

#### Issue: "Container not running" error with deploy-backend-enhanced.sh

**Cause:** Containers aren't running when attempting hot-patch deployment.

**Solution:**
```bash
# Option 1: Start containers if they stopped
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml up -d'

# Option 2: Full rebuild if containers are problematic
./script/quick_rebuild.sh
```

---

#### Issue: Docker build fails with "exit code 134" (Out of Memory)

**Cause:** Node.js build process exceeds available memory.

**Solution:**
1. Check current memory allocation in `Dockerfile.production` line 70
2. Verify server has enough RAM + swap (need 4GB+ for heap)
3. Increase swap if needed:
```bash
ssh root@msp.rhaps.net 'free -h'  # Check available memory
```

Current configuration uses 4096MB heap size, which requires:
- 3.7GB physical RAM + 4GB swap = 7.7GB total (sufficient)

---

#### Issue: Bundler version mismatch errors

**Cause:** Dockerfile installs different bundler version than Gemfile.lock specifies.

**Solution:**
1. Check required version: `grep "BUNDLED WITH" -A 1 Gemfile.lock`
2. Update `Dockerfile.production` line 82 to match:
```dockerfile
RUN gem install bundler:2.5.16  # Match your Gemfile.lock version
```

---

#### Issue: "Could not find JavaScript runtime" error

**Cause:** Container missing Node.js for asset compilation.

**Solution:**
Node.js installation is in `Dockerfile.production` lines 21-23. If missing:
```dockerfile
curl -fsSL https://deb.nodesource.com/setup_23.x | bash - && \
apt-get install -y nodejs
```

---

#### Issue: Gems not found at runtime

**Cause:** Deployment mode installs gems to `./vendor/bundle`, but Docker only copied system gems.

**Solution:**
Ensure `Dockerfile.production` line 94 includes:
```dockerfile
COPY --from=ruby-builder /app/vendor/bundle /app/vendor/bundle
```

---

#### Issue: Docker layer caching preventing updates

**Cause:** Cached build layers not detecting dependency changes.

**Solution:**
```bash
# Force clean rebuild
./script/quick_rebuild.sh --no-cache
```

Or add cache-breaking comment in Dockerfile:
```dockerfile
# Cache breaker: 2024-12-02-001
RUN bundle install
```

---

#### Issue: Containers show "Started" but crash immediately

**Cause:** Runtime errors in application code or configuration.

**Solution:**
```bash
# Check logs
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs web'

# Check container health
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml ps'
```

## Verification Steps

After any deployment, verify the application is working:

### 1. Check Container Status
```bash
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml ps'
```

Expected output:
- `web`: Up, healthy (if health checks defined)
- `worker`: Up
- `postgres`: Up, healthy
- `redis`: Up, healthy

### 2. Check Application Health
```bash
curl https://msp.rhaps.net/health
```

Expected: `{"status":"ok"}` or similar health response

### 3. View Recent Logs
```bash
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs --tail=50 web'
```

Look for:
- ✅ No error messages
- ✅ Application started successfully
- ❌ Exceptions or error traces

### 4. Test Specific Features

For the bot timeout fix example:
1. Access Apple Messages for Business bot
2. Trigger AR file sending in conversation flow
3. Verify no Rack timeout errors occur
4. Confirm AR files are sent successfully without delays

## Best Practices

1. **Always commit changes before deploying**
   ```bash
   git add .
   git commit -m "Fix: Remove blocking sleep calls from bot service"
   git push
   ```

2. **Test locally first**
   ```bash
   # Run tests
   bundle exec rspec
   
   # Start dev server
   foreman start -f Procfile.dev
   ```

3. **Monitor logs during deployment**
   ```bash
   # In a separate terminal while deploying
   ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs -f web'
   ```

4. **Keep deployment scripts updated**
   - Document any manual fixes in script comments
   - Update scripts when infrastructure changes
   - Test scripts after major updates

5. **Use appropriate script for change type**
   - Don't use `quick_rebuild.sh` for simple code changes
   - Don't use `deploy-backend-enhanced.sh` for dependency changes

## Docker Image Build Process

Understanding the build process helps troubleshoot issues:

### Multi-stage Build

1. **asset-builder stage** (lines 6-76):
   - Installs Node.js dependencies
   - Runs Vite build for frontend assets
   - Uses 4096MB heap size for large builds

2. **ruby-builder stage** (lines 78-86):
   - Installs Ruby gems with bundler 2.5.16
   - Deploys to `./vendor/bundle`

3. **Final stage** (lines 88-110):
   - Copies assets from asset-builder
   - Copies gems from ruby-builder (both system and vendor)
   - Sets up runtime environment
   - Exposes port 3000

### Key Configuration Points

**Memory allocation (line 70):**
```dockerfile
NODE_OPTIONS="--max-old-space-size=4096"
```

**Bundler configuration (lines 82-85):**
```dockerfile
RUN gem install bundler:2.5.16 && \
    bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install --jobs=4 --retry=3
```

**Gem copy (lines 93-94):**
```dockerfile
COPY --from=ruby-builder /usr/local/bundle /usr/local/bundle
COPY --from=ruby-builder /app/vendor/bundle /app/vendor/bundle
```

## Additional Resources

- **Quick rebuild script:** `script/quick_rebuild.sh`
- **Backend deployment script:** `script/deploy-backend-enhanced.sh`
- **Dockerfile:** `Dockerfile.production`
- **Docker Compose:** `docker-compose.production.yml`

## Support

If you encounter issues not covered in this guide:

1. Check container logs for detailed error messages
2. Verify server resources (memory, disk space)
3. Review recent code changes for issues
4. Consider rolling back to last known good state

## Changelog

- **2024-12-02**: Initial deployment guide created
  - Documented quick_rebuild.sh and deploy-backend-enhanced.sh
  - Added troubleshooting for bot timeout deployment
  - Included memory configuration guidance