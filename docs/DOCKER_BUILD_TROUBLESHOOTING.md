# Docker Build Troubleshooting Guide

This guide documents common Docker build issues encountered during Chatwoot deployment and their solutions.

## Table of Contents
1. [Out of Memory Errors](#out-of-memory-errors)
2. [Bundler Version Mismatches](#bundler-version-mismatches)
3. [Missing Gems at Runtime](#missing-gems-at-runtime)
4. [JavaScript Runtime Errors](#javascript-runtime-errors)
5. [Docker Layer Caching Issues](#docker-layer-caching-issues)
6. [Container Health vs Running Status](#container-health-vs-running-status)

---

## Out of Memory Errors

### Symptoms
```
Build failed with exit code 134
SIGABRT signal
JavaScript heap out of memory
```

### Root Cause
Node.js Vite build process exceeds allocated memory during frontend asset compilation.

### Diagnosis
1. Check server memory:
```bash
ssh root@msp.rhaps.net 'free -h'
```

Expected output:
```
              total        used        free      shared  buff/cache   available
Mem:          3.7Gi       1.5Gi       500Mi       100Mi       1.7Gi       2.0Gi
Swap:         4.0Gi       200Mi       3.8Gi
```

2. Check current heap allocation in `Dockerfile.production`:
```bash
grep "max-old-space-size" Dockerfile.production
```

### Solution
Increase Node.js heap size to match available memory (RAM + swap):

**In `Dockerfile.production` (line ~70):**
```dockerfile
# Build frontend assets with Vite directly (with increased memory limit)
# Using 4GB heap size since server has 3.7GB RAM + 4GB swap available
RUN NODE_OPTIONS="--max-old-space-size=4096" npx vite build --mode=production
```

**Memory sizing guidelines:**
- **2048MB**: Sufficient for small to medium projects (< 500 files)
- **4096MB**: Required for large projects with many dependencies
- **Rule of thumb**: Set to 50-70% of (Physical RAM + Swap)

**Example calculation:**
- Server RAM: 3.7GB
- Server Swap: 4GB
- Total available: 7.7GB
- Safe heap size: 4GB (52% of total)

### Prevention
- Monitor build memory usage during development
- Adjust heap size before deploying to new servers
- Consider increasing swap if builds consistently fail

---

## Bundler Version Mismatches

### Symptoms
```
Could not find 'bundler' (2.5.16)
Rails command not found
Gem::LoadError
```

### Root Cause
Dockerfile installs different bundler version than `Gemfile.lock` specifies.

### Diagnosis
1. Check required bundler version:
```bash
grep "BUNDLED WITH" -A 1 Gemfile.lock
```

Output example:
```
BUNDLED WITH
   2.5.16
```

2. Check Dockerfile bundler installation:
```bash
grep "gem install bundler" Dockerfile.production
```

### Solution
Match bundler version in Dockerfile to Gemfile.lock:

**In `Dockerfile.production` (line ~82):**
```dockerfile
# Install Ruby gems (using bundler version from Gemfile.lock)
# Updated 2025-12-02 to fix bundler version mismatch
RUN gem install bundler:2.5.16 && \
    bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install --jobs=4 --retry=3
```

### Best Practice
Add comment with update date when changing bundler version to help track changes:
```dockerfile
# Updated YYYY-MM-DD to fix bundler version mismatch
RUN gem install bundler:X.Y.Z
```

---

## Missing Gems at Runtime

### Symptoms
```
Could not find gem 'rails'
LoadError: cannot load such file
Bundler could not find compatible versions
```

### Root Cause
Bundler deployment mode installs gems to `./vendor/bundle` instead of system `/usr/local/bundle`, but Dockerfile only copies system location.

### Diagnosis
1. Check where gems are installed in build stage:
```bash
# In ruby-builder stage
grep "deployment" Dockerfile.production
```

2. Check what's copied in final stage:
```bash
grep "COPY --from=ruby-builder" Dockerfile.production
```

### Solution
Copy gems from BOTH locations in Dockerfile:

**In `Dockerfile.production` (lines ~92-94):**
```dockerfile
# Copy installed gems from ruby-builder
COPY --from=ruby-builder /usr/local/bundle /usr/local/bundle
COPY --from=ruby-builder /app/vendor/bundle /app/vendor/bundle
```

### Why Both Locations?
- `bundle config set --local deployment 'true'` → Installs to `./vendor/bundle`
- Some gems may still install to `/usr/local/bundle`
- Both locations must be copied to ensure all gems are available

### Verification
After rebuild, check if gems are accessible:
```bash
ssh root@msp.rhaps.net 'docker exec $(docker compose -f docker-compose.production.yml ps -q web) bundle exec rails --version'
```

---

## JavaScript Runtime Errors

### Symptoms
```
ExecJS::RuntimeUnavailable: Could not find a JavaScript runtime
Uglifier requires a JavaScript runtime
ExecJS could not find Node.js
```

### Root Cause
Rails asset precompilation requires JavaScript runtime (Node.js), but production image doesn't have it installed.

### Diagnosis
Check if Node.js is installed in container:
```bash
ssh root@msp.rhaps.net 'docker exec $(docker compose -f docker-compose.production.yml ps -q web) node --version'
```

### Solution
Install Node.js in base Docker image:

**In `Dockerfile.production` (lines ~18-23):**
```dockerfile
# Install essential system packages including Node.js for ExecJS runtime
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    # ... other packages ...
    curl \
    gnupg \
    ca-certificates && \
    curl -fsSL https://deb.nodesource.com/setup_23.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*
```

### Why Node.js in Production?
Even though Vite handles most asset compilation, some gems (like uglifier) require a JavaScript runtime for:
- Asset precompilation
- JavaScript minification
- Runtime transformations

---

## Docker Layer Caching Issues

### Symptoms
- Code changes not reflected in container
- Old dependencies still present after update
- Build seems to skip steps that should run

### Root Cause
Docker caches build layers based on file content/timestamps. If files haven't "changed" (according to Docker), cached layers are reused.

### Diagnosis
Check if build is using cache:
```bash
# During build, look for:
# ---> Using cache
# vs
# ---> Running in abc123...
```

### Solution 1: Force Clean Build
```bash
./script/quick_rebuild.sh --no-cache
```

This rebuilds all layers without using cache (slower but guaranteed fresh).

### Solution 2: Cache-Breaking Comment
Add dated comment in Dockerfile before problematic step:

```dockerfile
# Cache breaker: 2024-12-02-001  ← Update this timestamp/counter
RUN bundle install --jobs=4 --retry=3
```

Changing the comment forces Docker to rebuild from that point forward.

### When to Use Each
- **--no-cache**: After Gemfile changes, system package updates
- **Cache-breaking comment**: After manual fixes, when cache is suspect

### Example: Gem Installation Issue
```dockerfile
# ruby-builder stage
FROM chatwoot-base as ruby-builder

# Copy dependency files
COPY Gemfile Gemfile.lock ./

# Force cache invalidation after Gemfile.lock update - 2024-12-02
RUN gem install bundler:2.5.16 && \
    bundle config set --local deployment 'true' && \
    bundle install --jobs=4 --retry=3
```

---

## Container Health vs Running Status

### Symptoms
- Container shows "Started" but application isn't responding
- Container immediately restarts after starting
- Health check shows "unhealthy"

### Diagnosis

**1. Check container status:**
```bash
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml ps'
```

Possible statuses:
- `Up` - Container running (but may not be healthy)
- `Up (healthy)` - Container running AND health check passing
- `Restarting` - Container crashing and restarting
- `Exited` - Container stopped

**2. Check container health:**
```bash
ssh root@msp.rhaps.net 'docker inspect $(docker compose -f docker-compose.production.yml ps -q web) --format="{{.State.Health.Status}}"'
```

Possible health statuses:
- `healthy` - Health check passing ✅
- `unhealthy` - Health check failing ❌
- `starting` - Health check in progress ⏳
- `none` - No health check defined

**3. View recent logs:**
```bash
ssh root@msp.rhaps.net 'docker logs --tail 100 $(docker compose -f docker-compose.production.yml ps -q web)'
```

Look for:
- Exception traces
- "Exiting" messages
- Missing environment variables
- Database connection errors

### Common Issues and Solutions

#### Issue: Container running but unhealthy
**Cause:** Application started but health endpoint failing

**Solution:**
```bash
# Check health endpoint
curl https://msp.rhaps.net/health

# Check if Rails is ready
ssh root@msp.rhaps.net 'docker exec $(docker compose -f docker-compose.production.yml ps -q web) bundle exec rails runner "puts \"Rails OK\""'
```

#### Issue: Container immediately exits
**Cause:** Runtime error in application code

**Solution:**
```bash
# View full logs
ssh root@msp.rhaps.net 'docker logs $(docker compose -f docker-compose.production.yml ps -q web) 2>&1 | less'

# Common causes:
# - Missing environment variables
# - Database migration needed
# - Syntax errors in code
# - Missing dependencies
```

#### Issue: Container stays in "starting" health status
**Cause:** Application slow to start or health check misconfigured

**Solution:**
```bash
# Increase health check intervals in docker-compose.production.yml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
  interval: 30s          # ← Increase if needed
  timeout: 10s           # ← Increase if needed
  start_period: 60s      # ← Increase for slow startup
  retries: 3
```

### Verification Checklist

After any deployment, verify ALL of these:

1. ✅ Container status is "Up"
2. ✅ Health status is "healthy" (or "none" if no health check)
3. ✅ Recent logs show no errors
4. ✅ Application responds to HTTP requests
5. ✅ Database connection working
6. ✅ Background workers running (if applicable)

---

## Quick Reference: Common Fix Commands

### Rebuild with no cache
```bash
./script/quick_rebuild.sh --no-cache
```

### Check container logs
```bash
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs --tail=100 web'
```

### Restart containers
```bash
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml restart web worker'
```

### Check container status
```bash
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml ps'
```

### Verify Rails console access
```bash
ssh root@msp.rhaps.net 'docker exec -it $(docker compose -f docker-compose.production.yml ps -q web) bundle exec rails console'
```

### Check server resources
```bash
ssh root@msp.rhaps.net 'free -h && df -h'
```

---

## Prevention Best Practices

1. **Always test builds locally first** (if possible)
2. **Monitor resource usage during builds**
3. **Keep Dockerfile comments updated with change dates**
4. **Document manual fixes in commit messages**
5. **Use version control for Dockerfile changes**
6. **Test deployments in staging before production**
7. **Keep dependency versions synchronized** (bundler, Node.js)

---

## Related Documentation

- [Main Deployment Guide](./DEPLOYMENT_GUIDE.md)
- [Quick Rebuild Script](../script/quick_rebuild.sh)
- [Backend Deployment Script](../script/deploy-backend-enhanced.sh)
- [Production Dockerfile](../Dockerfile.production)

---

## Support

If you encounter issues not covered here:

1. Check container logs for detailed errors
2. Verify server resources (memory, disk)
3. Review recent Dockerfile/dependency changes
4. Try clean rebuild with `--no-cache`
5. Document the issue and solution for future reference

## Changelog

- **2024-12-02**: Initial troubleshooting guide
  - Documented memory, bundler, and gem installation issues
  - Added container health diagnosis procedures
  - Included quick reference commands