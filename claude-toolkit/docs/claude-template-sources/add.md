# Add Command

Add a new template source repository containing Claude Code slash commands.

## Overview

The `add` command configures a new git repository as a template source, making its slash commands available for installation via `claude-slash.sh`.

## Basic Usage

```bash
# Add a source repository
claude-template-sources add <name> <git-url>

# Examples
claude-template-sources add team-alpha git@github.com:myorg/alpha-commands.git
claude-template-sources add team-beta https://github.com:myorg/beta-commands.git
claude-template-sources add custom-tools git@internal.company.com:tools/claude-commands.git
```

## Command Syntax

```bash
claude-template-sources add <name> <git-url> [options]
```

### Parameters

| Parameter | Description | Required |
|-----------|-------------|----------|
| `<name>` | Unique source identifier (alphanumeric, hyphens, underscores) | Yes |
| `<git-url>` | Git repository URL (SSH or HTTPS) | Yes |

### Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Preview the add operation without making changes |
| `--debug` | Enable debug output for troubleshooting |
| `--porcelain` | Machine-readable output format |

## Repository Requirements

### Repository Structure
The repository must contain a `slash-commands/` directory with `.md` files:

```
repository-root/
├── slash-commands/              # Required directory
│   ├── command1.md             # Command files
│   ├── command2.md
│   ├── subdirectory/           # Subdirectories allowed
│   │   └── nested-command.md
│   └── advanced-command.md
├── README.md                   # Optional documentation
└── other-files/               # Other files ignored
```

### Command File Format
Each command file must have valid YAML frontmatter:

```markdown
---
description: Brief command description
source: source-name            # Should match the source name
argument-hint: <arguments>     # Optional usage hint
allowed-tools: Read, Write     # Optional tool restrictions
---

# Command Name

Command instructions for Claude Code...

Arguments provided: $ARGUMENTS
```

## Examples

### Adding Team Sources

```bash
# Add team-specific command sources
claude-template-sources add team-alpha git@github.com:myorg/alpha-commands.git
claude-template-sources add team-beta git@github.com:myorg/beta-commands.git
claude-template-sources add team-gamma https://github.com:myorg/gamma-commands.git
```

### Adding Custom Sources

```bash
# Add custom development tools
claude-template-sources add dev-tools git@internal.company.com:dev/claude-tools.git

# Add project-specific commands
claude-template-sources add project-x git@github.com:company/project-x-commands.git
```

### Preview Before Adding

```bash
# Preview the add operation
claude-template-sources add team-alpha git@github.com:myorg/alpha-commands.git --dry-run

# Example output:
# DRY RUN: Would add source 'team-alpha'
# Repository: git@github.com:myorg/alpha-commands.git
# Found 5 command files in slash-commands/
# Configuration would be saved to: ~/.config/claude-templates/sources.csv
```

## Validation Process

When adding a source, the following validation occurs:

### 1. Source Name Validation
- Must be unique (not already configured)
- Alphanumeric characters, hyphens, and underscores only
- Cannot be reserved names (`user`, `all`, `claude-toolkit`)

### 2. Repository Validation
- Must be a valid git repository
- Repository must be accessible with current credentials
- Must not be already configured (different name, same URL)

### 3. Content Validation
- Repository must contain `slash-commands/` directory
- Directory must contain at least one `.md` file
- Command files must have valid YAML frontmatter

### 4. Source Field Consistency
- Command files should have `source:` field matching the source name
- Warnings displayed for mismatched source fields

## Output Examples

### Successful Addition

```bash
$ claude-template-sources add team-alpha git@github.com:myorg/alpha-commands.git

Adding source repository...
✅ Added source 'team-alpha': git@github.com:myorg/alpha-commands.git
Use 'claude-slash install --source team-alpha' to install commands from this source
```

### Validation Errors

```bash
# Duplicate source name
$ claude-template-sources add team-alpha git@github.com:different-repo.git
❌ Source name 'team-alpha' already exists
Use 'claude-template-sources list' to see configured sources

# Invalid repository
$ claude-template-sources add invalid-source /path/to/non-git-directory
❌ Repository is not a valid git repository
Ensure the path points to a git repository with slash commands

# Missing slash-commands directory
$ claude-template-sources add empty-repo git@github.com:empty/repo.git
❌ Repository does not contain slash-commands directory
Template source repositories must have a 'slash-commands/' directory with .md files
```

## Post-Addition Workflow

After adding a source, install commands from it:

```bash
# 1. Add the source
claude-template-sources add team-alpha git@github.com:myorg/alpha-commands.git

# 2. Verify source was added
claude-template-sources list

# 3. Install commands from the source
claude-slash install --source team-alpha

# 4. List installed commands
claude-slash list --source team-alpha
```

## Git Authentication

### SSH Authentication (Recommended)
```bash
# Ensure SSH key is configured
ssh-add ~/.ssh/id_ed25519

# Test SSH access
ssh -T git@github.com

# Add source with SSH URL
claude-template-sources add team-alpha git@github.com:myorg/commands.git
```

### HTTPS Authentication
```bash
# Set up git credentials for HTTPS
git config --global credential.helper store

# Add source with HTTPS URL
claude-template-sources add team-alpha https://github.com:myorg/commands.git
```

### Apple Internal GitHub
```bash
# For Apple's internal GitHub
claude-template-sources add team-alpha git@github.pie.apple.com:myorg/commands.git

# Or with HTTPS
claude-template-sources add team-alpha https://github.pie.apple.com/myorg/commands.git
```

## Configuration Storage

Sources are stored in `~/.config/claude-templates/sources.csv`:

```
# Claude Template Sources Configuration
# Format: source_name<TAB>git_url
# Lines starting with # are comments
team-alpha	git@github.com:myorg/alpha-commands.git
team-beta	git@github.com:myorg/beta-commands.git
dev-tools	git@internal.company.com:dev/claude-tools.git
```

Repository content is cached in `~/.cache/claude-templates/`:

```
~/.cache/claude-templates/
├── abc123def456.../           # Hash-based cache directory
│   └── team-alpha/           # Source name subdirectory
│       └── slash-commands/   # Cached repository content
└── 789ghi012jkl.../         # Another cached repository
    └── team-beta/
        └── slash-commands/
```

## Integration with claude-slash.sh

After adding sources, use `claude-slash.sh` to install commands:

```bash
# Install from specific source
claude-slash install --source team-alpha

# Install from multiple sources
claude-slash install --source team-alpha,team-beta

# Update commands from source
claude-slash reinstall --source team-alpha

# List commands by source
claude-slash list --source team-alpha
```

## Troubleshooting

### Common Issues

**Git clone fails:**
```bash
# Check git credentials
git config --list | grep credential

# Test repository access
git clone <repository-url> /tmp/test-clone

# Use debug mode for detailed error information
claude-template-sources add team-alpha <repository-url> --debug
```

**Repository validation fails:**
```bash
# Check repository structure
git clone <repository-url> /tmp/check-repo
ls -la /tmp/check-repo/slash-commands/

# Verify command file format
head -10 /tmp/check-repo/slash-commands/*.md
```

**Source name conflicts:**
```bash
# List existing sources
claude-template-sources list

# Remove existing source if needed
claude-template-sources remove conflicting-name

# Choose a different source name
claude-template-sources add team-alpha-v2 <repository-url>
```

## Security Considerations

### Repository Access
- Only add repositories you trust
- Use SSH keys for secure authentication
- Verify repository contents before adding

### Source Names
- Use descriptive, team-recognizable names
- Avoid names that could conflict with future features
- Follow consistent naming conventions across your organization

### Network Security
- Repository cloning respects git configuration (proxies, certificates)
- Uses standard git authentication mechanisms
- Compatible with VPN and corporate network setups

## Related Commands

- [`list`](list.md) - List all configured template sources
- [`remove`](remove.md) - Remove a source configuration
- **claude-slash.sh commands:**
  - `claude-slash install --source <name>` - Install commands from source
  - `claude-slash list --source <name>` - List commands from source
  - `claude-slash reinstall --source <name>` - Update commands from source

## Advanced Usage

### Batch Source Addition
```bash
# Add multiple sources
sources=(
  "team-alpha git@github.com:org/alpha-commands.git"
  "team-beta git@github.com:org/beta-commands.git"
  "dev-tools git@github.com:org/dev-tools.git"
)

for source_config in "${sources[@]}"; do
  claude-template-sources add $source_config
done
```

### Validation Script
```bash
#!/bin/bash
# validate-sources.sh - Validate all configured sources

claude-template-sources list --porcelain | while IFS=$'\t' read -r name url; do
  if [[ "$name" != "name" ]]; then  # Skip header
    echo "Validating source: $name"
    if git ls-remote "$url" >/dev/null 2>&1; then
      echo "✅ $name: Repository accessible"
    else
      echo "❌ $name: Repository not accessible"
    fi
  fi
done
```