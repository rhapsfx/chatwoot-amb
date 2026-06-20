# claude-agents.sh

The `claude-agents.sh` script manages Claude Code subagents from multiple sources with intelligent discovery and user protection.

## Overview

Professional subagent management for Claude Code:

- **Multiple Sources**: Install subagents from various repositories (claude-toolkit, team sources, custom sources)
- **Command-First Interface**: Explicit commands required for all operations
- **User Subagent Protection**: Always preserves your custom subagents during operations
- **Smart Conflict Resolution**: Handles naming conflicts intelligently

*Note: Source management (adding, removing, listing sources) is handled by the separate `claude-template-sources` command.*

## Quick Start

```bash
# Install subagents from all configured sources
claude-agents install

# List all subagents from all sources
claude-agents list

# List subagents from specific source
claude-agents list --source claude-toolkit
claude-agents list --source user

# Add a new subagent source (using separate command)
claude-template-sources add team-alpha git@github.com:myorg/agents.git
claude-agents install --source team-alpha

# Update to latest subagents
claude-agents reinstall
```

## Command Structure

All operations follow the command-first pattern:

```bash
claude-agents <command> [options]
```

**Available Commands:**

| Command | Purpose | Documentation |
|---------|---------|---------------|
| `install` | Deploy subagents from sources | [Installation Guide](install.md) |
| `list` | Show installed subagents | [Subagent Listing](list.md) |
| `reinstall` | Update/refresh subagents | [Reinstall Process](reinstall.md) |
| `uninstall` | Remove subagents from sources | [Uninstall Guide](uninstall.md) |

*Note: Source management commands (`add`, `remove`, `list`) are available via the `claude-template-sources` command.*

## Powerful Built-in Subagents

After installation, you get these professional subagents:

- **`architect`** - Expert software architect for comprehensive architectural analysis and design guidance
- **`test-writer-debugger`** - Expert test writer and debugger for comprehensive test suite management
- **`statusline-setup`** - Specialized agent for configuring Claude Code status line settings
- **`output-style-setup`** - Expert agent for creating custom Claude Code output styles

## Key Features

### User Subagent Protection
Your custom subagents are **always preserved**:
- Never overwritten during install/reinstall/uninstall operations
- Renamed safely if naming conflicts occur with source subagents
- Clearly distinguished from source subagents (user subagents have no `source:` field)

### Multiple Source Support
- Install subagents from multiple repositories simultaneously
- Configure team-specific or project-specific subagent sources
- Source-based filtering and management
- Repository caching for performance

### Directory Structure
- **Installation Location**: `~/.claude/agents/`
- **Source Subagents**: Files with `source: <source-name>` in YAML frontmatter
- **User Subagents**: Files without `source:` field in YAML frontmatter
- **Source Configuration**: `~/.config/claude-templates/sources.csv`
- **Repository Cache**: `~/.cache/claude-templates/`

## Common Usage Patterns

```bash
# Initial setup
claude-agents install

# Add team subagent sources (using separate command)
claude-template-sources add team-alpha git@github.com:myorg/alpha-agents.git
claude-template-sources add team-beta git@github.com:myorg/beta-agents.git
claude-agents install --source team-alpha,team-beta

# Check what's installed from all sources
claude-agents list

# Check what sources are configured (using separate command)
claude-template-sources list

# Get latest updates from all sources
claude-agents reinstall

# Get updates from specific source
claude-agents reinstall --source claude-toolkit

# See only your custom subagents (user source)
claude-agents list --source user

# See subagents from specific source
claude-agents list --source team-alpha

# Clean removal of subagents from specific source (keeps other sources)
claude-agents uninstall --source team-alpha
```

## Global Options

Available with all commands:
- `--dry-run` - Preview operations without making changes
- `--yes, -y, --force` - Skip confirmation prompts
- `--https` - Use HTTPS git URLs instead of SSH
- `--help, -h` - Show command help

## List Command Options

Available only with the `list` command:
- `--source <name>` - List subagents from specific source: all (default), user, claude-toolkit, or any configured source
- `--source <name1,name2>` - List subagents from comma-separated list of sources
- `--format <format>` - Output format: compact (default) or detailed

## Creating Custom Subagents

Create custom subagents by placing Markdown files in `~/.claude/agents/`:

1. Create a `.md` file with YAML frontmatter
2. Define the subagent's capabilities and tools
3. Write clear instructions for the AI assistant
4. Test and iterate

Subagents support:
- `tools` field to specify available tools
- `description` field for clear purpose definition
- Rich markdown instructions for behavior

## Quick Troubleshooting

**Subagents not appearing after installation:**
- Check installation: `claude-agents list`
- Check source configuration: `claude-template-sources list`
- Restart Claude Code to refresh subagent list

**Source management issues:**
- Verify source exists: `claude-template-sources list`
- Check repository access: ensure git credentials are configured
- Verify source URLs are accessible

**Network/authentication issues:**
- Use HTTPS mode: `claude-agents install --https` (during initial toolkit setup)
- Check VPN connection to internal networks
- Verify Git authentication for source repositories

**For detailed troubleshooting, use dry-run mode:**
```bash
claude-agents install --dry-run
claude-agents list --format detailed
claude-template-sources list
```

## Related Documentation

- **[Installation Process](install.md)** - Deploy toolkit subagents and handle conflicts
- **[Subagent Listing](list.md)** - View subagents with filtering options
- **[Reinstall Process](reinstall.md)** - Update subagents while preserving customizations
- **[Uninstall Process](uninstall.md)** - Remove toolkit subagents safely
- **[Dry Run Mode](dry-run.md)** - Preview operations without changes
- **[Troubleshooting Guide](troubleshooting.md)** - Common issues and solutions