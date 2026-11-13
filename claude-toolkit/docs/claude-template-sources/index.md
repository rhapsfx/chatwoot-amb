# claude-template-sources.sh

The `claude-template-sources.sh` script manages template source repositories - git repositories containing Claude Code slash commands and subagents.

## Overview

Template source management for Claude Code:

- **Source Repository Management**: Add, remove, and list git repositories containing slash commands
- **Multi-Source Support**: Manage commands from multiple sources (claude-toolkit, team sources, custom sources)
- **Command Integration**: Works seamlessly with `claude-slash.sh` for command installation
- **Repository Caching**: Efficient caching of source repositories for performance

*Note: This script manages source configurations only. Use `claude-slash.sh` for installing commands from sources.*

## Quick Start

```bash
# List configured sources
claude-template-sources list

# Add a new source repository
claude-template-sources add team-alpha git@github.com:myorg/commands.git

# Remove a source configuration
claude-template-sources remove team-alpha

# Install commands from sources (using claude-slash.sh)
claude-slash install --source team-alpha
```

## Command Structure

All operations follow the command-first pattern:

```bash
claude-template-sources <command> [options]
```

**Available Commands:**

| Command | Purpose | Documentation |
|---------|---------|---------------|
| `add` | Add template source repository | [Add Sources](add.md) |
| `remove` | Remove source configuration | [Remove Sources](remove.md) |
| `list` | List configured sources | [List Sources](list.md) |

## Key Features

### Repository-Based Sources
- Configure git repositories containing slash commands
- Support for both SSH and HTTPS git URLs
- Automatic repository validation and caching
- Integration with Apple's internal git infrastructure

### Source Management
- **Add Sources**: Configure new template repositories
- **Remove Sources**: Clean removal of source configurations
- **List Sources**: View all configured sources with details
- **Validation**: Ensures repositories contain valid slash commands

### Integration with claude-slash.sh
Template sources work seamlessly with command installation:

```bash
# 1. Add source repositories
claude-template-sources add team-alpha git@github.com:myorg/alpha-commands.git
claude-template-sources add team-beta git@github.com:myorg/beta-commands.git

# 2. Install commands from sources
claude-slash install --source team-alpha,team-beta

# 3. List installed commands by source
claude-slash list --source team-alpha
```

## Common Usage Patterns

### Team Source Management
```bash
# Add team-specific command sources
claude-template-sources add team-alpha git@github.com:myorg/alpha-commands.git
claude-template-sources add team-beta git@github.com:myorg/beta-commands.git

# List configured sources
claude-template-sources list

# Install commands from team sources
claude-slash install --source team-alpha,team-beta

# Update team commands
claude-slash reinstall --source team-alpha
```

### Repository Structure
Template source repositories should contain:

```
repository-root/
├── slash-commands/           # Required directory
│   ├── command1.md          # Slash command files
│   ├── command2.md
│   └── subdirectory/
│       └── command3.md
└── README.md                # Optional documentation
```

Each command file should have proper YAML frontmatter:

```markdown
---
description: Command description
source: source-name          # Should match source name
argument-hint: <arguments>   # Optional
---

# Command Content
Instructions for Claude Code...
```

## Global Options

Available with all commands:
- `--dry-run` - Preview operations without making changes
- `--debug` - Enable debug output
- `--porcelain` - Machine-readable output format
- `--help, -h` - Show command help

## Directory Structure

Template sources use XDG-compliant directories:

- **Source Configuration**: `~/.config/claude-templates/sources.csv`
- **Repository Cache**: `~/.cache/claude-templates/`
- **Installed Commands**: `~/.claude/commands/` (managed by claude-slash.sh)

## Source Repository Requirements

### Required Structure
1. **Git Repository**: Must be a valid git repository
2. **slash-commands Directory**: Must contain `slash-commands/` directory
3. **Command Files**: At least one `.md` file in `slash-commands/`
4. **Valid Frontmatter**: Each command file must have proper YAML frontmatter

### Example Repository
```bash
# Create a template source repository
mkdir my-team-commands
cd my-team-commands
git init

mkdir slash-commands
cat > slash-commands/deploy.md << 'EOF'
---
description: Deploy application with safety checks
source: my-team
argument-hint: <environment>
---

# Deploy Command
Deploy application to specified environment.
EOF

git add . && git commit -m "Initial commands"
```

## Integration Examples

### Development Workflow
```bash
# Check current sources
claude-template-sources list

# Add new team source
claude-template-sources add my-team git@github.com:myorg/team-commands.git

# Install commands from new source
claude-slash install --source my-team

# List commands from all sources
claude-slash list
```

### Source Updates
```bash
# Sources are automatically updated when installing commands
claude-slash reinstall --source my-team

# Or update all sources
claude-slash reinstall
```

## Quick Troubleshooting

**Source not found after adding:**
- Verify git repository is accessible: `git clone <repository-url>`
- Check repository contains `slash-commands/` directory
- Ensure command files have valid YAML frontmatter

**Installation issues:**
- Check source configuration: `claude-template-sources list`
- Verify git credentials are configured
- Use dry-run mode: `claude-template-sources add <name> <url> --dry-run`

**For detailed troubleshooting, see:**
- **[Troubleshooting Guide](troubleshooting.md)** - Common issues and solutions
- **[Dry Run Mode](dry-run.md)** - Preview operations safely

## Related Documentation

- **[Add Sources](add.md)** - Add new template source repositories
- **[Remove Sources](remove.md)** - Remove source configurations
- **[List Sources](list.md)** - View configured sources
- **[Dry Run Mode](dry-run.md)** - Preview operations without changes
- **[Troubleshooting Guide](troubleshooting.md)** - Common issues and solutions

**Integration:**
- **[Claude Slash Commands](../claude-slash/index.md)** - Installing commands from sources
- **[Architecture](../architecture.md)** - System design and component relationships