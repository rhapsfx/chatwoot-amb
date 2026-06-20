# claude-slash.sh

The `claude-slash.sh` script manages Claude Code slash commands from multiple sources with intelligent discovery and user protection.

## Overview

Professional slash command management for Claude Code:

- **Multiple Sources**: Install commands from various repositories (claude-toolkit, team sources, custom sources)
- **Command-First Interface**: Explicit commands required for all operations
- **User Command Protection**: Always preserves your custom commands during operations
- **Smart Conflict Resolution**: Handles naming conflicts intelligently

*Note: Source management (adding, removing, listing sources) is handled by the separate `claude-template-sources` command.*

## Quick Start

```bash
# Install commands from all configured sources
claude-slash install

# List all commands from all sources
claude-slash list

# List commands from specific source
claude-slash list --source claude-toolkit
claude-slash list --source user

# Add a new command source (using separate command)
claude-template-sources add team-alpha git@github.com:myorg/commands.git
claude-slash install --source team-alpha

# Update to latest commands
claude-slash reinstall
```

## Command Structure

All operations follow the command-first pattern:

```bash
```bash
claude-slash <command> [options]
```

**Available Commands:**

| Command | Purpose | Documentation |
|---------|---------|---------------|
| `install` | Deploy commands from sources | [Installation Guide](install.md) |
| `list` | Show installed commands | [Command Listing](list.md) |
| `reinstall` | Update/refresh commands | [Reinstall Process](reinstall.md) |
| `uninstall` | Remove commands from sources | [Uninstall Guide](uninstall.md) |

*Note: Source management commands (`add`, `remove`, `list`) are available via the `claude-template-sources` command.*

## Powerful Built-in Commands

After installation, you get these professional commands:

- **`/smart-commit`** - Intelligent commit analysis with file organization
- **`/review-codebase`** - Comprehensive code analysis with security insights  
- **`/quick-commit`** - Streamlined workflow for simple changes
- **`/add-command`** - Interactive wizard for creating custom commands

## Key Features

### User Command Protection
Your custom commands are **always preserved**:
- Never overwritten during install/reinstall/uninstall operations
- Renamed safely if naming conflicts occur with source commands
- Clearly distinguished from source commands (user commands have no `source:` field)

### Multiple Source Support
- Install commands from multiple repositories simultaneously
- Configure team-specific or project-specific command sources
- Source-based filtering and management
- Repository caching for performance

### Directory Structure
- **Installation Location**: `~/.claude/commands/`
- **Source Commands**: Files with `source: <source-name>` in YAML frontmatter
- **User Commands**: Files without `source:` field in YAML frontmatter
- **Source Configuration**: `~/.config/claude-templates/sources.csv`
- **Repository Cache**: `~/.cache/claude-templates/`

## Common Usage Patterns

```bash
# Initial setup
claude-slash install

# Add team command sources (using separate command)
claude-template-sources add team-alpha git@github.com:myorg/alpha-commands.git
claude-template-sources add team-beta git@github.com:myorg/beta-commands.git
claude-slash install --source team-alpha,team-beta

# Check what's installed from all sources
claude-slash list

# Check what sources are configured (using separate command)
claude-template-sources list

# Get latest updates from all sources
claude-slash reinstall

# Get updates from specific source
claude-slash reinstall --source claude-toolkit

# See only your custom commands (user source)
claude-slash list --source user

# See commands from specific source
claude-slash list --source team-alpha

# Clean removal of commands from specific source (keeps other sources)
claude-slash uninstall --source team-alpha
```

## Global Options

Available with all commands:
- `--dry-run` - Preview operations without making changes
- `--yes, -y, --force` - Skip confirmation prompts
- `--https` - Use HTTPS git URLs instead of SSH
- `--help, -h` - Show command help

## List Command Options

Available only with the `list` command:
- `--source <name>` - List commands from specific source: all (default), user, claude-toolkit, or any configured source
- `--source <name1,name2>` - List commands from comma-separated list of sources
- `--format <format>` - Output format: compact (default) or detailed

## Creating Custom Commands

Use the built-in helper within Claude Code:

1. Start Claude Code in your project
2. Run `/add-command project my-command`
3. Follow the interactive wizard
4. Test and iterate

Commands support dynamic features:
- `$ARGUMENTS` - User input
- `@filename` - File content inclusion  
- `!command` - Shell command execution

## Quick Troubleshooting

**Commands not appearing after installation:**
- Check installation: `claude-slash list`
- Check source configuration: `claude-template-sources list`
- Restart Claude Code to refresh command list

**Source management issues:**
- Verify source exists: `claude-template-sources list`
- Check repository access: ensure git credentials are configured
- Verify source URLs are accessible

**Network/authentication issues:**
- Use HTTPS mode: `claude-slash install --https` (during initial toolkit setup)
- Check VPN connection to internal networks
- Verify Git authentication for source repositories

**For detailed troubleshooting, use dry-run mode:**
```bash
claude-slash install --dry-run
claude-slash list --format detailed
claude-template-sources list
```

## Related Documentation

- **[Installation Process](install.md)** - Deploy toolkit commands and handle conflicts
- **[Command Listing](list.md)** - View commands with filtering options
- **[Reinstall Process](reinstall.md)** - Update commands while preserving customizations
- **[Uninstall Process](uninstall.md)** - Remove toolkit commands safely
- **[Dry Run Mode](dry-run.md)** - Preview operations without changes
- **[Troubleshooting Guide](troubleshooting.md)** - Common issues and solutions
