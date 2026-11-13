# Remove Command

Remove template source repositories from configuration, cleaning up cached repositories and source references.

## Overview

The `remove` command cleanly removes template source configurations, deletes cached repository data, and provides options for preserving or removing installed commands from the source.

## Basic Usage

```bash
# Remove a source configuration
claude-template-sources remove <name>

# Examples
claude-template-sources remove team-alpha
claude-template-sources remove old-source
claude-template-sources remove deprecated-tools
```

## Command Syntax

```bash
claude-template-sources remove <name> [options]
```

### Parameters

| Parameter | Description | Required |
|-----------|-------------|----------|
| `<name>` | Source name to remove | Yes |

### Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Preview the remove operation without making changes |
| `--debug` | Enable debug output for troubleshooting |
| `--porcelain` | Machine-readable output format |

## What Gets Removed

When removing a source, the following cleanup occurs:

### 1. Source Configuration
- Removes the source entry from `~/.config/claude-templates/sources.csv`
- Updates the source list for future operations

### 2. Repository Cache
- Deletes cached repository data from `~/.cache/claude-templates/`
- Removes all locally cached files for the source

### 3. Commands Status
- **Commands remain installed** by default
- Use `claude-slash uninstall --source <name>` to remove installed commands

## Examples

### Basic Source Removal

```bash
# Remove team source configuration
claude-template-sources remove team-alpha

# Remove development tools source
claude-template-sources remove dev-tools

# Remove deprecated source
claude-template-sources remove old-commands
```

### Preview Before Removal

```bash
# Preview what will be removed
claude-template-sources remove team-alpha --dry-run

# Example output:
# DRY RUN: Would remove source 'team-alpha'
# Source configuration: ~/.config/claude-templates/sources.csv
# Repository cache: ~/.cache/claude-templates/abc123def456.../team-alpha/
# Installed commands: 5 commands would remain (use claude-slash to manage)
```

### Complete Source and Command Removal

```bash
# 1. Remove installed commands first
claude-slash uninstall --source team-alpha

# 2. Remove source configuration
claude-template-sources remove team-alpha

# 3. Verify removal
claude-template-sources list
claude-slash list --source team-alpha  # Should show no commands
```

## Validation Process

When removing a source, the following validation occurs:

### 1. Source Existence Check
- Verifies the source name exists in configuration
- Displays error if source not found

### 2. Dependency Analysis  
- Checks if source has installed commands
- Provides information about command cleanup

### 3. Cache Location Identification
- Identifies all cache directories for the source
- Calculates space that will be freed

## Output Examples

### Successful Removal

```bash
$ claude-template-sources remove team-alpha

Removing source configuration...
✅ Removed source 'team-alpha'
Repository cache cleaned up: ~/.cache/claude-templates/abc123def456.../team-alpha/
Note: 5 installed commands from this source remain. Use 'claude-slash uninstall --source team-alpha' to remove them.
```

### Source Not Found

```bash
$ claude-template-sources remove nonexistent-source
❌ Source 'nonexistent-source' not found
Use 'claude-template-sources list' to see configured sources
```

### Dry Run Output

```bash
$ claude-template-sources remove team-alpha --dry-run

DRY RUN: Would remove source 'team-alpha'
Configuration: git@github.com:myorg/alpha-commands.git
Cache directory: ~/.cache/claude-templates/abc123def456.../team-alpha/
Installed commands: 5 commands (deploy.md, build.md, test.md, release.md, monitor.md)
Disk space to free: 2.3 MB

Use 'claude-template-sources remove team-alpha' to proceed
```

## Post-Removal Workflow

After removing a source, consider these follow-up actions:

### 1. Verify Removal

```bash
# Check source was removed from configuration
claude-template-sources list

# Verify cache cleanup
ls ~/.cache/claude-templates/
```

### 2. Command Cleanup (Optional)

```bash
# List commands from removed source (may still be installed)
claude-slash list --source team-alpha

# Remove commands if desired
claude-slash uninstall --source team-alpha
```

### 3. Re-add Source Later (If Needed)

```bash
# Sources can be re-added anytime
claude-template-sources add team-alpha git@github.com:myorg/alpha-commands.git

# Commands can be reinstalled
claude-slash install --source team-alpha
```

## Command Preservation

**Important**: Removing a source configuration does NOT automatically remove installed commands.

### Why Commands Are Preserved
- **Safety**: Prevents accidental loss of useful commands
- **Flexibility**: Allows source management without affecting workflows
- **Explicit Control**: Requires intentional command removal

### Managing Commands After Source Removal

```bash
# Check which commands remain from removed source
claude-slash list --source removed-source-name

# Remove specific commands if desired
claude-slash uninstall --source removed-source-name

# Or remove individual commands
rm ~/.claude/commands/specific-command.md
```

## Error Handling

### Source Not Found
```bash
$ claude-template-sources remove invalid-name
❌ Source 'invalid-name' not found
Available sources: team-alpha, team-beta, dev-tools
```

### Concurrent Modification
```bash
$ claude-template-sources remove team-alpha
❌ Source configuration file is locked or being modified
Try again in a moment or check for other running operations
```

### Cache Cleanup Issues
```bash
$ claude-template-sources remove team-alpha
⚠️  Source 'team-alpha' removed but cache cleanup failed
Manual cleanup may be needed: ~/.cache/claude-templates/abc123def456.../team-alpha/
```

## Advanced Usage

### Batch Source Removal

```bash
# Remove multiple sources (bash loop)
for source in deprecated-alpha deprecated-beta old-tools; do
  claude-template-sources remove "$source"
done
```

### Scripted Removal with Validation

```bash
#!/bin/bash
# remove-source-safely.sh - Remove source with validation

source_name="$1"

# Check if source exists
if claude-template-sources list --porcelain | grep -q "^$source_name	"; then
  echo "Removing source: $source_name"
  
  # Show what will be removed
  claude-template-sources remove "$source_name" --dry-run
  
  # Confirm with user
  read -p "Proceed with removal? (y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Remove commands first
    claude-slash uninstall --source "$source_name" 2>/dev/null || true
    
    # Remove source configuration
    claude-template-sources remove "$source_name"
  else
    echo "Removal cancelled"
  fi
else
  echo "Source '$source_name' not found"
  claude-template-sources list
fi
```

### Cleanup Verification Script

```bash
#!/bin/bash
# verify-cleanup.sh - Verify source removal was complete

source_name="$1"

echo "Verifying removal of source: $source_name"

# Check configuration
if claude-template-sources list --porcelain | grep -q "^$source_name	"; then
  echo "❌ Source still in configuration"
else
  echo "✅ Source removed from configuration"
fi

# Check cache directories
cache_dirs=$(find ~/.cache/claude-templates -type d -name "$source_name" 2>/dev/null)
if [[ -n "$cache_dirs" ]]; then
  echo "⚠️  Cache directories still exist:"
  echo "$cache_dirs"
else
  echo "✅ Cache directories cleaned up"
fi

# Check installed commands
remaining_commands=$(claude-slash list --source "$source_name" 2>/dev/null | wc -l)
if [[ "$remaining_commands" -gt 0 ]]; then
  echo "ℹ️  $remaining_commands commands still installed from this source"
  echo "   Use 'claude-slash uninstall --source $source_name' to remove them"
else
  echo "✅ No commands remain from this source"
fi
```

## Configuration File Management

### Source Configuration Format

Sources are stored in `~/.config/claude-templates/sources.csv`:

```
# Claude Template Sources Configuration
# Format: source_name<TAB>git_url
# Lines starting with # are comments
team-alpha	git@github.com:myorg/alpha-commands.git
team-beta	git@github.com:myorg/beta-commands.git
```

### Manual Configuration Editing

```bash
# Backup configuration before manual editing
cp ~/.config/claude-templates/sources.csv ~/.config/claude-templates/sources.csv.bak

# Edit configuration file
# Remove the line for the source you want to delete

# Verify configuration is still valid
claude-template-sources list
```

## Integration with claude-slash.sh

Source removal integrates with command management:

### Source-Command Relationship

```bash
# After removing a source, commands may still reference it
claude-slash list --format detailed | grep "source-name"

# Commands retain their source information even after source removal
grep "source:" ~/.claude/commands/*.md | grep "removed-source-name"
```

### Command Cleanup Workflow

```bash
# Recommended workflow for complete source removal:

# 1. List commands from source
claude-slash list --source team-alpha

# 2. Remove commands from source (optional)  
claude-slash uninstall --source team-alpha

# 3. Remove source configuration
claude-template-sources remove team-alpha

# 4. Verify complete removal
claude-template-sources list
claude-slash list --source team-alpha
```

## Troubleshooting

### Common Issues

**Source removal appears to succeed but source still listed:**
```bash
# Check for file permission issues
ls -la ~/.config/claude-templates/
chmod 644 ~/.config/claude-templates/sources.csv

# Verify file format
cat ~/.config/claude-templates/sources.csv
```

**Cache directories not cleaned up:**
```bash
# Manual cache cleanup
find ~/.cache/claude-templates -name "*source-name*" -type d -exec rm -rf {} +

# Verify cleanup
ls ~/.cache/claude-templates/
```

**Commands still showing removed source:**
```bash
# This is expected - commands retain source information
# To see only active sources:
claude-template-sources list

# To remove orphaned commands:
claude-slash uninstall --source removed-source-name
```

## Security Considerations

### Safe Removal Practices
- Use `--dry-run` to preview removal operations
- Back up important source configurations before removal
- Verify cache cleanup to avoid disk space issues

### Data Preservation
- Command removal is separate from source removal
- Repository data is permanently deleted from cache
- Source URLs can be re-added but cache must be rebuilt

## Related Commands

- [`add`](add.md) - Add new template source repositories
- [`list`](list.md) - List all configured template sources  
- **claude-slash.sh commands:**
  - `claude-slash uninstall --source <name>` - Remove commands from source
  - `claude-slash list --source <name>` - List commands from source

## Advanced Examples

### Source Migration Workflow

```bash
# Migrating from old source to new source URL

# 1. Add new source with different name
claude-template-sources add team-alpha-new git@github.com:myorg/new-alpha-commands.git

# 2. Install commands from new source
claude-slash install --source team-alpha-new

# 3. Compare command availability
claude-slash list --source team-alpha
claude-slash list --source team-alpha-new

# 4. Remove old source when satisfied
claude-slash uninstall --source team-alpha
claude-template-sources remove team-alpha

# 5. Rename new source if desired
claude-template-sources remove team-alpha-new
claude-template-sources add team-alpha git@github.com:myorg/new-alpha-commands.git
claude-slash install --source team-alpha
```

### Organization Cleanup Script

```bash
#!/bin/bash
# cleanup-deprecated-sources.sh - Remove multiple deprecated sources

deprecated_sources=(
  "old-team-alpha"
  "legacy-tools"  
  "experimental-commands"
  "temp-source"
)

echo "Cleaning up deprecated template sources..."

for source in "${deprecated_sources[@]}"; do
  if claude-template-sources list --porcelain | grep -q "^$source	"; then
    echo "Removing source: $source"
    
    # Remove commands first (optional)
    claude-slash uninstall --source "$source" 2>/dev/null || true
    
    # Remove source configuration  
    claude-template-sources remove "$source"
  else
    echo "Source '$source' not found, skipping"
  fi
done

echo "Cleanup complete. Remaining sources:"
claude-template-sources list
```