# List Command

View installed Claude Code subagents with source filtering options to distinguish between different subagent sources and user-created subagents.

## Overview

The `list` command displays all installed subagents in the `~/.claude/agents/` directory. It provides source-based filtering capabilities to show subagents from specific sources (claude-toolkit, team sources, user subagents, etc.) with their origins clearly identified.

## Basic Usage

```bash
# List all installed subagents from all sources
claude-agents list

# List subagents from specific source
claude-agents list --source claude-toolkit
claude-agents list --source user
claude-agents list --source team-alpha

# List subagents from multiple sources
claude-agents list --source user,claude-toolkit

# Show detailed information
claude-agents list --format detailed

# Preview list without changes
claude-agents list --dry-run
```

## Command Syntax

```bash
claude-agents list [options]
```

### Source Filtering

| Source | Description |
|--------|-------------|
| (none) | Shows all subagents from all sources with origin indicators (default) |
| `all` | Shows all subagents from all sources (explicit) |
| `user` | Shows only user-created subagents (no source field) |
| `claude-toolkit` | Shows only subagents from the claude-toolkit source |
| `<source-name>` | Shows subagents from specific configured source |
| `<name1,name2>` | Shows subagents from comma-separated list of sources |

### Options

| Option | Description |
|--------|-------------|
| `--source <name>` | Filter by source: all (default), user, claude-toolkit, or any configured source |
| `--source <name1,name2>` | Filter by comma-separated list of sources |
| `--format <format>` | Output format: compact (default) or detailed |
| `--dry-run` | Preview list operation without making system modifications |

## Output Format

### All Subagents (Default)

Shows all subagents with source indicators:

```bash
$ claude-agents list
architect.md (claude-toolkit)
custom-reviewer.md (user)
deployment-helper.md (team-alpha)
statusline-setup.md (claude-toolkit)
test-writer-debugger.md (claude-toolkit)
output-style-setup.md (claude-toolkit)
workflow-manager.md (user)
```

**Source Indicators:**
- **(claude-toolkit)**: Subagent from the Claude Toolkit repository
- **(team-alpha)**: Subagent from team-alpha source repository
- **(user)**: Subagent created by the user (no source field)

### Source-Specific Listing

Shows only subagents from specified source:

```bash
$ claude-agents list --source claude-toolkit
architect.md (claude-toolkit)
statusline-setup.md (claude-toolkit)
test-writer-debugger.md (claude-toolkit)
output-style-setup.md (claude-toolkit)
```

### User Subagents Only

Shows only user-created subagents:

```bash
$ claude-agents list --source user
custom-reviewer.md (user)
workflow-manager.md (user)
```

### No Subagents Installed

When no subagents are installed:

```bash
$ claude-agents list
No subagents installed
```

### Filtered Results Empty

When filter returns no results:

```bash
$ claude-agents list --source nonexistent-source
No subagents found for source: nonexistent-source
```

## Subagent Identification

### Source-Based Detection

Subagents are classified by their YAML frontmatter:
- **Source Subagents**: Have `source: <source-name>` in YAML frontmatter
- **User Subagents**: Have no `source:` field in YAML frontmatter

### Multiple Sources Support

The system supports multiple subagent sources:
- **claude-toolkit**: Official toolkit subagents
- **Team Sources**: Team-specific subagent repositories
- **Custom Sources**: Any configured git repository
- **User Subagents**: Locally created subagents

## Detailed Output

### Detailed Information Mode

With `--format detailed`, shows additional information:

```bash
$ claude-agents list --format detailed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
File: architect.md
Origin:  claude-toolkit
Path:    ~/.claude/agents/architect.md
Size:    25KB
Modified: 2024-01-15 10:30:25
Description: Expert software architect for comprehensive architectural analysis and design guidance
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
File: custom-reviewer.md
Origin:  user
Path:    ~/.claude/agents/custom-reviewer.md  
Size:    8KB
Modified: 2024-01-10 14:22:10
Description: Custom code review agent for team-specific practices
```

### Source Management

Check what sources are configured:

```bash
$ claude-template-sources list
claude-toolkit    git@github.com:org/claude-toolkit.git (4 subagents installed)
team-alpha        git@github.com:org/team-alpha.git      (1 subagent installed)
user                                                      (2 subagents defined)
```

## Common Use Cases

### Development Environment Audit

Check what subagents are available:

```bash
# See all installed subagents
claude-agents list
architect.md (claude-toolkit)
test-writer-debugger.md (claude-toolkit)
statusline-setup.md (claude-toolkit)
my-helper.md (user)

# Check if specific subagents are installed
claude-agents list --source claude-toolkit | grep -q "architect"
echo $? # 0 if found, 1 if not found
```

### Source Management

Manage subagents by source:

```bash
# List configured sources
claude-template-sources list

# Check what's installed from each source
claude-agents list --source claude-toolkit
claude-agents list --source team-alpha
claude-agents list --source user

# List subagents from multiple sources
claude-agents list --source claude-toolkit,team-alpha
```

### Team Synchronization

Verify team has consistent subagents:

```bash
# Check toolkit subagent installation
claude-agents list --source claude-toolkit
# Expected output should match team standard

# Check all team sources
claude-agents list --source claude-toolkit,team-alpha,team-beta
```

### Subagent Discovery

Explore available functionality:

```bash
# See what's available with details
claude-agents list --format detailed

# Focus on specific source capabilities
claude-agents list --source claude-toolkit --format detailed
```

## Automation and Scripting

### Subagent Counting

```bash
# Count total subagents
total_agents=$(claude-agents list | wc -l)

# Count subagents by source
toolkit_count=$(claude-agents list --source claude-toolkit | wc -l)
user_count=$(claude-agents list --source user | wc -l)

echo "Total: $total_agents (Toolkit: $toolkit_count, User: $user_count)"
```

### Subagent Validation

```bash
# Check if all expected subagents are installed
expected_agents=("architect.md" "test-writer-debugger.md" "statusline-setup.md")
installed=$(claude-agents list --source claude-toolkit)

for agent in "${expected_agents[@]}"; do
    if ! echo "$installed" | grep -q "$agent"; then
        echo "Missing: $agent"
    fi
done
```

### Source Verification

```bash
# Verify sources are configured and have subagents
claude-template-sources list | while IFS=$'\t' read -r source url; do
    count=$(claude-agents list --source "$source" | wc -l)
    echo "$source: $count subagents"
done
```

## Error Scenarios

### Subagents Directory Missing

```bash
$ claude-agents list
[WARNING] Subagents directory not found: ~/.claude/agents/
No subagents installed
```

### Permission Issues

```bash
$ claude-agents list
[ERROR] Permission denied accessing ~/.claude/agents/
```
*Solution*: Check directory permissions with `ls -la ~/.claude/`

### Source Not Found

```bash
$ claude-agents list --source nonexistent-source
[ERROR] Source 'nonexistent-source' not found in configuration
Use 'claude-template-sources list' to see available sources
```

## Directory Structure Analysis

The list command analyzes this structure:

```
~/.claude/agents/
├── architect.md              # claude-toolkit source
├── test-writer-debugger.md   # claude-toolkit source
├── deployment-helper.md      # team-alpha source
├── ci-agent.md              # team-beta source
├── my-reviewer.md           # user subagent (no source)
└── project-helper.md        # user subagent (no source)

~/.config/claude-templates/
└── sources.csv              # Source configuration

~/.cache/claude-templates/
├── abc123.../               # Cached repositories
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

### Subagent Availability

Listed subagents are available in Claude Code via the Task tool:

```bash
# Start Claude Code
claude

# Use any listed subagent through Task tool (inside Claude Code)
# Task: "Review architecture" subagent_type: architect
# Task: "Write tests for authentication" subagent_type: test-writer-debugger
# Task: "Configure status line" subagent_type: statusline-setup
```

### Subagent Validation

The listing process validates subagent syntax:
- **YAML Frontmatter**: Checks for proper frontmatter format
- **Source Fields**: Validates source field consistency
- **Markdown Structure**: Validates markdown syntax
- **Tools Definition**: Verifies tools field if present

## Related Commands

- [`install`](install.md) - Install subagents from sources
- [`reinstall`](reinstall.md) - Reinstall subagents from latest repositories
- [`uninstall`](uninstall.md) - Remove subagents from specific sources

**Source Management (separate command):**
- `claude-template-sources add` - Add new subagent source repositories
- `claude-template-sources list` - List configured subagent sources
- `claude-template-sources remove` - Remove source configurations