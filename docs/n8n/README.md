# n8n Integration Documentation

Complete documentation for integrating n8n workflow automation with Chatwoot.

## Main Documentation

- **[n8n Bot Integration Guide](n8n-bot-integration-guide.md)** - Comprehensive guide covering setup, configuration, custom nodes, production deployment, and troubleshooting

## For Claude Agents - Token Optimization

**NEW**: Efficient troubleshooting and workflow management using multi-agent patterns

- **[INDEX](INDEX.md)** 📖 - Start here! Navigation guide for all documentation
- **[Agent Best Practices](N8N-AGENT-BEST-PRACTICES.md)** ⭐ - Complete strategy for token-efficient n8n operations (60-90% token reduction)
- **[Quick Reference Card](N8N-QUICK-REFERENCE.md)** - Fast decision-making cheat sheet for operations
- **[Practical Examples](N8N-PRACTICAL-EXAMPLES.md)** - Real-world patterns with before/after token comparisons
- **[Troubleshooting: Input Too Long](TROUBLESHOOTING-INPUT-TOO-LONG.md)** 🚨 - Fix "Input is too long for requested model" error
- **[Troubleshooting: Filtered Mode Too Large](TROUBLESHOOTING-FILTERED-MODE-TOO-LARGE.md)** 🚨🚨 - Even filtered mode can be too large with images/large data

**Key Benefits**:
- 85-90% token reduction for typical workflow operations
- Clear agent routing strategies (main vs backend-developer vs debug-specialist)
- Progressive data loading patterns for execution review
- Efficient MCP tool usage vs custom scripts
- Prevents context overflow errors

## Examples

- **[Quick Reply Routing Example](n8n-quick-reply-routing-example.md)** - Example workflow showing how to extract and route customer responses from quick reply buttons

## Utilities

- **[verify-node-installation.sh](verify-node-installation.sh)** - Script to verify custom n8n node installation

## Additional Resources

### Fix Reports
- **[fixes/CUSTOM_NODES_FIXED.md](fixes/CUSTOM_NODES_FIXED.md)** - Resolution of custom node symlink issues

### Status Reports
- **[reports/NODE_STATUS_REPORT.md](reports/NODE_STATUS_REPORT.md)** - Custom node installation status and validation errors

## Quick Start

### For Users
1. Read the [main integration guide](n8n-bot-integration-guide.md) for complete setup instructions
2. Follow the custom nodes installation section for Apple Messages for Business features
3. See the [quick reply example](n8n-quick-reply-routing-example.md) for a practical workflow implementation
4. Deploy to production using the production deployment section in the main guide

### For Claude Agents
1. **Start here**: Read the [Quick Reference Card](N8N-QUICK-REFERENCE.md) (2 min)
2. **For specific operations**: Check [Practical Examples](N8N-PRACTICAL-EXAMPLES.md)
3. **For comprehensive strategy**: Review [Agent Best Practices](N8N-AGENT-BEST-PRACTICES.md)
4. **For workflow structure**: See [n8n-flows/N8N-WORKFLOW-GUIDE.md](../../n8n-flows/N8N-WORKFLOW-GUIDE.md)

## Key Features

- Custom n8n nodes for Apple Messages for Business interactive messages
- Bot API integration with Chatwoot templates
- Production deployment workflows
- Network configuration for Docker environments
- Troubleshooting guides for common issues

## Support

For issues or questions:
- Check the Troubleshooting section in the main guide
- Review fix reports in `fixes/` directory
- Consult Chatwoot and n8n official documentation
