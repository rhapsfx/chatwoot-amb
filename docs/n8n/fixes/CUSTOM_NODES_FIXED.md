# n8n Custom Nodes - Issue Resolution

## ✅ Problem Solved

The n8n custom nodes (Chatwoot AMB) are now working correctly after fixing the symlink issue.

---

## Root Cause

**The Problem**: Custom nodes were installed via symlink, but the symlink pointed to a macOS path that **doesn't exist inside the container**.

```bash
# Inside container, this symlink was broken:
~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb -> ../../../LocalGit/chatwoot/n8n-nodes-chatwoot-amb
#                                                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#                                                      This path doesn't exist inside the container!
```

**Why it happened**:
- The n8n container only has access to the mounted volume (`~/.n8n`)
- Symlinks pointing outside the mounted volume appear broken inside the container
- n8n couldn't load the custom nodes because the files were inaccessible

---

## Solution

**Replaced symlink with actual copy** of the compiled package:

```bash
# Before (broken symlink)
~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb -> ../../../LocalGit/chatwoot/...

# After (actual files)
~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/
├── package.json
├── dist/
│   ├── nodes/
│   │   ├── ChatwootAMBListPicker/
│   │   ├── ChatwootAMBTimePicker/
│   │   ├── ChatwootAMBQuickReply/
│   │   ├── ChatwootAMBForm/
│   │   ├── ChatwootAMBApplePay/
│   │   ├── ChatwootAMBRichLink/
│   │   └── ChatwootAMBTemplateMessage/
│   └── credentials/
└── node_modules/
```

---

## Steps Taken

1. **Stopped n8n container**:
   ```bash
   container stop n8n
   ```

2. **Removed broken symlink**:
   ```bash
   rm -rf ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb
   ```

3. **Copied actual package**:
   ```bash
   cp -r ~/LocalGit/chatwoot/n8n-nodes-chatwoot-amb ~/.n8n/custom/node_modules/
   ```

4. **Started n8n**:
   ```bash
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
   ```

5. **Verified custom nodes loaded**:
   ```bash
   container logs n8n | grep "Activated workflow"
   # Output: Activated workflow "Acoustic House flow 0.91" (ID: tUS32chOsTi9vXfr)
   ```

---

## Current Status

### ✅ All Systems Working

- **n8n Container**: Running (http://localhost:5678)
- **Web UI**: Accessible (no secure cookie error)
- **Custom Nodes**: All 7 nodes loaded successfully
- **Workflows**: Activated without errors
- **Your Data**: Fully preserved (database, flows, credentials)

### Custom Nodes Available

1. **ChatwootAMBListPicker** - List picker with images
2. **ChatwootAMBTimePicker** - Time/appointment picker
3. **ChatwootAMBQuickReply** - Quick reply buttons
4. **ChatwootAMBForm** - Multi-field forms
5. **ChatwootAMBApplePay** - Apple Pay requests
6. **ChatwootAMBRichLink** - Rich link previews
7. **ChatwootAMBTemplateMessage** - Template messages with attachments ⭐

---

## When to Update Custom Nodes

If you modify the custom node source code in `~/LocalGit/chatwoot/n8n-nodes-chatwoot-amb/`, you need to:

1. **Rebuild the package**:
   ```bash
   cd ~/LocalGit/chatwoot/n8n-nodes-chatwoot-amb
   npm run build
   ```

2. **Stop n8n**:
   ```bash
   container stop n8n && container rm n8n
   ```

3. **Update the copy**:
   ```bash
   rm -rf ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb
   cp -r ~/LocalGit/chatwoot/n8n-nodes-chatwoot-amb ~/.n8n/custom/node_modules/
   ```

4. **Restart n8n** (use the command above)

---

## Alternative: Development Setup

If you're actively developing custom nodes and need live reload, consider:

1. **Mount both directories**:
   ```bash
   container run \
     --name n8n \
     --detach \
     --publish 5678:5678 \
     --volume ~/.n8n:/home/node/.n8n \
     --volume ~/LocalGit/chatwoot/n8n-nodes-chatwoot-amb:/custom-nodes \
     --env N8N_CUSTOM_EXTENSIONS=/custom-nodes \
     ...
   ```

2. **Or use n8n's native development mode** (outside container):
   ```bash
   cd ~/LocalGit/chatwoot/n8n-nodes-chatwoot-amb
   npm link

   cd ~/.n8n/custom
   npm link n8n-nodes-chatwoot-amb

   # Run n8n natively
   n8n start
   ```

---

## Files Reference

### Custom Node Package
- **Source**: `/Users/rhaps/LocalGit/chatwoot/n8n-nodes-chatwoot-amb/`
- **Deployed**: `/Users/rhaps/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/`

### n8n Data
- **Database**: `/Users/rhaps/.n8n/database.sqlite` (43 MB - your flows)
- **Config**: `/Users/rhaps/.n8n/config` (encryption key)
- **Logs**: `/Users/rhaps/.n8n/n8nEventLog*.log`

### Container Command
```bash
# Quick restart command (copy-paste ready)
container stop n8n && container rm n8n && container run \
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
```

---

## Verification

### Check Container Status
```bash
container list | grep n8n
# Should show: n8n ... running
```

### Check Web UI
Open: http://localhost:5678
- Should load without secure cookie error
- Custom nodes visible in node panel

### Check Workflow Activation
```bash
container logs n8n | grep "Activated workflow"
# Should show: Activated workflow "Acoustic House flow 0.91"
```

### Check Custom Node Files
```bash
ls ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/dist/nodes/
# Should list all 7 node directories
```

---

## Summary

**Before**:
- ❌ Broken symlink
- ❌ Custom nodes not recognized
- ❌ Workflows failing with "Unrecognized node type"

**After**:
- ✅ Actual files copied
- ✅ Custom nodes loaded
- ✅ Workflows activated successfully
- ✅ n8n fully operational

**Your data**: **100% safe and preserved** throughout the fix! 🎉
