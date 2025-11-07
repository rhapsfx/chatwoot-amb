# Chatwoot Production Deployment - Summary

## What We Accomplished

✅ Fixed Apple Messages for Business icon display
✅ Fixed translation/i18n compilation for production
✅ Set up Nginx Proxy Manager with Let's Encrypt SSL
✅ Configured Docker networking between services
✅ Fixed persistent PID file issues
✅ Mounted Vite assets as volumes for persistence

## Production Setup

### Server Details
- **URL**: https://msp.rhaps.net
- **Server IP**: 82.64.228.224
- **Nginx Proxy Manager**: http://msp.rhaps.net:81

### Services Running
- **Chatwoot Web**: Port 8080 (internal), Port 3000 (mapped)
- **Chatwoot Worker**: Sidekiq background jobs
- **PostgreSQL**: Port 5432
- **Redis**: Port 6379
- **Nginx Proxy Manager**: Ports 80, 443, 81

### Network Configuration
- Chatwoot services: `chatwoot_default` network (172.19.0.x)
- Nginx Proxy Manager: `npm-network` (172.20.0.x)
- Web container connected to both networks for cross-communication

## Deployment Scripts

### Backend Deployment (Models, Controllers, Services, Migrations) - Recommended
```bash
./script/deploy-backend-changes-safe.sh
```
**Use this for**: Custom roles, policies, services, API endpoints, database migrations, Enterprise features
- Syncs backend code (app/, enterprise/, config/, db/migrate/, lib/)
- Copies into running containers
- Runs database migrations automatically
- Restarts web and worker services
- **Safe**: Preserves Apple Pay config, certs, and .env files
- **Enterprise**: Includes Enterprise edition features (custom roles, etc.)

### Asset Deployment (Frontend Only)
```bash
./script/deploy-assets-only.sh
```
**Use this for**: Vue components, styles, JavaScript changes
- Builds Vite assets locally
- Syncs to server
- Copies into running container
- Restarts web service

### Alternative Backend Deployment (Less Safe)
```bash
./script/deploy-backend-changes.sh
```
**Note**: Use `deploy-backend-changes-safe.sh` instead unless you have specific reasons

## Deploying Custom Roles

### Initial Deployment
```bash
# 1. Deploy backend code and run migrations
./script/deploy-backend-changes-safe.sh

# 2. Verify custom roles table was created
ssh root@msp.rhaps.net 'docker exec chatwoot-web rails runner "puts \"Custom roles table exists: #{ActiveRecord::Base.connection.tables.include?(\"custom_roles\")}\""'

# 3. Enable custom roles feature for your account
ssh root@msp.rhaps.net 'docker exec chatwoot-web rails runner "
account = Account.first
account.enable_features(\"custom_roles\")
account.save!
puts \"Custom roles enabled for account #{account.id}\"
"'

# 4. Verify deployment
ssh root@msp.rhaps.net 'docker exec chatwoot-web rails runner "
puts \"=== Custom Roles Status ===\"
puts \"Model loaded: #{defined?(CustomRole) ? \"Yes\" : \"No\"}\"
puts \"Table exists: #{ActiveRecord::Base.connection.tables.include?(\"custom_roles\")}\"
puts \"Feature enabled: #{Account.first.feature_flags[\"custom_roles\"]}\"
puts \"Total custom roles: #{CustomRole.count}\"
"'
```

### Post-Deployment Verification

**Check files were deployed**:
```bash
ssh root@msp.rhaps.net "docker exec chatwoot-web ls -la app/models/custom_role.rb"
ssh root@msp.rhaps.net "docker exec chatwoot-web ls -la app/policies/custom_role_policy.rb"
```

**Check database migration status**:
```bash
ssh root@msp.rhaps.net "docker exec chatwoot-web rails runner 'puts ActiveRecord::Base.connection.columns(\"custom_roles\").map(&:name).join(\", \")'"
```

**Test in Rails console**:
```bash
ssh root@msp.rhaps.net "docker exec -it chatwoot-web rails console"
```
Then run:
```ruby
# Check feature is enabled
Account.first.feature_flags['custom_roles']

# Create a test custom role
role = CustomRole.create!(
  account: Account.first,
  name: 'Test Role',
  description: 'Test custom role',
  permissions: { 'conversations' => ['view', 'create'] }
)

# Verify it was created
CustomRole.count
```

## Key Configuration Files

### docker-compose.production.yml
- Uses existing `chatwoot:production` image
- Mounts volumes for persistence:
  - `./storage` → container storage
  - `./log` → application logs
  - `./tmp` → temp files and PID
  - `./public/vite` → compiled frontend assets (read-only)
- Auto-removes stale PID file on startup
- Connected to both networks

### Database Credentials
- Database: `chatwoot_production`
- Username: `chatwoot_user`
- Password: `cacVej-beghoz-tuzjo6`

## Maintenance Commands

### Restart Services
```bash
ssh root@msp.rhaps.net "cd /opt/chatwoot && docker compose -f docker-compose.production.yml restart web"
```

### View Logs
```bash
ssh root@msp.rhaps.net "cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs web --tail=50 -f"
```

### Check Service Status
```bash
ssh root@msp.rhaps.net "cd /opt/chatwoot && docker compose -f docker-compose.production.yml ps"
```

### Deploy Backend Changes
```bash
./script/deploy-backend-changes-safe.sh
```

### Deploy Frontend Assets
```bash
./script/deploy-assets-only.sh
```

## Important Notes

1. **PID File**: Automatically cleaned on container start
2. **Assets**: Mounted as volume from host, persist across restarts
3. **Networks**: Web container must be on both networks
4. **SSL**: Auto-renewed by Nginx Proxy Manager via Let's Encrypt
5. **Firewall**: Hetzner Cloud firewall has ports 22, 80, 81, 443 open

## Troubleshooting

### 502 Bad Gateway
- Check if web container is running
- Verify network connectivity between nginx-proxy-manager and chatwoot-web
- Check Nginx Proxy Manager logs

### 500 Server Error
- Check for missing Vite assets
- Run `./deploy-assets-only.sh`
- Check Rails logs for errors

### PID File Issues
- Should be auto-fixed by docker-compose command
- Manual fix: `ssh root@msp.rhaps.net "rm -f /opt/chatwoot/tmp/pids/server.pid"`

## Success Criteria Met

✅ Apple Messages for Business icon displays correctly
✅ All translations compiled and working
✅ HTTPS with valid Let's Encrypt certificate
✅ Services auto-restart on failure
✅ Assets persist across container restarts
✅ Production-ready deployment workflow established

---

**Deployment Date**: October 4, 2025
**Stack**: Rails 7.1.5.2, Vue 3, Vite, PostgreSQL 15, Redis 7
**Infrastructure**: Docker, Nginx Proxy Manager, Hetzner Cloud



  Live logs (follow mode):
  ssh root@msp.rhaps.net "cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs web -f"

  Last 50 lines:
  ssh root@msp.rhaps.net "cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs web --tail=50"

  Last 100 lines with timestamps:
  ssh root@msp.rhaps.net "cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs web --tail=100 -t"

  All services logs:
  ssh root@msp.rhaps.net "cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs --tail=50"

  Worker logs:
  ssh root@msp.rhaps.net "cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs worker --tail=50"

  Search for errors:
  ssh root@msp.rhaps.net "cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs web --tail=200 | grep -i  error"

  Inside the container (Rails production log):
  ssh root@msp.rhaps.net "docker exec chatwoot-web tail -f /app/log/production.log"