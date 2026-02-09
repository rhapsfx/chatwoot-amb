# List Command

Display configured template source repositories.

## Overview

The `list` command shows all configured template sources with their repository URLs. It provides a simple overview of available sources that can be used with `claude-slash` commands.

## Basic Usage

```bash
# List all configured sources
claude-template-sources list

# Machine-readable output
claude-template-sources list --porcelain
```

## Command Syntax

```bash
claude-template-sources list [options]
```

### Options

| Option | Description |
|--------|-------------|
| `--porcelain` | Machine-readable output format (tab-separated) |
| `--dry-run` | Preview the list operation (same as normal list) |
| `--debug` | Enable debug output for troubleshooting |

## Output Formats

### Default Format

```bash
$ claude-template-sources list

Configured sources:

claude-toolkit    git@github.pie.apple.com:AI-for-Devs-Community/claude-toolkit.git
team-alpha        git@github.com:myorg/alpha-commands.git
team-beta         git@github.com:myorg/beta-commands.git
dev-tools         git@internal.company.com:dev/claude-tools.git
user              (user-defined templates)
```

### Porcelain Format (Machine-Readable)

```bash
$ claude-template-sources list --porcelain

claude-toolkit	git@github.pie.apple.com:AI-for-Devs-Community/claude-toolkit.git
team-alpha	git@github.com:myorg/alpha-commands.git
team-beta	git@github.com:myorg/beta-commands.git
dev-tools	git@internal.company.com:dev/claude-tools.git
```

## Special Sources

The list always shows these special sources:

| Source | Description |
|--------|-------------|
| `user` | Virtual source representing user-created commands (always shown) |
| `claude-toolkit` | Auto-configured if not explicitly added |

## Examples

### Basic Source Management

```bash
# Quick source overview
claude-template-sources list

# Get machine-readable data for scripting
claude-template-sources list --porcelain > sources-backup.csv
```

### Integration with Other Commands

```bash
# List sources, then install from specific one
claude-template-sources list
claude-slash install --source team-alpha

# Check sources, then add new one
claude-template-sources list
claude-template-sources add new-team git@github.com:myorg/new-commands.git

# Verify source after adding
claude-template-sources add team-gamma git@github.com:myorg/gamma.git
claude-template-sources list
```

## Empty Configuration

When no sources are configured:

```bash
$ claude-template-sources list

No sources configured
Add sources with: claude-template-sources add <name> <git-url>

user              (user-defined templates)
```

## Scripting and Automation

### Bash Scripting Examples

```bash
# Get all source names into an array (excluding user)
readarray -t sources < <(claude-template-sources list --porcelain | cut -f1)

# Process each source
for source in "${sources[@]}"; do
  echo "Processing source: $source"
  claude-slash reinstall --source "$source"
done
```

### Configuration File Processing

```bash
# Process porcelain output (tab-separated)
claude-template-sources list --porcelain | while IFS=$'\t' read -r name url; do
  echo "Source: $name -> $url"
  
  # Test repository access
  if git ls-remote "$url" >/dev/null 2>&1; then
    echo "  ✅ Repository accessible"
  else  
    echo "  ❌ Repository not accessible"
  fi
done
```

### Configuration Backup

```bash
# Backup source configuration (tab-separated format)
backup_file="sources-backup-$(date +%Y%m%d-%H%M%S).txt"
claude-template-sources list --porcelain > "$backup_file"
echo "Source configuration backed up to: $backup_file"

# Restore from backup (copy to configuration file)
cp "$backup_file" ~/.config/claude-templates/sources.csv
claude-template-sources list  # Verify restoration
```

## Configuration Storage

Sources are stored in `~/.config/claude-templates/sources.csv`:

```
# Claude Template Sources Configuration
# Format: source_name<TAB>git_url
# Lines starting with # are comments
claude-toolkit	git@github.pie.apple.com:AI-for-Devs-Community/claude-toolkit.git
team-alpha	git@github.com:myorg/alpha-commands.git
team-beta	git@github.com:myorg/beta-commands.git
```

## Troubleshooting

### Empty List

```bash
# Check if configuration file exists
ls -la ~/.config/claude-templates/sources.csv

# Create configuration directory if missing
mkdir -p ~/.config/claude-templates

# Add a source to get started
claude-template-sources add example-source git@github.com:org/commands.git
```

### Permission Issues

```bash
# Check file permissions
ls -la ~/.config/claude-templates/
chmod 644 ~/.config/claude-templates/sources.csv

# Check directory permissions
chmod 755 ~/.config/claude-templates/
```

## Related Commands

- [`add`](add.md) - Add new template source repositories
- [`remove`](remove.md) - Remove source configurations
- **claude-slash commands:**
  - `claude-slash list --source <name>` - List commands from specific source
  - `claude-slash install --source <name>` - Install commands from source