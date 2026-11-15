# Install Command

Install Claude Code subagents from template source repositories to enable specialized AI assistant workflows.

## Overview

The `install` command downloads and installs subagents from configured template source repositories. The toolkit supports multiple source repositories, allowing teams to share and distribute custom subagent sets through a centralized template source management system.

## Basic Usage

```bash
# Install from all configured sources (default)
claude-agents install

# Install from specific source
claude-agents install --source claude-toolkit

# Install from multiple sources
claude-agents install --source team-alpha,team-beta

# Install with debug output
claude-agents install --debug

# Preview install without changes
claude-agents install --dry-run
```

## Command Syntax

```bash
claude-agents install [options]
```

### Core Options

| Option | Description |
|--------|-------------|
| `--source <sources>` | Install from specific source(s). Can be source name, comma-separated list, or "all" (default: all) |
| `--debug` | Enable debug output (verbose logging) |
| `--dry-run` | Preview install operation without making system modifications |
| `--porcelain` | Machine-readable output format |
| `--yes`, `-y`, `--force` | Skip confirmation prompts and auto-accept |

## Installation Process

### 1. Template Source Management

The installer uses a template source management system:
- **Source Configuration**: Reads configured sources from `~/.config/claude-templates/sources.csv`
- **Auto-Configuration**: Automatically configures `claude-toolkit` source if not already present
- **Source Selection**: Expands source specifications (all, specific names, comma-separated lists)
- **Repository Caching**: Caches source repositories in `~/.cache/claude-templates/`

### 2. Subagents Directory Setup

Creates and configures the Claude Code subagents directory:
- **Directory Creation**: Creates `~/.claude/agents/` if it doesn't exist
- **Permission Setup**: Ensures proper read/write permissions
- **User Preservation**: Identifies existing user subagents for preservation

### 3. Repository Operations

Retrieves latest subagents from template source repositories:
- **Repository Clone/Update**: Downloads or updates cached repositories from configured sources
- **Subagent Extraction**: Extracts subagents from `agents/` directory in each repository
- **Source Validation**: Verifies subagent files have proper `source:` field in YAML frontmatter

### 4. Subagent Installation

Installs subagents from sources while preserving user subagents:
- **Intelligent Installation**: Only installs subagents that are new or different from existing ones
- **User Preservation**: Maintains existing user-created subagents (those without `source:` field or with `source: user`)
- **Conflict Resolution**: Handles naming conflicts between source and user subagents
- **Metadata Tracking**: Records source information for management purposes

### 5. Installation Verification

Validates successful installation:
- **File Integrity**: Verifies installed subagent files have proper structure
- **Source Consistency**: Checks that subagent files have correct `source:` field values
- **Checksum Validation**: Compares checksums to detect changes and avoid redundant operations

## Template Sources

Subagents are installed from configured template source repositories. The system supports multiple sources:

### Default Sources

| Source | Description |
|--------|-------------|
| `claude-toolkit` | Auto-configured toolkit repository containing standard subagents |
| `user` | Virtual source representing user-created subagents (cannot be installed/uninstalled) |

### Source Management

Use `claude-template-sources` to manage additional sources:
```bash
# List configured sources
claude-template-sources list

# Add a new source
claude-template-sources add team-alpha git@github.com:myorg/alpha-agents.git

# Install from the new source
claude-agents install --source team-alpha
```

## Installation Examples

### Install from All Sources
```bash
# Default behavior - installs from all configured sources
claude-agents install

# Explicit specification
claude-agents install --source all
```

### Install from Specific Sources
```bash
# Install from single source
claude-agents install --source claude-toolkit

# Install from multiple sources
claude-agents install --source claude-toolkit,team-alpha
```

### Preview Installation
```bash
# See what would be installed without making changes
claude-agents install --dry-run

# See detailed debug information
claude-agents install --debug --dry-run
```

## Directory Structure

The installation creates the following structure:

```
~/.claude/agents/
├── architect.md               # Source subagent (e.g., source: claude-toolkit)
├── test-writer-debugger.md    # Source subagent (e.g., source: claude-toolkit)  
├── user-helper.md             # User subagent (source: user or no source field)
└── [other-files.md]           # Mixed source and user subagents
```

## Installation Behavior

### Fresh Installation

When no subagents exist:
```bash
$ claude-agents install
Installing files from source(s): all
✅ Successfully installed 4 file(s)

Note: Restart Claude Code to refresh available subagents
```

### Existing Installation (Idempotent)

When subagents are already up-to-date:
```bash
$ claude-agents install
Installing files from source(s): all
✅ All files already installed
```

### Updates Available

When source repositories have newer versions:
```bash
$ claude-agents install
Installing files from source(s): all
✅ Successfully installed 2 file(s)
⚠️  Skipped installing 'custom-agent.md': destination is not identical (probably contains user changes)

Note: Restart Claude Code to refresh available subagents
```

## User Subagent Preservation

### Automatic Detection

The installer automatically identifies and preserves user subagents:
- **Source Field Detection**: Subagents without `source:` field or with `source: user` are preserved
- **Checksum Protection**: Files that have been modified locally are protected from overwriting
- **Safe Operation**: Installation never removes or overwrites user-created subagents

### Conflict Resolution

When conflicts occur between source and user subagents with the same name:
- **File Renaming**: If necessary, conflicting files get renamed with source suffix (e.g., `agent-sourcename.md`)
- **User Priority**: Existing user subagents take precedence over source subagents with the same name
- **Clear Messaging**: Installation reports any conflicts and resolutions taken

## Use Cases

### Initial Development Setup

Setting up a new development environment:
```bash
# Install subagents from all configured sources
claude-agents install

# Verify installation
claude-agents list
```

### Installing from Specific Sources

Getting subagents from particular team or project sources:
```bash
# Install from specific team source
claude-agents install --source team-alpha

# Install from multiple sources
claude-agents install --source claude-toolkit,team-beta
```

### Updating Subagents

Getting latest subagent improvements:
```bash
# Update from all sources
claude-agents reinstall

# Update from specific source
claude-agents reinstall --source claude-toolkit
```

## Advanced Usage

### Debug Mode

Get detailed information during installation:
```bash
claude-agents install --debug
# [DEBUG] Expanding source list: all
# [DEBUG] Cloning/updating repository for source: claude-toolkit
# [DEBUG] Found 4 subagent files in claude-toolkit
# [DEBUG] Installing subagent: architect.md
# [SUCCESS] Successfully installed 4 file(s)
```

### Dry Run Mode

Preview operations without making changes:
```bash
claude-agents install --dry-run
# [INFO] dryrun:install_templates(all, false)
# Would install 2 new subagents from claude-toolkit
# Would skip 2 existing subagents (already up-to-date)
```

### Automated Installation

Skip interactive prompts for scripting:
```bash
# Non-interactive installation
claude-agents install --yes
```

### Porcelain Mode

Get machine-readable output:
```bash
claude-agents install --porcelain
# claude-toolkit	/path/to/architect.md	success	
# claude-toolkit	/path/to/test-writer.md	success
# team-alpha	/path/to/custom-agent.md	skip	destination is identical
```

## Error Scenarios and Troubleshooting

### Source Configuration Issues

**No Sources Configured**:
```bash
$ claude-agents install
❌ No sources configured
Use 'claude-template-sources add <name> <url>' to add template sources
```
*Solution*: Configure at least one template source using `claude-template-sources add`

**Source Not Found**:
```bash
$ claude-agents install --source nonexistent
❌ Source 'nonexistent' not found in configuration
```
*Solution*: Use `claude-template-sources list` to see available sources

### Repository Access Issues

**Authentication Failed**:
```bash
$ claude-agents install
❌ Error cloning repository git@github.com:org/agents.git
```
*Solutions*:
1. Configure SSH keys for repository access
2. Check VPN connection if required
3. Verify repository access permissions
4. Use `--debug` for detailed error information

### File System Issues

**Permission Denied**:
```bash
$ claude-agents install
❌ Cannot write to agents directory: ~/.claude/agents/
```
*Solutions*:
1. Check directory permissions: `ls -la ~/.claude/`
2. Create directory manually: `mkdir -p ~/.claude/agents`
3. Check disk space availability

### Installation Validation Failures

**Invalid Subagent Files**:
```bash
$ claude-agents install
⚠️  Failed to install 'invalid-agent.md': Expected 'source: claude-toolkit' in YAML frontmatter
```
*Solutions*:
1. Report issue to template source maintainers
2. Check repository integrity
3. Try installing from a different source

## Subagent Usage After Installation

Once installed, subagents are available in Claude Code via the Task tool:

```bash
# Start Claude Code in a project
cd /path/to/project
claude

# Use installed subagents through Task tool (examples depend on what's installed)
# Task: "Review code architecture" (using architect subagent)
# Task: "Write comprehensive tests" (using test-writer-debugger subagent)
```

## Integration with Other Commands

The install command works with other toolkit operations:

```bash
# Complete workflow
claude-agents install             # Install subagents from sources
claude-agents list               # Verify installation
claude-agents reinstall          # Update to latest
claude-agents uninstall --source team-alpha  # Remove specific source subagents
```

## Related Commands

- [`list`](list.md) - View installed subagents by source
- [`reinstall`](reinstall.md) - Reinstall subagents from latest repository versions
- [`uninstall`](uninstall.md) - Remove source subagents (user subagents protected)
- **claude-template-sources commands:**
  - [`claude-template-sources add`](../claude-template-sources/add.md) - Add template source repositories
  - [`claude-template-sources list`](../claude-template-sources/list.md) - List configured sources
  - [`claude-template-sources remove`](../claude-template-sources/remove.md) - Remove source configuration