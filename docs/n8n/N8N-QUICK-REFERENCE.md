# n8n Operations Quick Reference Card

**Purpose**: Fast decision-making guide for n8n operations

---

## 🚦 Quick Decision Matrix

### "Should I delegate this task?"

```
Operation Type                    | Complexity | Tokens  | Delegate? | Agent
----------------------------------|------------|---------|-----------|------------------------
Find node type                    | Simple     | 50-200  | ❌ No     | Main (search_nodes)
Configure single node             | Simple     | 500-2K  | ❌ No     | Main (get_node_essentials)
Update JS in Code node            | Medium     | 2-5K    | ✅ Yes    | backend-developer
Change 1-2 connections            | Medium     | 1-3K    | ✅ Yes    | backend-developer
Add new node + connections        | Medium     | 3-8K    | ✅ Yes    | backend-developer
Check execution status            | Simple     | 1-3K    | ❌ No     | Main (preview mode)
Debug failed execution            | Medium     | 5-15K   | ✅ Yes    | debug-specialist
Complex multi-step workflow edit  | Complex    | 15-30K  | ✅ Yes    | tech-lead-orchestrator
Create workflow from scratch      | Complex    | 20-40K  | ✅ Yes    | backend-systems-architect
```

---

## 📊 Token Cost Quick Comparison

### Execution Review

| Method | Token Cost | Use When |
|--------|------------|----------|
| `mode: 'preview'` | 1-3K | Just checking status |
| `mode: 'summary'` | 5-10K | Need to see data samples |
| `mode: 'filtered'` | 5-15K | Debugging specific node |
| `mode: 'full'` | 20-100K | Deep analysis needed (rare) |

### Workflow Operations

| Method | Token Cost | Use When |
|--------|------------|----------|
| Local file edit | 1-5K | Have workflow JSON file |
| `n8n_get_workflow_minimal` | 500 | Just need metadata |
| `n8n_get_workflow_structure` | 2-5K | Need node/connection list |
| `n8n_get_workflow` | 10-50K | Need complete workflow |
| `n8n_update_partial_workflow` | 1-5K | Small targeted change |
| `n8n_update_full_workflow` | 10-50K | Major overhaul |

### Node Configuration

| Method | Token Cost | Use When |
|--------|------------|----------|
| `get_node_essentials` | 500-2K | First time config |
| `get_node_info` | 5-20K | Need complete schema |
| `search_node_properties` | 200-1K | Looking for specific field |

---

## 🎯 Operation Patterns

### Pattern: Update JavaScript Code

```javascript
// ✅ EFFICIENT (1-3K tokens)
// 1. Local file
const workflow = require('./workflow.json');
const node = workflow.nodes.find(n => n.name === 'Process Data');
node.parameters.jsCode = `/* new code */`;
fs.writeFileSync('workflow.json', JSON.stringify(workflow, null, 2));

// ✅ API (if connected)
mcp__name__n8n_update_partial_workflow({
  id: workflowId,
  operations: [{
    type: 'updateNode',
    nodeName: 'Process Data',
    updates: { parameters: { jsCode: '/* new code */' } }
  }]
});

// ❌ INEFFICIENT (50K+ tokens)
// Fetching entire workflow just to update one field
```

---

### Pattern: Change Connection

```javascript
// ✅ CORRECT: Name-based
workflow.connections['Source Node'] = {
  main: [[{
    node: 'Target Node',  // ← NAME
    type: 'main',
    index: 0
  }]]
};

// ❌ WRONG: UUID-based (won't execute)
workflow.connections['uuid-1234'] = {
  main: [[{
    node: 'uuid-5678',  // ← UUID
    type: 'main',
    index: 0
  }]]
};
```

---

### Pattern: Review Execution

```javascript
// ✅ EFFICIENT: Progressive loading
// Step 1: Preview (1-3K)
const preview = mcp__name__n8n_get_execution({ id, mode: 'preview' });

// Step 2: Only if needed (5-10K)
if (preview.error) {
  const filtered = mcp__name__n8n_get_execution({
    id,
    mode: 'filtered',
    nodeNames: [preview.stoppedAt],
    itemsLimit: 5
  });
}

// ❌ INEFFICIENT: Full data upfront (50K+)
const full = mcp__name__n8n_get_execution({ id, mode: 'full' });
```

---

## 🔧 Troubleshooting Quick Fixes

### Issue: "Connections don't work"
```bash
# Convert to name-based
node n8n-flows/convert-to-name-based.js
```

### Issue: "Too many tokens"
```javascript
// Use essentials, not full info
mcp__name__get_node_essentials('nodes-base.slack')  // 2K
// NOT: mcp__name__get_node_info('nodes-base.slack')  // 20K
```

### Issue: "Execution review too expensive"
```javascript
// Use preview mode first
mode: 'preview'  // 1-3K tokens
// NOT: mode: 'full'  // 50K+ tokens
```

---

## 📋 Pre-Operation Checklist

### Before Fetching Workflow
- [ ] Do I need the full workflow or just structure?
- [ ] Can I work with a local file instead?
- [ ] Is there a more targeted operation (partial update)?

### Before Reviewing Execution
- [ ] Do I just need success/failure status? (preview mode)
- [ ] Do I need data from specific nodes? (filtered mode)
- [ ] Do I really need all data? (full mode - rarely needed)

### Before Configuring Node
- [ ] Have I called `get_node_essentials` first?
- [ ] Do I really need `get_node_info`? (usually not)

### Before Delegating to Agent
- [ ] Is this a simple operation I can do? (<3K tokens)
- [ ] Will delegation save tokens overall?
- [ ] Which agent is best suited?

---

## 🎭 Agent Selection Cheat Sheet

```
SIMPLE (Main Agent - No Delegation)
├─ search_nodes
├─ get_node_essentials
├─ validate_node_minimal
├─ n8n_get_execution (preview mode)
└─ validate_workflow

MEDIUM (Delegate to Specialist)
├─ backend-developer
│   ├─ Update JS code
│   ├─ Change connections
│   └─ Add/remove nodes
├─ debug-specialist
│   ├─ Review failed execution
│   ├─ Compare executions
│   └─ Diagnose errors
└─ backend-systems-architect
    ├─ Design workflow structure
    └─ Node orchestration

COMPLEX (Orchestrate Multiple Agents)
└─ tech-lead-orchestrator
    ├─ Multi-step workflow changes
    ├─ Create + test + validate
    └─ Complex troubleshooting
```

---

## 🎬 Common User Requests → Actions

| User Says | Quick Action | Tokens |
|-----------|--------------|--------|
| "Find a node that..." | `search_nodes` | 50-200 |
| "How do I configure X node?" | `get_node_essentials` | 500-2K |
| "Update the JS in node Y" | → backend-developer | 2-5K |
| "Connect A to B" | → backend-developer | 1-3K |
| "Did execution X succeed?" | `n8n_get_execution` (preview) | 1-3K |
| "Why did execution X fail?" | → debug-specialist | 5-15K |
| "Validate my workflow" | `validate_workflow` | 1-5K |
| "Create workflow for..." | → backend-systems-architect | 20-40K |

---

## 💡 Pro Tips

1. **Always start with preview mode** for executions
2. **Always use get_node_essentials** before get_node_info
3. **Always use name-based connections** (never UUIDs)
4. **Local files > API** when user has the JSON
5. **Delegate early** for operations >3K tokens
6. **Batch operations** in single API call when possible

---

## 🚨 Common Mistakes to Avoid

❌ Fetching full workflow to update one field
✅ Use `n8n_update_partial_workflow`

❌ Getting node info before essentials
✅ Get essentials first, info only if needed

❌ Using `mode: 'full'` for execution review
✅ Use `mode: 'preview'` first

❌ Not specifying mode in `n8n_get_execution`
✅ **ALWAYS** specify mode (defaults can cause "Input too long" error)

❌ Creating UUID-based connections
✅ Always use name-based connections

❌ Doing everything in main agent
✅ Delegate to specialists for >3K token operations

**🚨 Critical**: If you see "Input is too long for requested model" error, see [TROUBLESHOOTING-INPUT-TOO-LONG.md](TROUBLESHOOTING-INPUT-TOO-LONG.md)

---

## 📞 When to Ask for Help

**Ask user to:**
- Export workflow JSON from n8n UI (for local editing)
- Provide execution ID for review
- Confirm n8n API access is configured
- Run deployment scripts (SSH blocked in Claude)

**Use MCP tools when:**
- n8n API is configured and accessible
- Need to discover nodes or get docs
- Validating workflow structure
- Reviewing executions

**Use local scripts when:**
- User has workflow JSON file
- Making bulk changes
- Converting connection formats
- Testing locally before deploy

---

**Remember**: The goal is to minimize token usage while maintaining functionality. When in doubt, delegate to a specialist!
