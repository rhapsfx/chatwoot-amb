# Install Command

Install Claude Code slash commands from template source repositories to enable enhanced development workflows.

## Overview

The `install` command downloads and installs slash commands from configured template source repositories. The toolkit supports multiple source repositories, allowing teams to share and distribute custom command sets through a centralized template source management system.

## Basic Usage

```bash
# Install from all configured sources (default)
claude-slash install

# Install from specific source
claude-slash install --source claude-toolkit

# Install from multiple sources
claude-slash install --source team-alpha,team-beta

# Install with debug output
claude-slash install --debug

# Preview install without changes
claude-slash install --dry-run
```

## Command Syntax

```bash
claude-slash install [options]
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

### 2. Commands Directory Setup

Creates and configures the Claude Code commands directory:
- **Directory Creation**: Creates `~/.claude/commands/` if it doesn't exist
- **Permission Setup**: Ensures proper read/write permissions
- **User Preservation**: Identifies existing user commands for preservation

### 3. Repository Operations

Retrieves latest slash commands from template source repositories:
- **Repository Clone/Update**: Downloads or updates cached repositories from configured sources
- **Command Extraction**: Extracts commands from `slash-commands/` directory in each repository
- **Source Validation**: Verifies command files have proper `source:` field in YAML frontmatter

### 4. Command Installation

Installs commands from sources while preserving user commands:
- **Intelligent Installation**: Only installs commands that are new or different from existing ones
- **User Preservation**: Maintains existing user-created commands (those without `source:` field or with `source: user`)
- **Conflict Resolution**: Handles naming conflicts between source and user commands
- **Metadata Tracking**: Records source information for management purposes

### 5. Installation Verification

Validates successful installation:
- **File Integrity**: Verifies installed command files have proper structure
- **Source Consistency**: Checks that command files have correct `source:` field values
- **Checksum Validation**: Compares checksums to detect changes and avoid redundant operations

## Template Sources

Commands are installed from configured template source repositories. The system supports multiple sources:

### Default Sources

| Source | Description |
|--------|-------------|
| `claude-toolkit` | Auto-configured toolkit repository containing standard commands |
| `user` | Virtual source representing user-created commands (cannot be installed/uninstalled) |

### Source Management

Use `claude-template-sources` to manage additional sources:
```bash
# List configured sources
claude-template-sources list

# Add a new source
claude-template-sources add team-alpha git@github.com:myorg/alpha-commands.git

# Install from the new source
claude-slash install --source team-alpha
```

## Installation Examples

### Install from All Sources
```bash
# Default behavior - installs from all configured sources
claude-slash install

# Explicit specification
claude-slash install --source all
```

### Install from Specific Sources
```bash
# Install from single source
claude-slash install --source claude-toolkit

# Install from multiple sources
claude-slash install --source claude-toolkit,team-alpha
```

### Preview Installation
```bash
# See what would be installed without making changes
claude-slash install --dry-run

# See detailed debug information
claude-slash install --debug --dry-run
```

## Directory Structure

The installation creates the following structure:

```
~/.claude/commands/
├── command1.md                # Source command (e.g., source: claude-toolkit)
├── command2.md                # Source command (e.g., source: team-alpha)  
├── user-command.md             # User command (source: user or no source field)
└── [other-files.md]            # Mixed source and user commands
```

## Installation Behavior

### Fresh Installation

When no slash commands exist:
```bash
$ claude-slash install
Installing files from source(s): all
✅ Successfully installed 5 file(s)

Note: Restart Claude Code to refresh available commands
```

### Existing Installation (Idempotent)

When commands are already up-to-date:
```bash
$ claude-slash install
Installing files from source(s): all
✅ All files already installed
```

### Updates Available

When source repositories have newer versions:
```bash
$ claude-slash install
Installing files from source(s): all
✅ Successfully installed 3 file(s)
⚠️  Skipped installing 'custom-command.md': destination is not identical (probably contains user changes)

Note: Restart Claude Code to refresh available commands
```

## User Command Preservation

### Automatic Detection

The installer automatically identifies and preserves user commands:
- **Source Field Detection**: Commands without `source:` field or with `source: user` are preserved
- **Checksum Protection**: Files that have been modified locally are protected from overwriting
- **Safe Operation**: Installation never removes or overwrites user-created commands

### Conflict Resolution

When conflicts occur between source and user commands with the same name:
- **File Renaming**: If necessary, conflicting files get renamed with source suffix (e.g., `command-sourcename.md`)
- **User Priority**: Existing user commands take precedence over source commands with the same name
- **Clear Messaging**: Installation reports any conflicts and resolutions taken

## Use Cases

### Initial Development Setup

Setting up a new development environment:
```bash
# Install commands from all configured sources
claude-slash install

# Verify installation
claude-slash list
```

### Installing from Specific Sources

Getting commands from particular team or project sources:
```bash
# Install from specific team source
claude-slash install --source team-alpha

# Install from multiple sources
claude-slash install --source claude-toolkit,team-beta
```

### Updating Commands

Getting latest command improvements:
```bash
# Update from all sources
claude-slash reinstall

# Update from specific source
claude-slash reinstall --source claude-toolkit
```

## Advanced Usage

### Debug Mode

Get detailed information during installation:
```bash
claude-slash install --debug
# [DEBUG] Expanding source list: all
# [DEBUG] Cloning/updating repository for source: claude-toolkit
# [DEBUG] Found 5 command files in claude-toolkit
# [DEBUG] Installing command: add-command.md
# [SUCCESS] Successfully installed 5 file(s)
```

### Dry Run Mode

Preview operations without making changes:
```bash
claude-slash install --dry-run
# [INFO] dryrun:install_templates(all, false)
# Would install 3 new commands from claude-toolkit
# Would skip 2 existing commands (already up-to-date)
```

### Automated Installation

Skip interactive prompts for scripting:
```bash
# Non-interactive installation
claude-slash install --yes
```

### Porcelain Mode

Get machine-readable output:
```bash
claude-slash install --porcelain
# claude-toolkit	/path/to/command1.md	success	
# claude-toolkit	/path/to/command2.md	success
# team-alpha	/path/to/command3.md	skip	destination is identical
```

## Error Scenarios and Troubleshooting

### Source Configuration Issues

**No Sources Configured**:
```bash
$ claude-slash install
❌ No sources configured
Use 'claude-template-sources add <name> <url>' to add template sources
```
*Solution*: Configure at least one template source using `claude-template-sources add`

**Source Not Found**:
```bash
$ claude-slash install --source nonexistent
❌ Source 'nonexistent' not found in configuration
```
*Solution*: Use `claude-template-sources list` to see available sources

### Repository Access Issues

**Authentication Failed**:
```bash
$ claude-slash install
❌ Error cloning repository git@github.com:org/commands.git
```
*Solutions*:
1. Configure SSH keys for repository access
2. Check VPN connection if required
3. Verify repository access permissions
4. Use `--debug` for detailed error information

### File System Issues

**Permission Denied**:
```bash
$ claude-slash install
❌ Cannot write to commands directory: ~/.claude/commands/
```
*Solutions*:
1. Check directory permissions: `ls -la ~/.claude/`
2. Create directory manually: `mkdir -p ~/.claude/commands`
3. Check disk space availability

### Installation Validation Failures

**Invalid Command Files**:
```bash
$ claude-slash install
⚠️  Failed to install 'invalid-command.md': Expected 'source: claude-toolkit' in YAML frontmatter
```
*Solutions*:
1. Report issue to template source maintainers
2. Check repository integrity
3. Try installing from a different source

## Command Usage After Installation

Once installed, commands are available in Claude Code:

```bash
# Start Claude Code in a project
cd /path/to/project
claude

# Use installed commands (examples depend on what's installed)
/add-command project auth-check --template security-audit  
/smart-commit "implement user authentication"
```

## Integration with Other Commands

The install command works with other toolkit operations:

```bash
# Complete workflow
claude-slash install             # Install commands from sources
claude-slash list               # Verify installation
claude-slash reinstall          # Update to latest
claude-slash uninstall --source team-alpha  # Remove specific source commands
```

## Related Commands

- [`list`](list.md) - View installed slash commands by source
- [`reinstall`](reinstall.md) - Reinstall commands from latest repository versions
- [`uninstall`](uninstall.md) - Remove source commands (user commands protected)
- **claude-template-sources commands:**
  - [`claude-template-sources add`](../claude-template-sources/add.md) - Add template source repositories
  - [`claude-template-sources list`](../claude-template-sources/list.md) - List configured sources
  - [`claude-template-sources remove`](../claude-template-sources/remove.md) - Remove source configuration
