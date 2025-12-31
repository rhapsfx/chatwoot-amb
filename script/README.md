# Deployment Scripts

This directory contains scripts for deploying and managing the Chatwoot production environment.

## Available Scripts

### Production Deployment

#### `quick_rebuild.sh`
**Full Docker image rebuild and deployment**

```bash
./script/quick_rebuild.sh              # Standard rebuild with cache
./script/quick_rebuild.sh --no-cache   # Clean rebuild without cache
```

**Use when:**
- Dockerfile changes
- Dependency updates (Gemfile, package.json)
- Frontend asset changes
- System package updates
- Initial deployment

**Time:** 5-15 minutes  
**Connects to:** root@msp.rhaps.net  
**See also:** [Deployment Guide](../docs/DEPLOYMENT_GUIDE.md)

---

#### `deploy-backend-enhanced.sh`
**Hot-patch backend code to running containers**

```bash
./script/deploy-backend-enhanced.sh
```

**Use when:**
- Ruby code changes only (services, controllers, models)
- Configuration updates (routes, initializers)
- Database migrations
- Quick iterations during development

**Time:** 1-3 minutes  
**Requires:** Containers must be running  
**See also:** [Deployment Guide](../docs/DEPLOYMENT_GUIDE.md)

---

### Legacy/Archive Scripts

#### `build_and_deploy_from_mac.sh`
Legacy deployment script. Use `quick_rebuild.sh` instead.

#### `hotfix_bot_timeout.sh`
Archive: Original fix for bot timeout issue. Functionality merged into main codebase.

---

## Quick Decision Guide

**Q: What did I change?**

| Change Type | Script to Use |
|------------|---------------|
| Ruby files (services, controllers, models) | `deploy-backend-enhanced.sh` |
| Routes or initializers | `deploy-backend-enhanced.sh` |
| Database migrations | `deploy-backend-enhanced.sh` |
| Gemfile or Gemfile.lock | `quick_rebuild.sh` |
| Dockerfile.production | `quick_rebuild.sh --no-cache` |
| Frontend (JS, CSS, Vue) | `quick_rebuild.sh` |
| System packages (apt) | `quick_rebuild.sh --no-cache` |
| Node.js or Ruby version | `quick_rebuild.sh --no-cache` |

---

## Documentation

- **[Deployment Guide](../docs/DEPLOYMENT_GUIDE.md)** - Complete deployment workflows and examples
- **[Docker Troubleshooting](../docs/DOCKER_BUILD_TROUBLESHOOTING.md)** - Solutions for common build issues

---

## Server Configuration

**Production Server:** msp.rhaps.net  
**User:** root  
**Deploy Path:** /opt/chatwoot  
**Compose File:** docker-compose.production.yml

**Containers:**
- `web` - Rails application (port 3000→8080)
- `worker` - Sidekiq background jobs
- `postgres` - PostgreSQL database
- `redis` - Redis cache/queue

---

## Common Commands

### Check deployment status
```bash
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml ps'
```

### View logs
```bash
# Web logs
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs -f web'

# Worker logs
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs -f worker'
```

### Restart containers
```bash
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml restart web worker'
```

### Check health
```bash
curl https://msp.rhaps.net/health
```

### Rails console
```bash
ssh root@msp.rhaps.net 'docker exec -it $(docker compose -f docker-compose.production.yml ps -q web) bundle exec rails console'
```

---

## Troubleshooting

### Build fails with "exit code 134"
**Out of memory error**

Solution: Check [Docker Troubleshooting Guide](../docs/DOCKER_BUILD_TROUBLESHOOTING.md#out-of-memory-errors)

Current config uses 4096MB heap for Node.js builds.

---

### "Container not running" error
**Containers stopped or crashed**

```bash
# Check status
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml ps'

# View logs
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs web'

# Restart if needed
./script/quick_rebuild.sh
```

---

### Hot-patch fails with dependency errors
**Image missing required dependencies**

Solution: Use full rebuild instead
```bash
./script/quick_rebuild.sh
```

---

## Development History

### Recent Updates (2024-12-02)

**Bot Timeout Fix Deployment:**
- Removed blocking `sleep()` calls from bot service
- Encountered and solved multiple Docker build issues
- Updated deployment scripts with learnings

**Key Infrastructure Fixes:**
- Increased Node.js heap to 4096MB for builds
- Fixed bundler version to 2.5.16 (matches Gemfile.lock)
- Added vendor/bundle copy for deployment mode gems
- Installed Node.js in base image for ExecJS

**Script Improvements:**
- Enhanced `quick_rebuild.sh` with `--no-cache` option
- Rewrote `deploy-backend-enhanced.sh` as generic hot-patch tool
- Created comprehensive deployment documentation

---

## Best Practices

1. **Test locally first** - Run tests before deploying
2. **Commit changes** - Always commit before deployment
3. **Use correct script** - Match script to change type
4. **Monitor logs** - Watch logs during deployment
5. **Verify deployment** - Check health and functionality

---

## Support

For issues not covered in documentation:

1. Check [Deployment Guide](../docs/DEPLOYMENT_GUIDE.md)
2. Review [Docker Troubleshooting](../docs/DOCKER_BUILD_TROUBLESHOOTING.md)
3. Examine container logs
4. Verify server resources
5. Document new issues for future reference

---

## Related Files

- `Dockerfile.production` - Production Docker image definition
- `docker-compose.production.yml` - Container orchestration
- `.env` - Environment variables (not in git)
- `config/database.yml` - Database configuration