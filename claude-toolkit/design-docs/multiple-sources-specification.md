# Claude Slash Commands Multiple Sources Specification

## Overview

This specification defines the extension of `claude-slash.sh` to support multiple sources of slash commands, enabling teams and organizations to maintain their own command repositories while preserving the existing toolkit functionality.

## Motivation

The current implementation is limited to a single source (the claude-toolkit repository). Organizations need the ability to:
- Maintain team-specific slash commands in separate repositories
- Install commands from multiple sources simultaneously
- Manage source repositories independently
- Preserve user-created commands alongside sourced commands

## Design Principles

1. **Source Isolation**: Commands from different sources are managed independently
2. **User Protection**: User-created commands are always preserved
3. **Conflict Resolution**: Clear handling of naming conflicts between sources
4. **Unified Interface**: Single CLI tool manages all sources consistently

## Command Line Interface

### Core Commands

The existing command structure is preserved and extended:

```bash
./scripts/claude-slash.sh <command> [options]
```

#### Existing Commands (Modified)

- `install [--source <name>]` - Install commands from specified source(s)
- `reinstall [--source <name>]` - Reinstall commands from specified source(s)  
- `uninstall [--source <name>]` - Remove commands from specified source(s)
- `list [--source <name>]` - List commands from specified source(s)

#### New Source Management Commands

- `add-source <name> <git-url>` - Add a new command source repository
- `remove-source <name>` - Remove a command source repository
- `list-sources` - List all configured command sources

### Source Option Behavior

The `--source` option replaces the `--filter` option with the following semantics:

- `--source all` (default) - Operate on all configured sources
- `--source <name>` - Operate only on the specified source
- `--source user` - Special virtual source for user-created commands

### Source Types

#### Regular Sources
- **claude-toolkit**: Auto-configured source pointing to the same git URL as current repository's `origin`
- **Custom Sources**: User-added sources with arbitrary names and git URLs

#### Virtual Sources  
- **user**: Represents locally-created commands without source attribution
- **all**: Meta-source representing all configured sources plus user commands

## Source Management

### Adding Sources

```bash
# Add a team repository
./scripts/claude-slash.sh add-source team-alpha git@github.com:myorg/alpha-commands.git

# Add with HTTPS URL
./scripts/claude-slash.sh add-source team-beta https://github.com/myorg/beta-commands.git
```

**Behavior:**
- Validates git URL format
- Creates source configuration entry
- Does not install commands (requires separate `install` command)

**Validation:**
- Source name must be alphanumeric with hyphens allowed
- Reserved names: `user`, `all`, `claude-toolkit`
- Git URL must be valid format
- Source name must be unique

### Removing Sources

```bash
# Remove a source (fails if commands are installed from that source)
./scripts/claude-slash.sh remove-source team-alpha
```

**Behavior:**
- Removes source configuration
- Fails if any installed commands originate from that source
- Preserves cached repository data (for potential re-adding)
- Cannot remove auto-managed `claude-toolkit` source (fails with meaningful message)

### Listing Sources

```bash
# List all configured sources
./scripts/claude-slash.sh list-sources

# Sample output:
# claude-toolkit    git@github.com:AI-for-Devs-Community/claude-code-toolkit.git   (auto-managed)
# team-alpha        git@github.com:myorg/alpha-commands.git                         (5 commands)
# team-beta         https://github.com/myorg/beta-commands.git                      (3 commands) 
```

**Output Format:**
- Source name, git URL, status/command count
- Special indicators for auto-managed sources
- Command count from last successful operation

## File System Layout

### Configuration Storage

Source configuration is stored in: `$(get_xdg_config_home)/claude-slash/sources.csv`

**Format (CSV with TAB separator):**
```
# Claude Slash Commands Sources Configuration
# Format: source_name<TAB>git_url
# Lines starting with # are comments
claude-toolkit	git@github.com:AI-for-Devs-Community/claude-code-toolkit.git
team-alpha	git@github.com:myorg/alpha-commands.git
team-beta	https://github.com/myorg/beta-commands.git
```

**Reading/Writing in Bash:**
Configuration file is managed using standard bash tools (`grep`, `cut`, `printf`) for CSV parsing and manipulation, eliminating the need for external dependencies like `jq`.

### Repository Caching

Source repositories are cached in: `$(get_xdg_cache_home)/slash-commands/`

**Directory Structure:**
```
$(get_xdg_cache_home)/slash-commands/
├── a1b2c3d4e5f6.../              # repo_hash for claude-toolkit
│   └── claude-toolkit/
│       ├── .git/
│       └── slash-commands/
│           ├── add-command.md
│           ├── smart-commit.md
│           └── ...
├── f6e5d4c3b2a1.../              # repo_hash for team-alpha
│   └── team-alpha/
│       ├── .git/
│       └── slash-commands/
│           ├── deploy.md
│           └── test-runner.md
└── 9f8e7d6c5b4a.../              # repo_hash for team-beta
    └── team-beta/
        ├── .git/
        └── slash-commands/
            └── security-scan.md
```

**Repository Hash Calculation:**
- `repo_hash="$(printf '%s' "$repository_url" | compute_checksum)"`  
- Provides collision-resistant directory names
- Enables same repository under different source names

### Installation Directory

Commands are installed to: `~/.claude/commands/`

**Command Attribution:**
Commands from sources are identified by `source: <source_name>` in YAML frontmatter instead of `toolkit-command: true`.

**Example Command File:**
```yaml
---
description: Deploy application with safety checks
source: team-alpha
argument-hint: <environment> [--dry-run]
allowed-tools: Bash(git:*), Bash(kubectl:*)
---

# Deploy Command
Deploy application to specified environment with safety validations.
```

### Conflict Resolution

When multiple sources provide commands with the same name:

1. **Source Suffix Naming**: Conflicting commands use source name as suffix
2. **User Command Protection**: User commands always take precedence

**Naming Scheme:**
- User commands: `command-name.md` (unchanged)
- Source commands: `command-name.md` or `command-name-<source_name>.md` (if conflict)
- Example: `deploy.md` from team-alpha becomes `deploy-team-alpha.md` if `deploy.md` already exists

## Command Operations

### Install Command

```bash
# Install from all sources
./scripts/claude-slash.sh install

# Install from specific source  
./scripts/claude-slash.sh install --source team-alpha

# Install from multiple sources (comma-separated)
./scripts/claude-slash.sh install --source claude-toolkit,team-alpha
```

**Behavior:**
- Updates or clones cached repositories from git remotes
- Verifies that commands are marked with `source: <source_name>`
- Installs commands while preserving user commands
- Resolves conflicts using source name suffix scheme
- Reports installation summary by source

### List Command  

```bash
# List all commands with source indicators
./scripts/claude-slash.sh list

# Sample output:
# add-command.md (claude-toolkit)
# deploy.md (team-alpha)  
# my-helper.md (user)
# security-scan.md (team-beta)
# smart-commit.md (claude-toolkit)

# List from specific source
./scripts/claude-slash.sh list --source team-alpha
# deploy.md
# test-runner.md

# List user commands only  
./scripts/claude-slash.sh list --source user
# my-helper.md
```

**Output Format:**
- Default: All commands with source indicators
- Source-specific: Commands from that source without indicators
- Maintains existing `--format` option (compact/detailed)

### Reinstall Command

```bash
# Reinstall from all sources
./scripts/claude-slash.sh reinstall

# Reinstall from specific sources (comma-separated)
./scripts/claude-slash.sh reinstall --source claude-toolkit,team-alpha
```

**Behavior:**
- Forces git pull to get latest changes
- Reinstalls commands regardless of current state  
- Preserves user commands and handles conflicts

### Uninstall Command

```bash
# Remove commands from all sources
./scripts/claude-slash.sh uninstall

# Remove commands from specific sources (comma-separated)
./scripts/claude-slash.sh uninstall --source team-alpha,team-beta

# Error case: cannot uninstall user commands
./scripts/claude-slash.sh uninstall --source user
# [ERROR] Cannot uninstall user-created slash commands
# [INFO] Use manual file removal to delete user commands
```

**Behavior:**
- Removes commands attributed to specified source(s)
- Preserves user commands always
- Special error handling for virtual `user` source

### Command Discovery and Validation

#### Source Command Identification

Commands are identified as belonging to a source by:

1. **Source Marker**: `source: <source_name>` in YAML frontmatter
2. **Repository Path**: Located in `slash-commands/` directory of source repository
3. **Installation Metadata**: Tracked during installation process

#### Command Validation

Each command must:
- Be a valid Markdown file with `.md` extension
- Contain valid YAML frontmatter  
- Include `source: <source_name>` matching the source repository
- Be located in the `slash-commands/` directory of the source repository

## Error Handling

### Source Management Errors

- **Invalid Git URL**: Clear error message with validation details
- **Duplicate Source Name**: Prevent adding sources with existing names  
- **Missing Source Configuration**: Error when specified source not configured

### Installation Errors

- **Missing Source**: Abort operation if any specified source is not configured
- **Repository Access Failure**: Abort operation if any source repository is inaccessible
- **Command Validation Failure**: Abort operation if any command fails validation
- **Network/Authentication Issues**: Clear SSH/HTTPS authentication guidance

### User Experience

- **Log Messages**: Show operation progress through log messages
- **Clear Error Messages**: Actionable error messages with suggested fixes
- **Dry-Run Support**: Preview operations across all sources
- **Debug Logging**: Detailed operation logging when requested, facilitated by log_debug function in library.sh

## Implementation Notes

### Breaking Changes

This is a major refactoring that introduces breaking changes:

- **Command Attribution**: All source commands must use `source: <source_name>` instead of `toolkit-command: true`
- **CLI Interface**: `--filter` option removed in favor of `--source` option  
- **Configuration Format**: New CSV-based configuration system replaces JSON format and eliminates `type` and `added_date` metadata
- **Dependency Elimination**: Removes `jq` dependency by using standard bash tools for configuration management
- **Caching**: New repository caching structure requires clean installation

### Migration Requirements

Existing installations require:
1. **Command Update**: All toolkit commands need `source: claude-toolkit` frontmatter
2. **Configuration Migration**: JSON configuration must be migrated to CSV format
3. **Cache Rebuild**: Repository cache structure must be rebuilt

## Security Considerations

### Repository Validation

- **Git URL Validation**: Strict validation of git URLs before cloning
- **Certificate Verification**: Enforce SSL certificate validation for HTTPS URLs  
- **Path Traversal Protection**: Prevent malicious repository paths
- **Command Content Scanning**: Basic validation of command file contents

### Access Control

- **Repository Access**: Leverage existing git authentication mechanisms
- **Local File Permissions**: Maintain secure permissions on cached repositories
- **Configuration Protection**: Secure storage of source configuration

### Audit Trail

- **Operation Logging**: Log all source management operations
- **Command Attribution**: Clear tracking of command sources
- **Change Detection**: Detect and report unexpected command changes

## Performance Considerations

### Caching Strategy

- **Repository Caching**: Persistent git clones to minimize network overhead
- **Incremental Updates**: Use git pull for updates rather than full clones
- **Parallel Operations**: Concurrent operations across multiple sources where safe

### Resource Management

- **Disk Space**: Monitor and report cache directory disk usage
- **Network Usage**: Minimize redundant network operations
- **Memory Efficiency**: Efficient processing of large command sets

### Optimization

- **Command Discovery**: Efficient scanning of source repositories
- **Conflict Resolution**: Fast conflict detection and resolution
- **Status Reporting**: Quick status checks without full operations

## Testing Strategy

### Unit Testing

- Source configuration management
- Repository caching logic  
- Command discovery and validation
- Conflict resolution algorithms

### Integration Testing

- Multi-source installation workflows
- Source addition and removal
- Repository caching and updates
- Error handling scenarios

### End-to-End Testing

- Complete workflows across multiple sources
- Migration from existing installations
- Network failure scenarios
- Security and permission testing

## Future Extensions

### Planned Enhancements

- **Source Versions**: Pin sources to specific git tags/commits
- **Command Namespacing**: Support for namespaced command organization
- **Source Priorities**: Configurable priority ordering for conflict resolution
- **Remote Source Discovery**: Discovery of available sources from registries

### Compatibility Considerations

- **API Stability**: Maintain stable CLI interface for scripting
- **Configuration Format**: Extensible configuration format for future features
