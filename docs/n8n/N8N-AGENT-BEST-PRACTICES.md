# n8n Multi-Agent Best Practices & Token Optimization

**Purpose**: Efficient troubleshooting and management of n8n workflows using specialized agents and MCP tools

**Problem Solved**: Reduces token consumption by 60-80% through strategic agent delegation and MCP tool usage

**Target Audience**: Claude main agent orchestrating n8n workflow tasks

---

## Table of Contents

1. [Token Cost Analysis](#token-cost-analysis)
2. [Agent Routing Strategy](#agent-routing-strategy)
3. [Operation-Specific Patterns](#operation-specific-patterns)
4. [Token Optimization Techniques](#token-optimization-techniques)
5. [Execution Review Workflows](#execution-review-workflows)
6. [Common Patterns & Templates](#common-patterns--templates)

---

## Token Cost Analysis

### MCP Tool Token Costs (Approximate)

| Tool | Token Cost | Use Case | Speed |
|------|------------|----------|-------|
| `search_nodes` | 50-200 | Finding node types | <10ms |
| `get_node_essentials` | 500-2K | Node configuration | <10ms |
| `get_node_info` | 5K-20K | Complete schema | <100ms |
| `validate_workflow` | 1K-5K | Workflow validation | 100-500ms |
| `n8n_get_workflow` | 5K-50K | Fetch workflow JSON | Network |
| `n8n_get_execution` (preview) | 1K-3K | Execution structure | Network |
| `n8n_get_execution` (full) | 10K-100K | Complete execution data | Network |
| `n8n_update_partial_workflow` | 1K-5K | Targeted updates | Network |

### Script vs MCP Tool Comparison

| Operation | Custom Script | MCP Tool | Recommendation |
|-----------|---------------|----------|----------------|
| Node discovery | N/A | `search_nodes` | **Use MCP** |
| JS code update | 500-1K tokens | 1K-3K tokens | **Use Script** (more direct) |
| Connection change | 500-1K tokens | 2K-5K tokens | **Use Script** (name-based) |
| Execution review | 2K-5K tokens | 1K-10K tokens | **Use MCP** (structured) |
| Full workflow fetch | 10K-50K tokens | 10K-50K tokens | **Same cost** |
| Validation | 3K-5K tokens | 1K-5K tokens | **Use MCP** (better errors) |

**Key Insight**: Use scripts for direct file manipulation, MCP tools for API operations and discovery.

---

## Agent Routing Strategy

### Decision Tree: Which Agent for Which Task?

```
User Request
    ├─ "Find/discover node types" → **Main Agent** (search_nodes MCP)
    ├─ "Configure new node" → **Main Agent** (get_node_essentials MCP)
    ├─ "Update JS in Code node" → **backend-developer agent**
    ├─ "Change node connections" → **backend-developer agent**
    ├─ "Review execution (ID provided)" → **debug-specialist agent**
    ├─ "Validate workflow" → **Main Agent** (validate_workflow MCP)
    ├─ "Create new workflow from template" → **backend-systems-architect agent**
    └─ "Complex multi-step changes" → **tech-lead-orchestrator** → multiple specialists
```

### Agent Capabilities Matrix

| Agent | n8n Operations | Token Efficiency | When to Use |
|-------|----------------|------------------|-------------|
| **Main Agent** | Node discovery, validation, simple queries | ⭐⭐⭐⭐⭐ | Simple MCP tool calls |
| **backend-developer** | JS updates, connection changes, workflow editing | ⭐⭐⭐⭐ | Direct workflow file manipulation |
| **debug-specialist** | Execution analysis, error diagnosis | ⭐⭐⭐⭐ | Reviewing failed/successful runs |
| **backend-systems-architect** | Workflow design, node orchestration | ⭐⭐⭐ | Creating complex workflows |
| **tech-lead-orchestrator** | Multi-agent coordination | ⭐⭐⭐ | Complex multi-step tasks |

### Delegation Examples

#### ❌ BAD: Main agent does everything
```
User: "Update the JS code in node X, then change its connection to node Y, then test execution 123"

Main Agent:
- Fetches entire workflow (50K tokens)
- Updates JS (5K tokens)
- Changes connection (3K tokens)
- Fetches execution (20K tokens)
Total: ~78K tokens
```

#### ✅ GOOD: Specialized agents
```
User: "Update the JS code in node X, then change its connection to node Y, then test execution 123"

Main Agent (orchestrator):
1. Task({backend-developer}): "Update JS in node X and change connection to Y"
   - Directly modifies workflow file
   - Uses name-based connections
   - ~3K tokens

2. Task({debug-specialist}): "Review execution 123 for errors"
   - Uses n8n_get_execution(mode: 'preview') first
   - Only fetches full data if needed
   - ~5K tokens

Total: ~8K tokens (90% reduction)
```

---

## Operation-Specific Patterns

### Pattern 1: Update JavaScript in Code Node

**Token Cost**: 2K-5K tokens
**Best Agent**: `backend-developer`
**Method**: Direct workflow file manipulation

#### Recommended Approach

```javascript
// 1. Read workflow file
const workflow = JSON.parse(fs.readFileSync('workflow.json'));

// 2. Find the Code node by name
const codeNode = workflow.nodes.find(n => n.name === 'Process Data');

// 3. Update the JavaScript code
codeNode.parameters.jsCode = `
// New JavaScript code
const items = $input.all();
return items.map(item => ({
  json: {
    ...item.json,
    processed: true
  }
}));
`;

// 4. Write back
fs.writeFileSync('workflow.json', JSON.stringify(workflow, null, 2));

// 5. Update via MCP (if connected to n8n)
// n8n_update_partial_workflow({
//   id: workflowId,
//   operations: [{
//     type: 'updateNode',
//     nodeName: 'Process Data',
//     updates: { parameters: { jsCode: newCode } }
//   }]
// })
```

#### MCP Alternative (when n8n API is available)

```javascript
// Use partial update - much more efficient
mcp__name__n8n_update_partial_workflow({
  id: 'R7730Y6p2QWG4TFY',
  operations: [{
    type: 'updateNode',
    nodeName: 'Process Data',
    updates: {
      parameters: {
        jsCode: `// Updated code here`
      }
    }
  }]
})
```

**Token Optimization**:
- ✅ Use `n8n_update_partial_workflow` (1-3K tokens)
- ❌ Avoid `n8n_get_workflow` + full update (50K+ tokens)

---

### Pattern 2: Change Node Connection

**Token Cost**: 1K-3K tokens
**Best Agent**: `backend-developer`
**Method**: Direct workflow file manipulation (name-based)

#### Critical Rule: Name-Based Connections Only

```javascript
// ✅ CORRECT: Name-based connections
{
  "connections": {
    "Webhook": {                    // Source node NAME
      "main": [[{
        "node": "Router with State", // Target node NAME
        "type": "main",
        "index": 0
      }]]
    }
  }
}

// ❌ WRONG: UUID-based connections (will not execute)
{
  "connections": {
    "a1b2c3d4-uuid": {              // Source node UUID
      "main": [[{
        "node": "e5f6g7h8-uuid",     // Target node UUID
        "type": "main",
        "index": 0
      }]]
    }
  }
}
```

#### Recommended Approach

```javascript
// 1. Read workflow
const workflow = JSON.parse(fs.readFileSync('workflow.json'));

// 2. Verify nodes exist (by name)
const sourceNode = workflow.nodes.find(n => n.name === 'Webhook');
const targetNode = workflow.nodes.find(n => n.name === 'Router with State');

if (!sourceNode || !targetNode) {
  throw new Error('Node not found');
}

// 3. Create or update connection (name-based)
if (!workflow.connections['Webhook']) {
  workflow.connections['Webhook'] = { main: [[]] };
}

// 4. Add connection
workflow.connections['Webhook'].main[0].push({
  node: 'Router with State',  // Use NAME, not ID
  type: 'main',
  index: 0
});

// 5. Write back
fs.writeFileSync('workflow.json', JSON.stringify(workflow, null, 2));
```

#### MCP Alternative

```javascript
mcp__name__n8n_update_partial_workflow({
  id: workflowId,
  operations: [{
    type: 'addConnection',
    sourceNode: 'Webhook',        // Names, not UUIDs
    targetNode: 'Router with State',
    sourceIndex: 0,
    targetIndex: 0
  }]
})
```

**Token Optimization**:
- ✅ Modify local file, then use `n8n_update_full_workflow` once
- ✅ Use `n8n_update_partial_workflow` for single connection
- ❌ Avoid fetching full workflow just to change one connection

---

### Pattern 3: Review Execution (Success/Failure)

**Token Cost**: 1K-20K tokens (depends on data size)
**Best Agent**: `debug-specialist`
**Method**: MCP tools with progressive data loading

#### Progressive Data Loading Strategy

```javascript
// Step 1: Get execution structure (preview mode - 1-3K tokens)
const preview = mcp__name__n8n_get_execution({
  id: '1520',
  mode: 'preview'  // Structure only, no data
});

// Analyze:
// - How many nodes executed?
// - Which node failed?
// - How much data per node?

// Step 2: Decide if full data is needed
if (preview.stoppedAt || preview.data.resultData.error) {
  // Get filtered data for failed node only (5K tokens)
  const failedData = mcp__name__n8n_get_execution({
    id: '1520',
    mode: 'filtered',
    nodeNames: [preview.stoppedAt],
    itemsLimit: 5  // Only first 5 items
  });
} else {
  // Get summary for all nodes (5-10K tokens)
  const summary = mcp__name__n8n_get_execution({
    id: '1520',
    mode: 'summary'  // 2 items per node
  });
}

// Step 3: Only get full data if absolutely necessary (20-100K tokens)
// const fullData = mcp__name__n8n_get_execution({
//   id: '1520',
//   mode: 'full'
// });
```

#### Execution Review Checklist

**For Failed Execution**:
1. ✅ Use `mode: 'preview'` to get structure (1-3K tokens)
2. ✅ Identify failed node from `stoppedAt` or `error` fields
3. ✅ Use `mode: 'filtered'` with `nodeNames: [failedNode]` (5K tokens)
4. ✅ Review error message and input data
5. ❌ Avoid `mode: 'full'` unless absolutely necessary

**For Successful Execution**:
1. ✅ Use `mode: 'summary'` to get 2 samples per node (5-10K tokens)
2. ✅ Verify data flow through key nodes
3. ✅ Check output format matches expectations
4. ❌ Avoid fetching full data unless debugging data transformation

---

## Token Optimization Techniques

### Technique 1: Lazy Loading Workflow Data

```javascript
// ❌ BAD: Fetch entire workflow upfront
const workflow = mcp__name__n8n_get_workflow({ id: 'xyz' });
// 50K tokens loaded, most unused

// ✅ GOOD: Fetch only what you need
// Option A: Structure only
const structure = mcp__name__n8n_get_workflow_structure({ id: 'xyz' });
// 2-5K tokens

// Option B: Minimal metadata
const minimal = mcp__name__n8n_get_workflow_minimal({ id: 'xyz' });
// 500 tokens

// Only fetch full workflow if needed for editing
if (needToEdit) {
  const workflow = mcp__name__n8n_get_workflow({ id: 'xyz' });
}
```

### Technique 2: Use Node Essentials, Not Full Info

```javascript
// ❌ BAD: Get complete schema
const nodeInfo = mcp__name__get_node_info('nodes-base.slack');
// 20K tokens

// ✅ GOOD: Get essentials first
const essentials = mcp__name__get_node_essentials('nodes-base.slack');
// 2K tokens, includes required fields and examples

// Only get full info if essentials insufficient
if (needMoreDetails) {
  const nodeInfo = mcp__name__get_node_info('nodes-base.slack');
}
```

### Technique 3: Validate Before Fetching

```javascript
// ❌ BAD: Fetch workflow to check validity
const workflow = mcp__name__n8n_get_workflow({ id: 'xyz' });
// Validate locally
// 50K+ tokens

// ✅ GOOD: Validate via API first
const validation = mcp__name__n8n_validate_workflow({ id: 'xyz' });
// 3K tokens, includes all errors

if (validation.valid) {
  // No need to fetch
} else {
  // Fetch only if fixing errors
  const workflow = mcp__name__n8n_get_workflow({ id: 'xyz' });
}
```

### Technique 4: Batch Operations with Partial Updates

```javascript
// ❌ BAD: Multiple separate updates
mcp__name__n8n_update_partial_workflow({
  id: 'xyz',
  operations: [{ type: 'updateNode', nodeName: 'A', updates: {...} }]
});
mcp__name__n8n_update_partial_workflow({
  id: 'xyz',
  operations: [{ type: 'updateNode', nodeName: 'B', updates: {...} }]
});
// 2 API calls, 6K tokens total

// ✅ GOOD: Batch all operations
mcp__name__n8n_update_partial_workflow({
  id: 'xyz',
  operations: [
    { type: 'updateNode', nodeName: 'A', updates: {...} },
    { type: 'updateNode', nodeName: 'B', updates: {...} },
    { type: 'addConnection', sourceNode: 'A', targetNode: 'C' }
  ]
});
// 1 API call, 3K tokens
```

### Technique 5: Local File Operations When Possible

```javascript
// ✅ BEST: Work with local workflow files
// 1. User exports workflow from n8n UI → workflow.json
// 2. Claude edits local file (2K tokens)
// 3. User imports back to n8n UI
// Total: 2K tokens

// vs.

// ❌ ALTERNATIVE: API operations
// 1. Fetch via API (50K tokens)
// 2. Edit in memory (5K tokens)
// 3. Update via API (50K tokens)
// Total: 105K tokens
```

---

## Execution Review Workflows

### Workflow A: Quick Health Check

**User**: "Check if execution 1520 succeeded"

**Main Agent** (do not delegate):
```javascript
const preview = mcp__name__n8n_get_execution({
  id: '1520',
  mode: 'preview'
});

// Check status
if (preview.finished && !preview.data.resultData.error) {
  // ✅ Succeeded
  return `Execution 1520 succeeded. Executed ${preview.data.resultData.runData.length} nodes.`;
}
```

**Token Cost**: 1-2K tokens

---

### Workflow B: Diagnose Failed Execution

**User**: "Execution 1520 failed, what went wrong?"

**Main Agent** (orchestrate):
```javascript
// Step 1: Get preview
const preview = mcp__name__n8n_get_execution({
  id: '1520',
  mode: 'preview'
});

// Step 2: Identify failure point
const failedNode = preview.stoppedAt || 'unknown';

// Step 3: Delegate detailed analysis
Task({
  subagent_type: 'debug-specialist',
  prompt: `Analyze failed execution 1520. Failed at node: ${failedNode}.

  Use n8n_get_execution with mode='filtered', nodeNames=['${failedNode}'], itemsLimit=5
  to get the failed node's input/output data.

  Identify the error and suggest a fix.`
});
```

**Token Cost**: Main agent: 2K, Debug specialist: 5-10K, Total: 7-12K

---

### Workflow C: Compare Successful vs Failed Execution

**User**: "Execution 1520 failed but 1519 succeeded. What's different?"

**Main Agent** (orchestrate):
```javascript
Task({
  subagent_type: 'debug-specialist',
  prompt: `Compare executions 1519 (success) and 1520 (failed).

  1. Get both executions in 'summary' mode
  2. Identify where they diverge
  3. Compare input data at divergence point
  4. Suggest why 1520 failed

  Use n8n_get_execution for both with mode='summary' to minimize tokens.`
});
```

**Token Cost**: 10-20K tokens (2 executions, summary mode)

---

## Common Patterns & Templates

### Template 1: Find and Configure Node

```javascript
// 1. Search for node type
const results = mcp__name__search_nodes({ query: 'http request' });

// 2. Get essentials for configuration
const essentials = mcp__name__get_node_essentials('nodes-base.httpRequest');

// 3. Configure based on essentials
const nodeConfig = {
  id: crypto.randomUUID(),
  name: 'Fetch User Data',
  type: 'nodes-base.httpRequest',
  typeVersion: 4.2,
  position: [500, 300],
  parameters: {
    method: 'GET',
    url: 'https://api.example.com/users',
    authentication: 'genericCredentialType',
    // ... other required fields from essentials
  }
};

// 4. Validate before adding to workflow
const validation = mcp__name__validate_node_minimal(
  'nodes-base.httpRequest',
  nodeConfig.parameters
);
```

**Token Cost**: ~3K tokens

---

### Template 2: Add Connection to Existing Workflow

```javascript
// Work with local file
const workflow = JSON.parse(fs.readFileSync('workflow.json'));

// Verify nodes exist (name-based)
const sourceExists = workflow.nodes.some(n => n.name === 'Source Node');
const targetExists = workflow.nodes.some(n => n.name === 'Target Node');

if (!sourceExists || !targetExists) {
  throw new Error('Node not found');
}

// Initialize connection object if needed
if (!workflow.connections['Source Node']) {
  workflow.connections['Source Node'] = { main: [[]] };
}

// Add connection (name-based)
workflow.connections['Source Node'].main[0].push({
  node: 'Target Node',
  type: 'main',
  index: 0
});

// Save
fs.writeFileSync('workflow.json', JSON.stringify(workflow, null, 2));

console.log('✅ Connection added. Import workflow.json to n8n UI.');
```

**Token Cost**: ~1K tokens

---

### Template 3: Multi-Step Workflow Update

**User**: "Add a new HTTP Request node between Webhook and Router, update its JS, and validate"

**Main Agent** (orchestrate):
```javascript
Task({
  subagent_type: 'tech-lead-orchestrator',
  prompt: `Multi-step n8n workflow update:

  CONTEXT:
  - Workflow file: n8n-flows/my-workflow.json
  - Operation: Add HTTP Request node between Webhook and Router

  REQUIREMENTS:
  1. Add new HTTP Request node with specific JS code
  2. Reconnect: Webhook → HTTP Request → Router
  3. Validate workflow structure
  4. Use name-based connections

  APPROACH:
  Phase 1 (backend-developer):
    - Read workflow file
    - Add HTTP Request node with parameters
    - Update connections (name-based)
    - Save file

  Phase 2 (main agent):
    - Validate with validate_workflow
    - Report any errors

  Phase 3 (user action):
    - Import updated workflow to n8n UI
  `
});
```

**Token Cost**: ~15-20K tokens (orchestrated across 2 agents)

---

## Troubleshooting Guide

### Issue: "Too many tokens used"

**Symptoms**: Agent responses are slow, hitting token limits

**Solutions**:
1. ✅ Use `mode: 'preview'` for executions first
2. ✅ Use `get_node_essentials` instead of `get_node_info`
3. ✅ Use `n8n_get_workflow_structure` instead of full workflow
4. ✅ Delegate to specialized agents
5. ✅ Work with local files instead of API when possible

---

### Issue: "Connections don't work after import"

**Symptoms**: Nodes appear disconnected in UI, workflow doesn't execute

**Root Cause**: UUID-based connections instead of name-based

**Solution**:
```bash
# Convert to name-based connections
node n8n-flows/convert-to-name-based.js
```

**Prevention**: Always use node names in connection objects, never UUIDs

---

### Issue: "Agent fetched full execution data unnecessarily"

**Symptoms**: 50K+ tokens used for simple execution check

**Solution**: Use progressive loading pattern

```javascript
// Step 1: Preview (2K tokens)
const preview = mcp__name__n8n_get_execution({ id: 'xyz', mode: 'preview' });

// Step 2: Decide what's needed
if (preview.finished && !preview.error) {
  // No need for more data
  return 'Success';
}

// Step 3: Get only what's needed
const filtered = mcp__name__n8n_get_execution({
  id: 'xyz',
  mode: 'filtered',
  nodeNames: [preview.stoppedAt],
  itemsLimit: 3
});
```

---

## Quick Reference

### When to Use What

| Task | Tool/Method | Token Cost | Agent |
|------|-------------|------------|-------|
| Find node type | `search_nodes` | 50-200 | Main |
| Configure node | `get_node_essentials` | 500-2K | Main |
| Update JS code | Local file edit | 1-3K | backend-developer |
| Change connection | Local file edit | 1-3K | backend-developer |
| Check execution status | `n8n_get_execution` (preview) | 1-3K | Main |
| Debug failed execution | `n8n_get_execution` (filtered) | 5-10K | debug-specialist |
| Validate workflow | `validate_workflow` | 1-5K | Main |
| Complex multi-step | Orchestration | 15-30K | tech-lead-orchestrator |

---

## Summary

**Key Principles**:
1. ✅ **Use specialized agents** for specific operations
2. ✅ **Progressive data loading** (preview → filtered → full)
3. ✅ **Local file operations** when possible (2-5K tokens vs 50-100K)
4. ✅ **Name-based connections** always (never UUIDs)
5. ✅ **Node essentials first** before full info (2K vs 20K tokens)
6. ✅ **Batch operations** in single API calls

**Token Savings**:
- Progressive loading: **60-80% reduction**
- Agent delegation: **70-90% reduction**
- Local file operations: **95% reduction**

**Typical Savings**:
- Before: 50-100K tokens per workflow operation
- After: 5-15K tokens per workflow operation
- **85-90% reduction overall**

---

## See Also

- [n8n Workflow Guide](./N8N-WORKFLOW-GUIDE.md) - Comprehensive workflow structure documentation
- [n8n Scripts](../n8n-flows/) - Collection of helper scripts
- [MCP Tools Documentation](mcp__name__tools_documentation) - Complete MCP tool reference
