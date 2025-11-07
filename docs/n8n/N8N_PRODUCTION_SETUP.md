# n8n Production Setup Guide

This guide shows how to set up n8n in production as a separate Docker environment that integrates with Chatwoot.

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                Nginx Proxy Manager                  │
│  https://msp.rhaps.net → Chatwoot                  │
│  https://n8n.msp.rhaps.net → n8n                   │
└─────────────────────────────────────────────────────┘
                     │
          ┌──────────┴──────────┐
          │                     │
    ┌─────▼─────┐         ┌─────▼─────┐
    │ Chatwoot  │◄────────┤    n8n    │
    │  Docker   │  Network│  Docker   │
    │  /opt/    │  Bridge │  /opt/n8n/│
    │  chatwoot │         │           │
    └───────────┘         └───────────┘
```

**Key Components**:
- **Chatwoot**: `/opt/chatwoot/` - Rails app with bot API
- **n8n**: `/opt/n8n/` - Workflow automation in separate directory
- **Network**: Docker bridge network for inter-container communication
- **Nginx Proxy Manager**: SSL termination and reverse proxy for both services

---

## Step 1: Create n8n Directory Structure

```bash
ssh root@msp.rhaps.net

# Create directory structure
mkdir -p /opt/n8n/data/custom/node_modules
cd /opt/n8n
```

**Directory Layout**:
```
/opt/n8n/
├── docker-compose.yml          # n8n container config
├── .env                         # Environment variables
└── data/                        # Persistent data (mounted volume)
    ├── custom/
    │   └── node_modules/
    │       └── n8n-nodes-chatwoot-amb/  # Custom AMB nodes
    └── [n8n database files]
```

---

## Step 2: Create docker-compose.yml

Create `/opt/n8n/docker-compose.yml`:

```yaml
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=n8n.msp.rhaps.net
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://n8n.msp.rhaps.net
      - NODE_ENV=production
      - N8N_SECURE_COOKIE=true
      # Custom nodes path (automatically detected)
      - N8N_CUSTOM_EXTENSIONS=/home/node/.n8n/custom
    volumes:
      - ./data:/home/node/.n8n
    dns:
      - 8.8.8.8
      - 1.1.1.1
    networks:
      - n8n-network
      - chatwoot_default  # Connect to Chatwoot network

networks:
  n8n-network:
    driver: bridge
  chatwoot_default:
    external: true  # Use existing Chatwoot network
```

**Important Settings**:
- `N8N_HOST`: Your n8n domain (for webhooks)
- `WEBHOOK_URL`: Full webhook URL (with https)
- `N8N_SECURE_COOKIE=true`: Required for HTTPS
- `volumes`: Mounts `./data` so custom nodes persist
- `networks`: Connects to both n8n network and Chatwoot network
- `dns`: Public DNS for external API access

---

## Step 3: Create .env File (Optional)

Create `/opt/n8n/.env` for sensitive variables:

```bash
# Encryption key (generate with: openssl rand -base64 32)
N8N_ENCRYPTION_KEY=your-encryption-key-here

# Basic auth (optional, recommended for production)
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=your-secure-password

# Timezone
GENERIC_TIMEZONE=America/Los_Angeles

# Execution mode
EXECUTIONS_MODE=regular
```

**Security Best Practices**:
- Always set `N8N_ENCRYPTION_KEY` in production
- Use `N8N_BASIC_AUTH` or configure OAuth
- Keep `.env` file secure (don't commit to git)

---

## Step 4: Connect n8n to Chatwoot Network

The key to making n8n and Chatwoot communicate is sharing a Docker network.

**Verify Chatwoot network exists**:
```bash
docker network ls | grep chatwoot
# Should show: chatwoot_default
```

**If network doesn't exist, create it**:
```bash
docker network create chatwoot_default
```

**Then connect Chatwoot web container** (if not already connected):
```bash
cd /opt/chatwoot
docker compose -f docker-compose.production.yml down
# Edit docker-compose.production.yml to add network
docker compose -f docker-compose.production.yml up -d
```

---

## Step 5: Start n8n

```bash
cd /opt/n8n
docker compose up -d

# Check it's running
docker compose ps
docker compose logs -f

# Verify custom nodes directory
docker compose exec n8n ls -la /home/node/.n8n/custom/node_modules/
```

**Expected Output**:
```
NAME                COMMAND                  SERVICE             STATUS              PORTS
n8n                 "tini -- /docker-ent…"   n8n                 running             0.0.0.0:5678->5678/tcp
```

---

## Step 6: Configure Nginx Proxy Manager

Add SSL reverse proxy for n8n.

### Access Nginx Proxy Manager

- URL: `http://msp.rhaps.net:81`
- Default: `admin@example.com` / `changeme`

### Add Proxy Host for n8n

1. Click **Hosts → Proxy Hosts → Add Proxy Host**

2. **Details Tab**:
   - Domain Names: `n8n.msp.rhaps.net`
   - Scheme: `http`
   - Forward Hostname/IP: `n8n` (container name)
   - Forward Port: `5678`
   - ✅ Cache Assets
   - ✅ Block Common Exploits
   - ✅ Websockets Support (required for n8n)

3. **SSL Tab**:
   - SSL Certificate: Request a new SSL Certificate
   - ✅ Force SSL
   - ✅ HTTP/2 Support
   - Email: `your-email@example.com`
   - ✅ Agree to Let's Encrypt ToS

4. Click **Save**

### Verify Nginx Configuration

```bash
# Check proxy hosts
docker exec nginx-proxy-manager cat /data/nginx/proxy_host/*.conf | grep n8n

# Should show upstream to n8n:5678
```

---

## Step 7: Configure DNS

Add DNS A record for n8n subdomain:

- **Subdomain**: `n8n.msp.rhaps.net`
- **Type**: `A`
- **Value**: `82.64.228.224` (server IP)
- **TTL**: `300` (5 minutes)

**Verify DNS**:
```bash
nslookup n8n.msp.rhaps.net
dig n8n.msp.rhaps.net +short
```

---

## Step 8: Test n8n Access

### Via Browser

1. Open `https://n8n.msp.rhaps.net`
2. Should load n8n UI with valid SSL
3. Check browser console for errors (F12 → Console)

### From Chatwoot Container

Test n8n is accessible from Chatwoot:

```bash
# From Chatwoot web container
docker exec chatwoot-web curl -I http://n8n:5678
# Should return: HTTP/1.1 200 OK

# Test webhook endpoint
docker exec chatwoot-web curl -X POST http://n8n:5678/webhook/test \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

### From n8n Container

Test Chatwoot API is accessible from n8n:

```bash
# From n8n container
docker exec n8n curl -I http://chatwoot-web:3000/api/v1/accounts/1/conversations
# Should return: HTTP/1.1 401 Unauthorized (expected without token)
```

---

## Step 9: Deploy Custom AMB Nodes

### From Local Machine

```bash
# Build custom nodes locally (if not already built)
cd /Users/rhaps/LocalGit/chatwoot/n8n-nodes-chatwoot-amb
npm install
npm run build

# Install to local n8n for testing
cp -r . ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/

# Deploy to production (syncs to /opt/n8n/data/)
cd /Users/rhaps/LocalGit/chatwoot
./script/deploy-backend-changes-safe.sh
```

**The deployment script automatically**:
- Syncs custom nodes to `/opt/n8n/data/custom/node_modules/`
- Restarts n8n container
- Verifies deployment

### Verify Custom Nodes Loaded

```bash
# Check files on server
ssh root@msp.rhaps.net "ls -la /opt/n8n/data/custom/node_modules/n8n-nodes-chatwoot-amb/dist/nodes/"

# Check n8n logs for loading
ssh root@msp.rhaps.net "cd /opt/n8n && docker compose logs | grep -i 'custom\|community'"

# Check in n8n UI
# 1. Open https://n8n.msp.rhaps.net
# 2. Create workflow
# 3. Click "+ Add node"
# 4. Search "Chatwoot AMB"
# 5. Should see all 6 custom nodes
```

---

## Step 10: Configure Chatwoot Bot Webhook

Update bot to use n8n internal hostname.

### Create/Update Agent Bot

```bash
# Via Rails console
ssh root@msp.rhaps.net
docker exec -it chatwoot-web rails console

# Create bot
bot = AgentBot.create!(
  name: 'n8n Production Bot',
  description: 'Automated workflows via n8n',
  outgoing_url: 'http://n8n:5678/webhook/chatwoot'  # Internal hostname
)

# Copy the access token
puts bot.access_token

# Assign to inbox
inbox = Inbox.find_by(channel_type: 'Channel::AppleMessagesForBusiness')
inbox.agent_bot = bot
inbox.save!
```

**Important**: Use internal Docker hostname `n8n:5678`, not the public URL.

---

## Network Configuration Summary

### Internal Communication (Container-to-Container)

**Chatwoot → n8n**:
- URL: `http://n8n:5678/webhook/chatwoot`
- Network: `chatwoot_default` Docker bridge
- No SSL (internal traffic)

**n8n → Chatwoot**:
- URL: `http://chatwoot-web:3000/api/v1/...`
- Network: `chatwoot_default` Docker bridge
- No SSL (internal traffic)

### External Access (User/Browser)

**Users → Chatwoot**:
- URL: `https://msp.rhaps.net`
- Via: Nginx Proxy Manager (SSL termination)
- SSL: Let's Encrypt certificate

**Users → n8n**:
- URL: `https://n8n.msp.rhaps.net`
- Via: Nginx Proxy Manager (SSL termination)
- SSL: Let's Encrypt certificate

---

## Maintenance Commands

### View n8n Logs

```bash
ssh root@msp.rhaps.net "cd /opt/n8n && docker compose logs -f"
```

### Restart n8n

```bash
ssh root@msp.rhaps.net "cd /opt/n8n && docker compose restart"
```

### Update n8n Version

```bash
ssh root@msp.rhaps.net "cd /opt/n8n && docker compose pull && docker compose up -d"
```

### Backup n8n Data

```bash
ssh root@msp.rhaps.net "cd /opt/n8n && tar -czf n8n-backup-$(date +%Y%m%d).tar.gz data/"
```

### Check Custom Nodes

```bash
ssh root@msp.rhaps.net "docker exec n8n ls -la /home/node/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/"
```

### Redeploy Custom Nodes

```bash
# From local machine
./script/deploy-backend-changes-safe.sh
```

---

## Troubleshooting

### n8n Not Accessible via Browser

**Check n8n is running**:
```bash
docker ps | grep n8n
cd /opt/n8n && docker compose ps
```

**Check Nginx proxy**:
```bash
docker exec nginx-proxy-manager cat /data/nginx/proxy_host/*.conf | grep n8n
```

**Check DNS**:
```bash
nslookup n8n.msp.rhaps.net
```

### Chatwoot Can't Reach n8n

**Test network connectivity**:
```bash
docker exec chatwoot-web ping -c 3 n8n
docker exec chatwoot-web curl -I http://n8n:5678
```

**Verify both containers on same network**:
```bash
docker network inspect chatwoot_default | grep -E 'n8n|chatwoot-web'
```

**Reconnect if needed**:
```bash
docker network connect chatwoot_default n8n
```

### Custom Nodes Not Appearing

**Check files exist**:
```bash
docker exec n8n ls -la /home/node/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/dist/nodes/
```

**Restart n8n**:
```bash
cd /opt/n8n && docker compose restart
```

**Clear browser cache**: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows)

### Webhook Not Receiving Events

**Check bot configuration**:
```bash
docker exec -it chatwoot-web rails runner "puts AgentBot.last.inspect"
```

**Test webhook manually**:
```bash
curl -X POST https://n8n.msp.rhaps.net/webhook/chatwoot \
  -H "Content-Type: application/json" \
  -d '{"event": "message_created", "content": "test"}'
```

**Check n8n execution logs**: Go to https://n8n.msp.rhaps.net → Executions

---

## Security Considerations

### Production Checklist

- ✅ Use `N8N_ENCRYPTION_KEY` for data encryption
- ✅ Enable `N8N_BASIC_AUTH` or OAuth
- ✅ Use HTTPS for all external access
- ✅ Keep n8n updated (`docker compose pull`)
- ✅ Regular backups of `/opt/n8n/data/`
- ✅ Restrict firewall rules (only 80, 443, 22, 81)
- ✅ Use internal Docker hostnames for inter-container communication
- ✅ Keep credentials in `.env` file (not in docker-compose.yml)

### Network Security

- **Internal traffic**: Unencrypted HTTP over Docker bridge (secure, isolated network)
- **External traffic**: HTTPS with Let's Encrypt (SSL termination at Nginx)
- **Firewall**: Only expose ports 80 (HTTP), 443 (HTTPS), 22 (SSH), 81 (Nginx UI)

---

## Performance Optimization

### Resource Limits

Add to `docker-compose.yml`:

```yaml
services:
  n8n:
    # ... existing config ...
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 512M
```

### Database Performance

For high-volume workflows, use PostgreSQL instead of SQLite:

```yaml
services:
  n8n:
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n_user
      - DB_POSTGRESDB_PASSWORD=your_password
```

---

## References

- **n8n Documentation**: <https://docs.n8n.io>
- **Docker Networking**: <https://docs.docker.com/network/>
- **Nginx Proxy Manager**: <https://nginxproxymanager.com/>
- **Chatwoot Bot API**: `/docs/n8n/n8n-bot-integration-guide.md`
- **Deployment Guide**: `/docs/deployment/DEPLOYMENT_SUMMARY.md`

---

**Setup Complete!** 🎉

Your n8n instance is now running in production with:
- ✅ Separate Docker environment at `/opt/n8n/`
- ✅ SSL via Nginx Proxy Manager
- ✅ Network connectivity to Chatwoot
- ✅ Custom AMB nodes deployed
- ✅ Ready for bot workflow automation
