# n8n Documentation Index for Claude Agents

**Purpose**: Navigation guide for Claude agents working with n8n workflows

**Quick Access**: Use this index to find the right documentation quickly

---

## 🚀 Start Here

### 🚨 Hit an Error?
👉 **["Input is too long for requested model"](TROUBLESHOOTING-INPUT-TOO-LONG.md)** (5 min)
- Common error when using n8n MCP tools
- Shows progressive loading pattern
- Prevents context overflow
- 86-93% token reduction

### First Time Working with n8n?
👉 **[Quick Reference Card](N8N-QUICK-REFERENCE.md)** (2 min read)
- Fast decision matrix
- Token cost comparison
- Operation patterns
- Agent selection cheat sheet

### Need to Perform a Specific Operation?
👉 **[Practical Examples](N8N-PRACTICAL-EXAMPLES.md)** (10 min read)
- Real-world scenarios with code
- Before/after token comparisons
- Step-by-step implementations
- 5 complete examples covering common tasks

### Want Comprehensive Strategy?
👉 **[Agent Best Practices](N8N-AGENT-BEST-PRACTICES.md)** (20 min read)
- Complete token optimization techniques
- Agent routing strategies
- Progressive data loading patterns
- Detailed troubleshooting guide

### Need n8n Workflow Structure Details?
👉 **[n8n-flows/N8N-WORKFLOW-GUIDE.md](../../n8n-flows/N8N-WORKFLOW-GUIDE.md)** (30 min read)
- Workflow JSON structure
- Connection format (UUID vs name-based)
- Helper scripts documentation
- API endpoints reference

---

## 📚 Documentation Matrix

| When You Need To... | Read This | Time | Tokens Saved |
|---------------------|-----------|------|--------------|
| **Quick decision** on which agent to use | [Quick Reference](N8N-QUICK-REFERENCE.md) | 2 min | N/A |
| **Update JS** in a Code node | [Example 1](N8N-PRACTICAL-EXAMPLES.md#example-1-simple-js-update) | 3 min | 98% |
| **Change connections** between nodes | [Example 2](N8N-PRACTICAL-EXAMPLES.md#example-2-connection-restructure) | 3 min | 97% |
| **Debug failed execution** | [Example 3](N8N-PRACTICAL-EXAMPLES.md#example-3-failed-execution-diagnosis) | 5 min | 86% |
| **Multi-step workflow** enhancement | [Example 4](N8N-PRACTICAL-EXAMPLES.md#example-4-multi-step-workflow-enhancement) | 7 min | 87% |
| **Understand workflow structure** | [N8N-WORKFLOW-GUIDE.md](../../n8n-flows/N8N-WORKFLOW-GUIDE.md) | 15 min | N/A |
| **Token optimization strategy** | [Best Practices](N8N-AGENT-BEST-PRACTICES.md) | 20 min | 85-90% |
| **Progressive data loading** | [Best Practices - Execution Review](N8N-AGENT-BEST-PRACTICES.md#execution-review-workflows) | 5 min | 60-80% |

---

## 🎯 Common User Requests → Documentation

| User Says | Go To | Section |
|-----------|-------|---------|
| "Update the JS code in node X" | [Practical Examples](N8N-PRACTICAL-EXAMPLES.md) | Example 1 |
| "Connect node A to node B" | [Practical Examples](N8N-PRACTICAL-EXAMPLES.md) | Example 2 |
| "Why did execution X fail?" | [Practical Examples](N8N-PRACTICAL-EXAMPLES.md) | Example 3 |
| "Add error handling to my workflow" | [Practical Examples](N8N-PRACTICAL-EXAMPLES.md) | Example 4 |
| "Create a workflow for..." | [Practical Examples](N8N-PRACTICAL-EXAMPLES.md) | Example 5 |
| "Should I use an agent or do this myself?" | [Quick Reference](N8N-QUICK-REFERENCE.md) | Decision Matrix |
| "How much will this operation cost in tokens?" | [Quick Reference](N8N-QUICK-REFERENCE.md) | Token Cost Quick Comparison |
| "My connections don't work" | [Workflow Guide](../../n8n-flows/N8N-WORKFLOW-GUIDE.md) | UUID vs Name-Based |
| "What's the workflow structure?" | [Workflow Guide](../../n8n-flows/N8N-WORKFLOW-GUIDE.md) | Top-Level Structure |

---

## 🔧 By Operation Type

### Node Operations
- **Find node type**: [Quick Reference - Common User Requests](N8N-QUICK-REFERENCE.md#-common-user-requests--actions)
- **Configure node**: [Best Practices - Template 1](N8N-AGENT-BEST-PRACTICES.md#template-1-find-and-configure-node)
- **Update node JS**: [Practical Examples - Example 1](N8N-PRACTICAL-EXAMPLES.md#example-1-simple-js-update)

### Connection Operations
- **Add connection**: [Best Practices - Template 2](N8N-AGENT-BEST-PRACTICES.md#template-2-add-connection-to-existing-workflow)
- **Change connection**: [Practical Examples - Example 2](N8N-PRACTICAL-EXAMPLES.md#example-2-connection-restructure)
- **Fix broken connections**: [Workflow Guide - Debugging](../../n8n-flows/N8N-WORKFLOW-GUIDE.md#debugging-checklist)

### Execution Operations
- **Check status**: [Best Practices - Workflow A](N8N-AGENT-BEST-PRACTICES.md#workflow-a-quick-health-check)
- **Debug failure**: [Best Practices - Workflow B](N8N-AGENT-BEST-PRACTICES.md#workflow-b-diagnose-failed-execution)
- **Compare executions**: [Practical Examples - Bonus](N8N-PRACTICAL-EXAMPLES.md#bonus-execution-comparison)

### Workflow Operations
- **Create from template**: [Practical Examples - Example 5](N8N-PRACTICAL-EXAMPLES.md#example-5-template-based-workflow-creation)
- **Multi-step changes**: [Practical Examples - Example 4](N8N-PRACTICAL-EXAMPLES.md#example-4-multi-step-workflow-enhancement)
- **Validate workflow**: [Quick Reference - Operation Patterns](N8N-QUICK-REFERENCE.md#-operation-patterns)

---

## 💡 Token Optimization Quick Tips

### Always Do This:
✅ Use `mode: 'preview'` first for executions (1-3K tokens)
✅ Use `get_node_essentials` before `get_node_info` (2K vs 20K tokens)
✅ Work with local files when user has JSON (2-5K vs 50-100K tokens)
✅ Delegate to specialists for operations >3K tokens
✅ Use name-based connections (never UUIDs)

### Never Do This:
❌ Fetch full workflow to update one field
❌ Use `mode: 'full'` for execution review without trying preview first
❌ Get complete node info without checking essentials
❌ Do complex multi-step operations without orchestration
❌ Create UUID-based connections

**See**: [Quick Reference - Pro Tips](N8N-QUICK-REFERENCE.md#-pro-tips)

---

## 📖 Suggested Reading Order

### For Quick Tasks (< 5 min)
1. [Quick Reference](N8N-QUICK-REFERENCE.md) - Scan the decision matrix
2. Find relevant [Practical Example](N8N-PRACTICAL-EXAMPLES.md)
3. Execute

### For Complex Tasks (15-30 min)
1. [Quick Reference](N8N-QUICK-REFERENCE.md) - Understand approach
2. [Best Practices](N8N-AGENT-BEST-PRACTICES.md) - Review relevant sections
3. [Practical Examples](N8N-PRACTICAL-EXAMPLES.md) - See similar patterns
4. Plan orchestration
5. Execute with agents

### For Deep Understanding (1-2 hours)
1. [Workflow Guide](../../n8n-flows/N8N-WORKFLOW-GUIDE.md) - Structure fundamentals
2. [Best Practices](N8N-AGENT-BEST-PRACTICES.md) - Complete strategy
3. [Practical Examples](N8N-PRACTICAL-EXAMPLES.md) - Patterns library
4. [Quick Reference](N8N-QUICK-REFERENCE.md) - Keep handy for decisions

---

## 🎓 Learning Path

### Beginner (Never worked with n8n)
Week 1: Quick Reference + Practical Examples 1-2
Week 2: Workflow Guide + Best Practices Sections 1-3
Week 3: Practical Examples 3-5 + Best Practices Sections 4-5

### Intermediate (Some n8n experience)
Day 1: Quick Reference (full read)
Day 2: Best Practices Sections 1-4
Day 3: Practical Examples (all)
Day 4: Practice with real workflows

### Advanced (Optimizing existing workflows)
- Focus on: Best Practices Sections 4-5 (Token Optimization, Execution Review)
- Reference: Quick Reference for fast decisions
- Deep dive: Practical Examples for pattern refinement

---

## 📞 Getting Help

### Common Errors

#### Error: "Input is too long for requested model"
→ **[Dedicated troubleshooting guide](TROUBLESHOOTING-INPUT-TOO-LONG.md)**
- Root cause: Using `mode: 'full'` or no mode specification
- Solution: Always start with `mode: 'preview'`
- Prevention: Progressive loading pattern

#### Error: "Connections don't work after import"
→ See [Workflow Guide](../../n8n-flows/N8N-WORKFLOW-GUIDE.md) - UUID vs Name-Based section
- Root cause: UUID-based connections instead of name-based
- Solution: Use `convert-to-name-based.js` script
- Prevention: Always use node names in connections

### General Problems

#### Problem: "I don't know which document to read"
→ Start with [Quick Reference](N8N-QUICK-REFERENCE.md) - Decision Matrix section

### Problem: "I need to do X but don't know the pattern"
→ Check [Practical Examples](N8N-PRACTICAL-EXAMPLES.md) - Table of Contents

### Problem: "My approach is using too many tokens"
→ Review [Best Practices](N8N-AGENT-BEST-PRACTICES.md) - Token Optimization section

### Problem: "Connections aren't working after import"
→ See [Workflow Guide](../../n8n-flows/N8N-WORKFLOW-GUIDE.md) - UUID vs Name-Based section

### Problem: "I need more details on workflow structure"
→ Read [Workflow Guide](../../n8n-flows/N8N-WORKFLOW-GUIDE.md) - Complete reference

---

## 📊 Document Statistics

| Document | Size | Reading Time | Token Savings | Best For |
|----------|------|--------------|---------------|----------|
| Quick Reference | 8KB | 2 min | N/A | Fast decisions |
| Practical Examples | 15KB | 10 min | 85-98% | Specific operations |
| Best Practices | 20KB | 20 min | 60-90% | Strategy & planning |
| Workflow Guide | 25KB | 30 min | N/A | Structure understanding |

**Total Reading Time**: ~60 minutes for complete understanding
**Token Savings After Implementation**: 85-90% average

---

## 🚀 Next Steps

1. **Read**: [Quick Reference](N8N-QUICK-REFERENCE.md) (2 min)
2. **Bookmark**: This index for future reference
3. **Execute**: Use patterns from [Practical Examples](N8N-PRACTICAL-EXAMPLES.md)
4. **Optimize**: Apply strategies from [Best Practices](N8N-AGENT-BEST-PRACTICES.md)
5. **Reference**: [Workflow Guide](../../n8n-flows/N8N-WORKFLOW-GUIDE.md) when needed

**Ready to Start?** → Choose your path above based on your task complexity!
