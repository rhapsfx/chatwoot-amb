# n8n Network Access & Icons Setup

## Current Status

### ✅ What's Working
- n8n container is running
- Custom nodes are loaded
- Workflows are activated

### ⚠️ Issues to Fix
1. **Icons not displaying** - Nodes show default icon instead of custom AMB icon
2. **Network access** - Container needs to reach Chatwoot API

---

## Fix 1: Network Access to Chatwoot

### Problem
n8n container needs to call Chatwoot Bot API, which is available at:
- **Tailscale URL**: `https://liquid-m3-pro.tail367da4.ts.net`
- **Local (blocked)**: `http://192.168.64.1:3000` (connection refused - not listening on all interfaces)

### Solution Options

#### Option A: Use Tailscale URL (Recommended)
The container can access your Tailscale hostname directly:

```javascript
// In n8n node configuration
Chatwoot URL: https://liquid-m3-pro.tail367da4.ts.net
Bot API Token: [your token from Chatwoot settings]
```

**Advantages**:
- Works immediately (no container changes needed)
- Uses HTTPS (secure)
- Works from anywhere on your Tailscale network

**Test from container**:
```bash
container exec n8n wget -q -O - https://liquid-m3-pro.tail367da4.ts.net 2>&1 | head -1
```

#### Option B: Use host.containers.internal
Apple Container provides a special hostname that always points to the host:

```javascript
// In n8n node configuration
Chatwoot URL: http://host.containers.internal:3000
```

**Note**: This requires Chatwoot to be listening on `0.0.0.0:3000` (all interfaces), not just `localhost:3000`.

To verify Chatwoot is listening on all interfaces:
```bash
lsof -iTCP:3000 -sTCP:LISTEN -P
# Should show: *:3000 (LISTEN) not 127.0.0.1:3000
```

If Chatwoot only listens on localhost, you need to update the dev-server configuration.

---

## Fix 2: Custom Node Icons

### Problem
Icons are present in the package but not displaying in n8n UI.

### Why This Happens
n8n caches node metadata and icons. After copying the custom nodes, n8n needs to:
1. Re-scan the custom nodes directory
2. Reload icon files
3. Clear the node cache

### Solution: Force n8n to Reload Icons

**Method 1: Container Restart** (Simple)
```bash
# Stop and remove container
container stop n8n && container rm n8n

# Start fresh (icons will be loaded)
container run \
  --name n8n \
  --detach \
  --publish 5678:5678 \
  --volume ~/.n8n:/home/node/.n8n \
  --env N8N_HOST=0.0.0.0 \
  --env N8N_PORT=5678 \
  --env N8N_PROTOCOL=http \
  --env N8N_SECURE_COOKIE=false \
  --env WEBHOOK_URL=http://localhost:5678/ \
  --env GENERIC_TIMEZONE=Europe/Paris \
  docker.io/n8nio/n8n:latest

# Wait for startup
sleep 10

# Check logs
container logs n8n | tail -20
```

**Method 2: Clear Browser Cache** (If icons still don't show)
The n8n web UI caches icons in your browser. Try:
1. Open n8n: http://localhost:5678
2. Open DevTools (F12)
3. Right-click refresh button → "Empty Cache and Hard Reload"
4. Or use Incognito/Private mode

**Method 3: Verify Icon Files**
```bash
# Check icons are in the package
ls -la ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/dist/icons/
# Should show: amb.svg, chatwoot.svg

# Check inside container
container exec n8n ls -la /home/node/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/dist/icons/
# Should show the same files
```

---

## Complete Setup Script

Here's a script to fix both issues:

```bash
#!/bin/bash
# Fix n8n network access and icons

echo "🔧 Fixing n8n setup..."

# 1. Stop n8n
echo "📦 Stopping n8n container..."
container stop n8n
container rm n8n

# 2. Verify custom nodes have icons
echo "🎨 Verifying icon files..."
if [ -f ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/dist/icons/amb.svg ]; then
    echo "✅ Icons found"
else
    echo "❌ Icons missing - rebuilding package..."
    cd ~/LocalGit/chatwoot/n8n-nodes-chatwoot-amb
    npm run build

    # Re-copy to custom directory
    rm -rf ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb
    cp -r ~/LocalGit/chatwoot/n8n-nodes-chatwoot-amb ~/.n8n/custom/node_modules/
fi

# 3. Start n8n with proper configuration
echo "🚀 Starting n8n..."
container run \
  --name n8n \
  --detach \
  --publish 5678:5678 \
  --volume ~/.n8n:/home/node/.n8n \
  --env N8N_HOST=0.0.0.0 \
  --env N8N_PORT=5678 \
  --env N8N_PROTOCOL=http \
  --env N8N_SECURE_COOKIE=false \
  --env WEBHOOK_URL=http://localhost:5678/ \
  --env GENERIC_TIMEZONE=Europe/Paris \
  docker.io/n8nio/n8n:latest

# 4. Wait for startup
echo "⏳ Waiting for n8n to start..."
sleep 10

# 5. Verify
echo ""
echo "🔍 Verification:"
echo "================"

# Check container
if container list | grep -q "n8n.*running"; then
    echo "✅ Container: Running"
else
    echo "❌ Container: Not running"
fi

# Check web UI
if curl -s -o /dev/null -w "%{http_code}" http://localhost:5678 | grep -q "200"; then
    echo "✅ Web UI: Accessible (http://localhost:5678)"
else
    echo "❌ Web UI: Not accessible"
fi

# Check workflow
if container logs n8n 2>&1 | grep -q "Activated workflow"; then
    echo "✅ Workflows: Activated"
else
    echo "⚠️  Workflows: Check logs for errors"
fi

# Check Tailscale access
echo ""
echo "🌐 Testing Chatwoot access..."
if container exec n8n wget -q -O /dev/null https://liquid-m3-pro.tail367da4.ts.net 2>&1; then
    echo "✅ Tailscale: Can reach Chatwoot"
else
    echo "⚠️  Tailscale: Cannot reach Chatwoot (check if Chatwoot is running)"
fi

echo ""
echo "✨ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Open n8n: http://localhost:5678"
echo "2. Clear browser cache (Ctrl+Shift+R or Cmd+Shift+R)"
echo "3. Check that custom nodes show AMB icon"
echo "4. Configure Chatwoot URL in nodes:"
echo "   - Use: https://liquid-m3-pro.tail367da4.ts.net"
echo "   - Add your Bot API token from Chatwoot settings"
echo ""
```

Save this as `~/LocalGit/chatwoot/docs/n8n/fix-n8n-setup.sh` and run:

```bash
chmod +x ~/LocalGit/chatwoot/docs/n8n/fix-n8n-setup.sh
~/LocalGit/chatwoot/docs/n8n/fix-n8n-setup.sh
```

---

## Configuring Chatwoot Bot API in n8n

Once n8n is running with icons loaded:

### 1. Get Your Bot API Token

In Chatwoot:
1. Go to **Settings** → **Applications**
2. Find or create a **Bot** integration
3. Copy the **API Access Token**

### 2. Configure Credentials in n8n

1. Open n8n: http://localhost:5678
2. Click **Credentials** (left sidebar)
3. Click **Add Credential**
4. Select **Chatwoot Bot API**
5. Fill in:
   - **Chatwoot URL**: `https://liquid-m3-pro.tail367da4.ts.net`
   - **Bot Token**: [paste your token]
6. Click **Save**

### 3. Test the Connection

Create a test workflow:
1. Add a **Manual Trigger** node
2. Add a **Chatwoot AMB List Picker** node
3. Connect to your credentials
4. Fill in required fields:
   - Conversation ID (use an existing conversation)
   - List picker data
5. Click **Execute Node**

If successful, the message will be sent to the conversation!

---

## Troubleshooting

### Icons Still Not Showing

**Try these steps in order**:

1. **Hard refresh browser**:
   - Chrome/Firefox: `Ctrl+Shift+R` (Windows) or `Cmd+Shift+R` (Mac)
   - Or open in Incognito/Private mode

2. **Check icon files exist**:
   ```bash
   container exec n8n ls -la /home/node/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/dist/icons/
   ```

3. **Check node definition**:
   ```bash
   container exec n8n grep "icon:" /home/node/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/dist/nodes/*/*.node.js
   # Should show: icon: 'file:amb.svg'
   ```

4. **Check browser console**:
   - Open DevTools (F12)
   - Look for 404 errors loading icon files
   - If you see 404s, n8n can't find the icons

5. **Last resort - rebuild package**:
   ```bash
   cd ~/LocalGit/chatwoot/n8n-nodes-chatwoot-amb
   npm run build

   # Copy fresh build
   container stop n8n && container rm n8n
   rm -rf ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb
   cp -r ~/LocalGit/chatwoot/n8n-nodes-chatwoot-amb ~/.n8n/custom/node_modules/

   # Start n8n (use command from above)
   ```

### Cannot Reach Chatwoot API

**Symptom**: n8n nodes show "Connection refused" or "Cannot connect"

**Solutions**:

1. **Verify Chatwoot is running**:
   ```bash
   curl -I https://liquid-m3-pro.tail367da4.ts.net
   # Should return: HTTP/2 200
   ```

2. **Test from container**:
   ```bash
   container exec n8n wget -q -O - https://liquid-m3-pro.tail367da4.ts.net 2>&1 | head -5
   # Should show HTML content
   ```

3. **Check Tailscale status**:
   ```bash
   tailscale status
   # Should show: liquid-m3-pro ... active
   ```

4. **Alternative: Use direct IP** (if Tailscale fails):
   - Find your Mac's IP: `ifconfig | grep "inet " | grep -v 127.0.0.1`
   - Ensure Chatwoot listens on `0.0.0.0:3000` (not just localhost)
   - Use `http://YOUR_MAC_IP:3000` in n8n configuration

---

## Quick Reference

### Container Commands

```bash
# Start n8n
container run --name n8n --detach --publish 5678:5678 \
  --volume ~/.n8n:/home/node/.n8n \
  --env N8N_HOST=0.0.0.0 --env N8N_PORT=5678 \
  --env N8N_PROTOCOL=http --env N8N_SECURE_COOKIE=false \
  --env WEBHOOK_URL=http://localhost:5678/ \
  --env GENERIC_TIMEZONE=Europe/Paris \
  docker.io/n8nio/n8n:latest

# Stop n8n
container stop n8n

# View logs
container logs n8n

# Follow logs
container logs -f n8n

# Execute command in container
container exec n8n [command]
```

### Important URLs

- **n8n Web UI**: http://localhost:5678
- **Chatwoot (Tailscale)**: https://liquid-m3-pro.tail367da4.ts.net
- **Chatwoot Bot API**: https://liquid-m3-pro.tail367da4.ts.net/api/v1/accounts/{account_id}/bots

### File Locations

- **Custom nodes**: `~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/`
- **Icons**: `~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/dist/icons/`
- **n8n data**: `~/.n8n/` (database, config, logs)
- **Source package**: `~/LocalGit/chatwoot/n8n-nodes-chatwoot-amb/`

---

## Summary

**To fix both issues**:

1. **Network Access**: Use Tailscale URL (`https://liquid-m3-pro.tail367da4.ts.net`) in n8n node configuration ✅
2. **Icons**: Restart container fresh + hard refresh browser ✅

**After setup**:
- Icons should display properly (AMB logo on custom nodes)
- n8n can call Chatwoot Bot API via Tailscale
- All custom nodes are functional and ready to use

**If issues persist**: Run the `fix-n8n-setup.sh` script above for automated troubleshooting!
