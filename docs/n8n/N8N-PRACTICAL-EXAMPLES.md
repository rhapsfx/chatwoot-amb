# n8n Multi-Agent Patterns - Practical Examples

**Purpose**: Real-world examples demonstrating efficient n8n operations using multi-agent patterns

**Audience**: Claude agents working with n8n workflows

---

## Table of Contents

1. [Example 1: Simple JS Update](#example-1-simple-js-update)
2. [Example 2: Connection Restructure](#example-2-connection-restructure)
3. [Example 3: Failed Execution Diagnosis](#example-3-failed-execution-diagnosis)
4. [Example 4: Multi-Step Workflow Enhancement](#example-4-multi-step-workflow-enhancement)
5. [Example 5: Template-Based Workflow Creation](#example-5-template-based-workflow-creation)

---

## Example 1: Simple JS Update

### User Request
> "The 'Process Data' node in my workflow needs to filter out items where `status !== 'active'`. Update the JavaScript code."

### ❌ INEFFICIENT Approach (50K+ tokens)

```javascript
// Main agent does everything
const workflow = mcp__name__n8n_get_workflow({ id: 'R7730Y6p2QWG4TFY' });
// → Fetches entire workflow: 50K tokens

const node = workflow.nodes.find(n => n.name === 'Process Data');
node.parameters.jsCode = `
const items = $input.all();
return items.filter(item => item.json.status === 'active');
`;

mcp__name__n8n_update_full_workflow({
  id: 'R7730Y6p2QWG4TFY',
  nodes: workflow.nodes,
  connections: workflow.connections
});
// → Updates entire workflow: 50K tokens

// TOTAL: ~100K tokens
```

### ✅ EFFICIENT Approach (2-3K tokens)

```javascript
// Main agent delegates
Task({
  subagent_type: 'backend-developer',
  description: 'Update JavaScript in Code node',
  prompt: `Update the 'Process Data' Code node in workflow file n8n-flows/Acoustic-House-Bot.json

  REQUIREMENT:
  Filter items to only include those where status === 'active'

  APPROACH:
  1. Read workflow JSON file
  2. Find node with name: 'Process Data'
  3. Update parameters.jsCode with filter logic
  4. Save file
  5. Report completion

  JAVASCRIPT CODE:
  const items = $input.all();
  return items.filter(item => item.json.status === 'active');
  `
});

// backend-developer agent:
// - Reads local file (500 tokens)
// - Updates JS code (1K tokens)
// - Saves file (500 tokens)
// TOTAL: ~2K tokens

// User imports updated file to n8n UI
```

**Token Savings**: 98K tokens (98% reduction)

---

## Example 2: Connection Restructure

### User Request
> "I need to add a new 'Validate Input' node between 'Webhook' and 'Process Data'. Move the connection."

### ❌ INEFFICIENT Approach (100K+ tokens)

```javascript
// Main agent fetches entire workflow
const workflow = mcp__name__n8n_get_workflow({ id: 'xyz' });
// 50K tokens

// Add new node
workflow.nodes.push({
  id: crypto.randomUUID(),
  name: 'Validate Input',
  type: 'n8n-nodes-base.function',
  typeVersion: 1,
  position: [400, 300],
  parameters: { /* ... */ }
});

// Update connections
delete workflow.connections['Webhook'];
workflow.connections['Webhook'] = {
  main: [[{ node: 'Validate Input', type: 'main', index: 0 }]]
};
workflow.connections['Validate Input'] = {
  main: [[{ node: 'Process Data', type: 'main', index: 0 }]]
};

// Update entire workflow
mcp__name__n8n_update_full_workflow({ id: 'xyz', ...workflow });
// 50K tokens

// TOTAL: ~100K tokens
```

### ✅ EFFICIENT Approach (3-5K tokens)

```javascript
// Main agent delegates
Task({
  subagent_type: 'backend-developer',
  description: 'Add node and restructure connections',
  prompt: `Add 'Validate Input' node between 'Webhook' and 'Process Data' in workflow file.

  FILE: n8n-flows/my-workflow.json

  STEPS:
  1. Add new Function node named 'Validate Input'
     - Type: n8n-nodes-base.function
     - Position: [400, 300]
     - Parameters: { functionCode: '// Validation logic\nreturn items;' }

  2. Update connections (NAME-BASED):
     - Webhook → Validate Input
     - Validate Input → Process Data
     - Remove old: Webhook → Process Data

  3. Validate node names exist before connecting

  CRITICAL: Use NAME-BASED connections (node names, not UUIDs)
  `
});

// backend-developer agent:
// - Reads file (500 tokens)
// - Adds node + updates connections (2K tokens)
// - Saves file (500 tokens)
// TOTAL: ~3K tokens
```

**Token Savings**: 97K tokens (97% reduction)

---

## Example 3: Failed Execution Diagnosis

### User Request
> "Execution 1520 failed. Can you tell me what went wrong and how to fix it?"

### ❌ INEFFICIENT Approach (70K+ tokens)

```javascript
// Main agent fetches full execution data
const execution = mcp__name__n8n_get_execution({
  id: '1520',
  mode: 'full'  // Gets ALL data from ALL nodes
});
// 50K tokens

// Analyzes all data looking for error
const error = execution.data.resultData.error;
const failedNode = execution.stoppedAt;

// Fetches workflow to understand context
const workflow = mcp__name__n8n_get_workflow({ id: execution.workflowId });
// 20K tokens

// TOTAL: ~70K tokens
```

### ✅ EFFICIENT Approach (7-12K tokens)

```javascript
// Main agent: Quick triage
const preview = mcp__name__n8n_get_execution({
  id: '1520',
  mode: 'preview'  // Structure only, no data
});
// 2K tokens

const failedNode = preview.stoppedAt;
const errorMsg = preview.data?.resultData?.error?.message;

// Delegate detailed analysis
Task({
  subagent_type: 'debug-specialist',
  description: 'Diagnose execution failure',
  prompt: `Analyze failed execution 1520.

  CONTEXT:
  - Failed at node: ${failedNode}
  - Error message: ${errorMsg}

  APPROACH:
  1. Use n8n_get_execution with:
     - mode: 'filtered'
     - nodeNames: ['${failedNode}']
     - itemsLimit: 5
     - includeInputData: true

  2. Analyze:
     - What was the input data?
     - What caused the error?
     - What's the expected format?

  3. Suggest fix:
     - Update node configuration
     - Add data transformation
     - Add error handling

  Token budget: 10K
  `
});

// debug-specialist agent:
// - Gets filtered execution data (5-8K tokens)
// - Analyzes error (2K tokens)
// TOTAL: ~7-10K tokens
```

**Token Savings**: 60K tokens (86% reduction)

### Output Example

```
🔍 Execution 1520 Analysis

❌ FAILED AT: HTTP Request node

🔴 ERROR: Invalid JSON response
- Expected: {"data": [...]}
- Received: "Error: Connection timeout"

🔧 ROOT CAUSE:
The external API returned an error string instead of JSON,
but the HTTP Request node is configured to parse JSON automatically.

✅ FIX:
Update HTTP Request node settings:
1. Set "Response Format" to "Text" instead of "JSON"
2. Add downstream Function node to parse JSON safely:

const response = $input.first().json.response;
try {
  return [{ json: JSON.parse(response) }];
} catch (error) {
  return [{ json: { error: 'Invalid JSON', raw: response } }];
}

This handles both successful JSON responses and error strings.
```

---

## Example 4: Multi-Step Workflow Enhancement

### User Request
> "I want to add error handling to my workflow. Add an If node after 'HTTP Request' to check for errors, and route errors to a 'Send Error Email' node. Update the HTTP Request to not fail on errors."

### ❌ INEFFICIENT Approach (150K+ tokens)

```javascript
// Main agent does everything sequentially:

// 1. Fetch workflow
const workflow = mcp__name__n8n_get_workflow({ id: 'xyz' });
// 50K tokens

// 2. Get node info for If node
const ifNodeInfo = mcp__name__get_node_info('nodes-base.if');
// 20K tokens

// 3. Get node info for Email node
const emailNodeInfo = mcp__name__get_node_info('nodes-base.emailSend');
// 20K tokens

// 4. Update HTTP Request node
// 5. Add If node
// 6. Add Email node
// 7. Update all connections

// 8. Update workflow
mcp__name__n8n_update_full_workflow({ id: 'xyz', ...workflow });
// 50K tokens

// 9. Validate
const validation = mcp__name__validate_workflow(workflow);
// 10K tokens

// TOTAL: ~150K tokens
```

### ✅ EFFICIENT Approach (15-25K tokens)

```javascript
// Main agent orchestrates
Task({
  subagent_type: 'tech-lead-orchestrator',
  description: 'Add error handling workflow',
  prompt: `Add comprehensive error handling to n8n workflow.

  FILE: n8n-flows/my-workflow.json

  REQUIREMENTS:
  1. HTTP Request node should not fail on HTTP errors
  2. Add If node to detect errors
  3. Add Email node for error notifications
  4. Route: Success → Original path, Error → Email

  ORCHESTRATION PLAN:

  Phase 1 (backend-developer):
    - Update HTTP Request node settings:
      * continueOnFail: true
      * Add error output

    - Add If node "Check for Error":
      * Position: [600, 300]
      * Condition: {{$json.error}} exists
      * True → Email node
      * False → Continue to Process Data

    - Add Email Send node "Send Error Email":
      * Position: [800, 400]
      * To: admin@example.com
      * Subject: "Workflow Error"
      * Body: {{$json.error}}

    - Update connections (name-based):
      * HTTP Request → Check for Error
      * Check for Error (false) → Process Data
      * Check for Error (true) → Send Error Email

  Phase 2 (main agent):
    - Validate workflow structure
    - Report completion

  TOKEN BUDGET: 20K
  `
});

// tech-lead-orchestrator:
// - Plans approach (2K tokens)
// - Delegates to backend-developer (10-15K tokens)
// - Validates with main agent (3K tokens)
// TOTAL: ~15-20K tokens
```

**Token Savings**: 130K tokens (87% reduction)

---

## Example 5: Template-Based Workflow Creation

### User Request
> "Create a workflow that sends a Slack message when a webhook is triggered. Use the best practices template."

### ❌ INEFFICIENT Approach (60K+ tokens)

```javascript
// Main agent manually constructs everything

// 1. Get node info for each node type
const webhookInfo = mcp__name__get_node_info('nodes-base.webhook');
// 20K tokens
const slackInfo = mcp__name__get_node_info('nodes-base.slack');
// 20K tokens

// 2. Manually build workflow structure
const workflow = {
  name: 'Webhook to Slack',
  nodes: [/* ... */],
  connections: {/* ... */}
};

// 3. Validate each node
// 10K tokens

// 4. Create workflow
mcp__name__n8n_create_workflow(workflow);
// 10K tokens

// TOTAL: ~60K tokens
```

### ✅ EFFICIENT Approach (5-10K tokens)

```javascript
// Main agent: Find template first
const templates = mcp__name__search_templates({
  query: 'webhook slack notification'
});
// 1K tokens

// If template found:
const template = mcp__name__get_template({
  templateId: templates.data[0].id,
  mode: 'structure'  // Nodes + connections only
});
// 2-3K tokens

// Delegate customization
Task({
  subagent_type: 'backend-developer',
  description: 'Customize Slack notification template',
  prompt: `Customize n8n template for Slack notifications.

  BASE TEMPLATE: ${JSON.stringify(template)}

  CUSTOMIZATIONS:
  1. Webhook path: /notify
  2. Slack channel: #notifications
  3. Message format: "Alert: {{$json.message}}"

  STEPS:
  1. Update Webhook node parameters
  2. Update Slack node parameters
  3. Save as: n8n-flows/webhook-to-slack.json

  User will import to n8n UI.
  `
});

// backend-developer:
// - Customizes template (3-5K tokens)
// TOTAL: ~6-9K tokens

// Alternative: If no template found, get node essentials (not full info)
const webhookEssentials = mcp__name__get_node_essentials('nodes-base.webhook');
// 2K tokens
const slackEssentials = mcp__name__get_node_essentials('nodes-base.slack');
// 2K tokens
// TOTAL: ~4K tokens (instead of 40K for full info)
```

**Token Savings**: 50K tokens (83% reduction)

---

## Bonus: Execution Comparison

### User Request
> "Execution 1519 succeeded but 1520 failed with the same input. What's different?"

### ✅ EFFICIENT Approach (10-15K tokens)

```javascript
Task({
  subagent_type: 'debug-specialist',
  description: 'Compare execution outcomes',
  prompt: `Compare executions 1519 (success) vs 1520 (failed).

  APPROACH:
  1. Get both executions in 'summary' mode (2 items each)
     - n8n_get_execution({ id: '1519', mode: 'summary' })
     - n8n_get_execution({ id: '1520', mode: 'summary' })

  2. Identify divergence point:
     - Which node shows different output?
     - Where did 1520 stop?

  3. Get detailed data for divergence point:
     - Use mode: 'filtered' with specific node name
     - Compare input data between executions

  4. Report:
     - What's different in the input?
     - Why did 1520 fail?
     - How to prevent this?

  TOKEN BUDGET: 15K
  `
});

// debug-specialist:
// - Fetches 2 summaries (10K tokens)
// - Analyzes differences (3K tokens)
// - (Optional) Fetches filtered data if needed (5K tokens)
// TOTAL: ~13-18K tokens (adaptive based on findings)
```

### Output Example

```
📊 Execution Comparison: 1519 vs 1520

✅ Execution 1519: SUCCESS
- Input: { "userId": "123", "action": "subscribe" }
- All 8 nodes executed

❌ Execution 1520: FAILED
- Input: { "userId": "456", "action": null }
- Failed at node 3: "Process Action"

🔍 DIVERGENCE POINT: "Process Action" node

INPUT DIFFERENCES:
1519: action = "subscribe" ✓
1520: action = null ✗

🔴 ERROR: Cannot read property 'toLowerCase' of null
- Code: action.toLowerCase() === 'subscribe'
- Assumes 'action' always has a value

✅ FIX:
Add null check in "Process Action" node:

const action = $json.action || '';
if (action.toLowerCase() === 'subscribe') {
  // ...
}

Or add validation earlier in workflow:
- If node: Check $json.action exists
- Route invalid inputs to error handler
```

---

## Summary of Token Savings

| Example | Operation | Without Agents | With Agents | Savings |
|---------|-----------|----------------|-------------|---------|
| 1 | JS Update | 100K | 2K | **98%** |
| 2 | Connection Change | 100K | 3K | **97%** |
| 3 | Execution Diagnosis | 70K | 10K | **86%** |
| 4 | Multi-Step Enhancement | 150K | 20K | **87%** |
| 5 | Template Creation | 60K | 8K | **87%** |

**Average Token Reduction: 91%**

---

## Key Patterns Demonstrated

1. ✅ **Progressive Data Loading**: Start with preview/summary, drill down only if needed
2. ✅ **Agent Specialization**: Use the right agent for each operation type
3. ✅ **Local File Operations**: Edit JSON files directly when possible
4. ✅ **Node Essentials First**: Get 2K of essentials before 20K of full info
5. ✅ **Batch Operations**: Group multiple changes in single API call
6. ✅ **Template Reuse**: Search templates before building from scratch
7. ✅ **Targeted Updates**: Use partial updates, not full workflow replacements

---

## Anti-Patterns to Avoid

❌ **Fetching full workflow to change one field**
- Costs: 50K tokens
- Alternative: Partial update (3K tokens)

❌ **Getting full node info without checking essentials**
- Costs: 20K tokens
- Alternative: Essentials first (2K tokens)

❌ **Using full execution mode for status checks**
- Costs: 50K tokens
- Alternative: Preview mode (2K tokens)

❌ **Main agent doing complex multi-step operations**
- Costs: 100K+ tokens
- Alternative: Orchestrator + specialists (20K tokens)

❌ **Creating UUID-based connections**
- Result: Workflow doesn't execute
- Alternative: Always use name-based connections

---

## Next Steps

For more information:
- [Best Practices Guide](./N8N-AGENT-BEST-PRACTICES.md) - Complete strategy documentation
- [Quick Reference](./N8N-QUICK-REFERENCE.md) - Fast decision-making cheat sheet
- [Workflow Guide](./N8N-WORKFLOW-GUIDE.md) - n8n structure and API documentation
