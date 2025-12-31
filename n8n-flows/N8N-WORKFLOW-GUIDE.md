# n8n Workflow Import & Connection Debugging Guide

## Critical Discovery: UUID vs Name-Based Connections

### The Root Cause

**Problem**: When workflows are imported via n8n API with UUID-based connections, the data is stored correctly in the database but the execution engine doesn't recognize the connections.

**Solution**: n8n requires **name-based connections** for proper execution.

### Connection Format Comparison

#### ❌ UUID-Based Connections (BROKEN)
```json
{
  "connections": {
    "0c09df62-6c60-4ab3-91e5-32c47c2b8a73": {
      "main": [[{
        "node": "b5edbc6e-6ee1-4712-a2eb-24f2fec0f53d",
        "type": "main",
        "index": 0
      }]]
    }
  }
}
```

**Symptoms**:
- ✅ Nodes stored correctly in database
- ✅ Connections stored correctly in database
- ✅ API verification passes (shows 113 connections)
- ❌ UI shows nodes as disconnected
- ❌ Workflow execution stops at first node
- ❌ Runtime engine doesn't follow connections

#### ✅ Name-Based Connections (WORKING)
```json
{
  "connections": {
    "Webhook": {
      "main": [[{
        "node": "Router with State",
        "type": "main",
        "index": 0
      }]]
    }
  }
}
```

**Result**: Everything works correctly.

---

## n8n Workflow JSON Structure

### Top-Level Structure
```json
{
  "name": "Workflow Name",
  "nodes": [],
  "connections": {},
  "settings": {},
  "staticData": null,
  "active": false,     // READ-ONLY via API
  "tags": []           // READ-ONLY via API
}
```

### Node Structure
```json
{
  "id": "unique-uuid-v4",           // UUID format required
  "name": "Node Name",              // Must be unique in workflow
  "type": "n8n-nodes-base.webhook", // Node type identifier
  "typeVersion": 2.1,               // Node version
  "position": [x, y],               // Canvas position [number, number]
  "parameters": {},                 // Node-specific configuration
  "credentials": {}                 // Optional credentials
}
```

### Connection Structure (Name-Based)
```json
{
  "connections": {
    "Source Node Name": {
      "main": [                    // Output type ("main" most common)
        [                          // Output index 0
          {
            "node": "Target Node Name",
            "type": "main",        // Input type
            "index": 0             // Input index
          }
        ]
      ]
    }
  }
}
```

### Connection Types

**Output Types** (most common):
- `main` - Standard data output
- `error` - Error handling output (from If nodes with error handling)

**Structure Breakdown**:
- **First level** (`connections` object): Source node name as key
- **Second level** (output type): Usually `"main"`
- **Third level** (array): Output port index (0, 1, 2...)
- **Fourth level** (array): List of target connections
- **Connection object**: Specifies target node, type, and index

**Example - Multiple Outputs** (If node):
```json
{
  "Is Welcome?": {
    "main": [
      [{"node": "Welcome Message 1", "type": "main", "index": 0}],  // True branch
      [{"node": "Is Menu?", "type": "main", "index": 0}]            // False branch
    ]
  }
}
```

**Example - Multiple Targets** (Router):
```json
{
  "Router with State": {
    "main": [
      [
        {"node": "Is Region Response?", "type": "main", "index": 0},
        {"node": "Should Process?", "type": "main", "index": 0}
      ]
    ]
  }
}
```

---

## Scripts & Tools

### 1. `fix-workflow-ids.js`
**Purpose**: Generate proper UUIDs for all nodes (initial attempt - creates UUID-based connections)

**⚠️ Note**: This script creates UUID-based connections which don't work properly. Use `convert-to-name-based.js` after running this.

**Usage**:
```bash
node fix-workflow-ids.js
```

**What it does**:
- Generates UUID v4 for all nodes
- Updates connections to use new UUIDs
- Creates mapping of old ID → new UUID

---

### 2. `convert-to-name-based.js` ⭐
**Purpose**: Convert UUID-based connections to name-based connections

**Usage**:
```bash
node convert-to-name-based.js
```

**Input**: `Acoustic-House-Bot-FINAL-v2-FIXED.json` (UUID-based)
**Output**: `Acoustic-House-Bot-FINAL-v2-NAME-BASED.json` (name-based)

**What it does**:
- Builds ID → Name mapping from nodes array
- Converts connection keys from node IDs to node names
- Converts connection targets from node IDs to node names
- Validates 100% conversion success

**Critical for**: Proper workflow execution in n8n

---

### 3. `import-via-api.js`
**Purpose**: Import workflow via n8n REST API with automatic verification

**Setup**:
```bash
export N8N_API_KEY="your-api-key-here"
export N8N_BASE_URL="http://localhost:5678"  # Optional, defaults to localhost
```

**Usage**:
```bash
node import-via-api.js
```

**What it does**:
- Creates workflow via POST `/api/v1/workflows`
- Fetches workflow back via GET to verify
- Counts and compares node counts
- Counts and compares connection counts
- Reports success or failure with detailed diagnostics

**Features**:
- Automatic connection verification
- Node count validation
- Connection count validation
- Detailed error reporting

---

### 4. `diagnose-workflow.js`
**Purpose**: Deep analysis of workflow structure and connections

**Usage**:
```bash
node diagnose-workflow.js <workflow-id>
```

**What it analyzes**:
- Node count and structure
- Connection sources and targets
- Node ID → Name mapping
- Connection validity (checks if referenced nodes exist)
- ID format validation (UUID detection)
- Connection matching percentage

**Output**:
- Overview of workflow
- Sample nodes (first 10)
- Connection analysis with invalid node detection
- First 10 connections with node names
- Node ID format analysis
- ID matching statistics

---

### 5. `compare-workflows.js`
**Purpose**: Compare source JSON with stored workflow in n8n

**Usage**:
```bash
node compare-workflows.js <workflow-id>
```

**What it compares**:
- Connection structure (deep analysis)
- Connection sources (ID vs name based)
- Byte-for-byte comparison
- Identifies missing connections
- Shows structural differences

**Use case**: Verify if n8n actually stored what you sent via API

---

### 6. `force-reindex.js`
**Purpose**: Force n8n to rebuild internal execution indexes

**Usage**:
```bash
node force-reindex.js <workflow-id>
```

**What it does**:
- Fetches workflow via GET
- Updates workflow via PUT (triggers reindexing)
- Verifies connections are preserved

**⚠️ Note**: This was an attempted fix before discovering the UUID vs name-based issue. May not be necessary with name-based connections.

---

### 7. `check-positions.js`
**Purpose**: Verify nodes have valid position data for UI rendering

**Usage**:
```bash
node check-positions.js <workflow-id>
```

**What it checks**:
- Nodes with/without position data
- Nodes at origin (0, 0)
- Position boundaries (min/max X/Y)
- UI rendering diagnostics

---

## Workflow Import Best Practices

### Via API (Recommended for Programmatic Import)

**1. Prepare Workflow JSON**:
```bash
# If starting from UUID-based connections:
node fix-workflow-ids.js          # Generate proper UUIDs
node convert-to-name-based.js     # Convert to name-based connections
```

**2. Set API Key**:
```bash
export N8N_API_KEY="your-api-key-here"
```

**3. Import**:
```bash
node import-via-api.js
```

**4. Verify**:
- Script automatically verifies connections
- Check n8n UI to confirm visual connections
- Test workflow execution

### Via UI (Recommended for Manual Import)

**1. Prepare Workflow JSON**:
```bash
node convert-to-name-based.js  # Ensure name-based connections
```

**2. Import in n8n**:
- Navigate to n8n UI
- Click "File" → "Import from File"
- Select `*-NAME-BASED.json` file
- Verify connections appear in UI
- Activate and test

---

## API Limitations & Workarounds

### Read-Only Fields

These fields **cannot be set** via POST `/api/v1/workflows`:

- `active` - Workflow activation status
- `tags` - Workflow tags
- `id` - Generated by n8n
- `createdAt`, `updatedAt` - Timestamps

**Workaround**: Activate workflow via PUT after creation

### Connection Format Requirement

**API requires name-based connections**, not UUID-based.

**Detection**:
```bash
# Check if connections are UUID-based (BAD)
cat workflow.json | jq -r '.connections | keys | .[0]'
# Output: "0c09df62-6c60-4ab3-91e5-32c47c2b8a73"  ❌

# Check if connections are name-based (GOOD)
cat workflow.json | jq -r '.connections | keys | .[0]'
# Output: "Webhook"  ✅
```

**Fix**:
```bash
node convert-to-name-based.js
```

---

## Debugging Checklist

### Problem: Nodes appear disconnected in UI

1. **Check connection format**:
   ```bash
   cat workflow.json | jq -r '.connections | keys | .[0]'
   ```
   - UUID format? → Convert to name-based
   - Name format? → Proceed to step 2

2. **Verify connections exist in database**:
   ```bash
   node diagnose-workflow.js <workflow-id>
   ```
   - Check "ID matching" percentage
   - Should be 100%

3. **Check node positions**:
   ```bash
   node check-positions.js <workflow-id>
   ```
   - All nodes should have position data

4. **Force reindex** (if needed):
   ```bash
   node force-reindex.js <workflow-id>
   ```

### Problem: Workflow execution stops at first node

**Root Cause**: UUID-based connections in execution engine

**Solution**:
1. Delete broken workflow
2. Convert to name-based connections:
   ```bash
   node convert-to-name-based.js
   ```
3. Re-import via API or UI
4. Verify execution follows connections

---

## Key Learnings

### 1. n8n Import Mechanism

- **UI Import**: Accepts both UUID and name-based, converts internally
- **API Import**: Expects name-based connections for proper execution
- **Database Storage**: Stores exactly what you send (doesn't normalize)
- **Execution Engine**: Requires name-based connections to route data

### 2. UUID Generation

- Use `crypto.randomUUID()` for UUID v4 format
- Format: `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`
- Must be unique within workflow
- Length: 36 characters (32 hex + 4 hyphens)

### 3. Connection Validation

**Three layers of validation**:
1. **API Response**: Returns connections in response (can be misleading)
2. **Database Storage**: Stores connections correctly
3. **Execution Engine**: Only works with name-based connections

**All three must work** for proper workflow execution.

### 4. Debugging Strategy

When workflow connections are broken:

1. **Verify data exists**: Check API response and database
2. **Verify format**: UUID vs name-based connections
3. **Verify execution**: Test workflow execution
4. **Convert if needed**: Use `convert-to-name-based.js`

---

## Tools Reference

### Quick Command Reference

```bash
# Convert UUID-based → Name-based
node convert-to-name-based.js

# Import workflow via API
export N8N_API_KEY="key"
node import-via-api.js

# Diagnose workflow issues
node diagnose-workflow.js <workflow-id>

# Compare source vs stored
node compare-workflows.js <workflow-id>

# Check positions
node check-positions.js <workflow-id>

# Force reindex
node force-reindex.js <workflow-id>
```

### n8n API Endpoints

```bash
# Create workflow
POST /api/v1/workflows
Headers: X-N8N-API-KEY: <key>
Body: {name, nodes, connections, settings}

# Get workflow
GET /api/v1/workflows/<id>
Headers: X-N8N-API-KEY: <key>

# Update workflow
PUT /api/v1/workflows/<id>
Headers: X-N8N-API-KEY: <key>
Body: {name, nodes, connections}

# List workflows
GET /api/v1/workflows
Headers: X-N8N-API-KEY: <key>

# Health check
GET /healthz
```

---

## Success Criteria

✅ **Workflow imported successfully** when:
1. All nodes appear in canvas
2. All connections visible in UI
3. Node count matches expected
4. Connection count matches expected
5. Workflow executes and follows connections
6. Data flows through all connected nodes

---

## Container Management (macOS)

### Update n8n to Latest Version

```bash
# Stop current container
container stop n8n

# Remove old container
container rm n8n

# Pull latest image
container image pull docker.io/n8nio/n8n:latest

# Start new container with settings
container run -d \
  --name n8n \
  -p 5678:5678 \
  -e N8N_SECURE_COOKIE=false \
  -v ~/.n8n:/home/node/.n8n \
  docker.io/n8nio/n8n:latest

# Verify running
container list

# Check health
curl http://localhost:5678/healthz
```

### Container Commands

```bash
# List containers
container list

# Stop container
container stop n8n

# Remove container
container rm n8n

# View logs
container logs n8n

# Inspect container
container inspect n8n
```

---

## Project Integration

### Location
All scripts are in: `/Users/rhaps/LocalGit/chatwoot/n8n-flows/`

### Workflow Files
- `Acoustic-House-Bot-FINAL-v2.json` - Original export
- `Acoustic-House-Bot-FINAL-v2-FIXED.json` - UUID-based (broken)
- `Acoustic-House-Bot-FINAL-v2-NAME-BASED.json` - Name-based (working) ✅

### Environment Variables
```bash
export N8N_API_KEY="your-api-key-here"
export N8N_BASE_URL="http://localhost:5678"
```

Get API key from: n8n UI → Settings → API → Create new API key

---

## Summary

**Critical Discovery**: n8n requires **name-based connections** (using node names as keys) rather than UUID-based connections (using node IDs as keys) for proper workflow execution.

**Solution**: Use `convert-to-name-based.js` to convert any UUID-based workflow JSON before importing.

**Scripts**: Complete toolkit for importing, verifying, diagnosing, and fixing n8n workflows.

**Result**: 149 nodes, 113 connections, all working correctly! 🎸
