# List Command

View installed Claude Code slash commands with source filtering options to distinguish between different command sources and user-created commands.

## Overview

The `list` command displays all installed slash commands in the `~/.claude/commands/` directory. It provides source-based filtering capabilities to show commands from specific sources (claude-toolkit, team sources, user commands, etc.) with their origins clearly identified.

## Basic Usage

```bash
# List all installed slash commands from all sources
claude-slash list

# List commands from specific source
claude-slash list --source claude-toolkit
claude-slash list --source user
claude-slash list --source team-alpha

# List commands from multiple sources
claude-slash list --source user,claude-toolkit

# Show detailed information
claude-slash list --format detailed

# Preview list without changes
claude-slash list --dry-run
```

## Command Syntax

```bash
claude-slash list [options]
```

### Source Filtering

| Source | Description |
|--------|-------------|
| (none) | Shows all commands from all sources with origin indicators (default) |
| `all` | Shows all commands from all sources (explicit) |
| `user` | Shows only user-created commands (no source field) |
| `claude-toolkit` | Shows only commands from the claude-toolkit source |
| `<source-name>` | Shows commands from specific configured source |
| `<name1,name2>` | Shows commands from comma-separated list of sources |

### Options

| Option | Description |
|--------|-------------|
| `--source <name>` | Filter by source: all (default), user, claude-toolkit, or any configured source |
| `--source <name1,name2>` | Filter by comma-separated list of sources |
| `--format <format>` | Output format: compact (default) or detailed |
| `--dry-run` | Preview list operation without making system modifications |

## Output Format

### All Commands (Default)

Shows all commands with source indicators:

```bash
$ claude-slash list
add-command.md (claude-toolkit)
auth-helper.md (user)
deploy.md (team-alpha)
quick-commit.md (claude-toolkit)
review-codebase.md (claude-toolkit)
smart-commit.md (claude-toolkit)
solid-analysis.md (claude-toolkit)
test-runner.md (user)
```

**Source Indicators:**
- **(claude-toolkit)**: Command from the Claude Toolkit repository
- **(team-alpha)**: Command from team-alpha source repository
- **(user)**: Command created by the user (no source field)

### Source-Specific Listing

Shows only commands from specified source:

```bash
$ claude-slash list --source claude-toolkit
add-command.md (claude-toolkit)
quick-commit.md (claude-toolkit)
review-codebase.md (claude-toolkit)
smart-commit.md (claude-toolkit)
solid-analysis.md (claude-toolkit)
```

### User Commands Only

Shows only user-created commands:

```bash
$ claude-slash list --source user
auth-helper.md (user)
test-runner.md (user)
```

### No Commands Installed

When no commands are installed:

```bash
$ claude-slash list
No slash commands installed
```

### Filtered Results Empty

When filter returns no results:

```bash
$ claude-slash list --source nonexistent-source
No commands found for source: nonexistent-source
```

## Command Identification

### Source-Based Detection

Commands are classified by their YAML frontmatter:
- **Source Commands**: Have `source: <source-name>` in YAML frontmatter
- **User Commands**: Have no `source:` field in YAML frontmatter

### Multiple Sources Support

The system supports multiple command sources:
- **claude-toolkit**: Official toolkit commands
- **Team Sources**: Team-specific command repositories
- **Custom Sources**: Any configured git repository
- **User Commands**: Locally created commands

## Detailed Output

### Detailed Information Mode

With `--format detailed`, shows additional information:

```bash
$ claude-slash list --format detailed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
File: add-command.md
Origin:  claude-toolkit
Path:    ~/.claude/commands/add-command.md
Size:    15KB
Modified: 2024-01-15 10:30:25
Description: Create a new Claude Code slash command
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
File: auth-helper.md
Origin:  user
Path:    ~/.claude/commands/auth-helper.md  
Size:    2KB
Modified: 2024-01-10 14:22:10
Description: Custom authentication helper command
```

### Source Management

Check what sources are configured:

```bash
$ claude-template-sources list
claude-toolkit    git@github.com:org/claude-toolkit.git (5 commands installed)
team-alpha        git@github.com:org/team-alpha.git      (2 commands installed)
user                                                      (3 commands defined)
```

## Common Use Cases

### Development Environment Audit

Check what commands are available:

```bash
# See all installed commands
claude-slash list
add-command.md (claude-toolkit)
review-codebase.md (claude-toolkit)
smart-commit.md (claude-toolkit)
my-helper.md (user)

# Check if specific commands are installed
claude-slash list --source claude-toolkit | grep -q "smart-commit"
echo $? # 0 if found, 1 if not found
```

### Source Management

Manage commands by source:

```bash
# List configured sources
claude-template-sources list

# Check what's installed from each source
claude-slash list --source claude-toolkit
claude-slash list --source team-alpha
claude-slash list --source user

# List commands from multiple sources
claude-slash list --source claude-toolkit,team-alpha
```

### Team Synchronization

Verify team has consistent commands:

```bash
# Check toolkit command installation
claude-slash list --source claude-toolkit
# Expected output should match team standard

# Check all team sources
claude-slash list --source claude-toolkit,team-alpha,team-beta
```

### Command Discovery

Explore available functionality:

```bash
# See what's available with details
claude-slash list --format detailed

# Focus on specific source capabilities
claude-slash list --source claude-toolkit --format detailed
```

## Automation and Scripting

### Command Counting

```bash
# Count total commands
total_commands=$(claude-slash list | wc -l)

# Count commands by source
toolkit_count=$(claude-slash list --source claude-toolkit | wc -l)
user_count=$(claude-slash list --source user | wc -l)

echo "Total: $total_commands (Toolkit: $toolkit_count, User: $user_count)"
```

### Command Validation

```bash
# Check if all expected commands are installed
expected_commands=("add-command.md" "smart-commit.md" "review-codebase.md")
installed=$(claude-slash list --source claude-toolkit)

for cmd in "${expected_commands[@]}"; do
    if ! echo "$installed" | grep -q "$cmd"; then
        echo "Missing: $cmd"
    fi
done
```

### Source Verification

```bash
# Verify sources are configured and have commands
claude-template-sources list | while IFS=$'\t' read -r source url; do
    count=$(claude-slash list --source "$source" | wc -l)
    echo "$source: $count commands"
done
```

## Error Scenarios

### Commands Directory Missing

```bash
$ claude-slash list
[WARNING] Commands directory not found: ~/.claude/commands/
No slash commands installed
```

### Permission Issues

```bash
$ claude-slash list
[ERROR] Permission denied accessing ~/.claude/commands/
```
*Solution*: Check directory permissions with `ls -la ~/.claude/`

### Source Not Found

```bash
$ claude-slash list --source nonexistent-source
[ERROR] Source 'nonexistent-source' not found in configuration
Use 'claude-template-sources list' to see available sources
```

## Directory Structure Analysis

The list command analyzes this structure:

```
~/.claude/commands/
├── add-command.md          # claude-toolkit source
├── smart-commit.md         # claude-toolkit source
├── deploy.md              # team-alpha source
├── security-scan.md       # team-beta source
├── my-helper.md           # user command (no source)
└── project-setup.md       # user command (no source)

~/.config/claude-templates/
└── sources.csv            # Source configuration

~/.cache/claude-templates/
├── abc123.../             # Cached repositories
│   └── claude-toolkit/
└── def456.../
    └── team-alpha/
```

## Performance Notes

- **Fast Operation**: Simple directory listing and source filtering
- **No Network Access**: Works entirely offline using cached data
- **Minimal Resource Usage**: Lightweight file system operations
- **Source Caching**: Repository information cached for performance

## Integration with Claude Code

### Command Availability

Listed commands are available in Claude Code:

```bash
# Start Claude Code
claude

# Use any listed command (inside Claude Code)
/smart-commit "implement feature"
/add-command user my-helper --description "My custom helper"
/review-codebase security
```

### Command Validation

The listing process validates command syntax:
- **YAML Frontmatter**: Checks for proper frontmatter format
- **Source Fields**: Validates source field consistency
- **Markdown Structure**: Validates markdown syntax

## Related Commands

- [`install`](install.md) - Install slash commands from sources
- [`reinstall`](reinstall.md) - Reinstall commands from latest repositories
- [`uninstall`](uninstall.md) - Remove commands from specific sources

**Source Management (separate command):**
- `claude-template-sources add` - Add new command source repositories
- `claude-template-sources list` - List configured command sources
- `claude-template-sources remove` - Remove source configurations
