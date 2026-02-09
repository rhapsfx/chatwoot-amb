# Dry Run Mode

Preview template source operations without making any changes to the system.

## Overview

Dry run mode allows you to safely preview the effects of template source operations before executing them. This is essential for understanding what changes will be made, validating configurations, and preventing unintended modifications.

## Availability

Dry run mode is available for all template source commands:

- `claude-template-sources add <name> <url> --dry-run`
- `claude-template-sources remove <name> --dry-run`  
- `claude-template-sources list --dry-run` (same as normal list)

## Basic Usage

```bash
# Preview adding a new source
claude-template-sources add team-alpha git@github.com:myorg/commands.git --dry-run

# Preview removing a source
claude-template-sources remove team-alpha --dry-run

# List operations (dry-run has no effect, same as normal list)
claude-template-sources list --dry-run
```

## Add Command Dry Run

### What It Shows

When using `--dry-run` with the add command, you'll see:

1. **Source Configuration**: What will be added to the configuration file
2. **Repository Validation**: Repository accessibility and structure checks
3. **Command Discovery**: Number and list of commands found
4. **Cache Location**: Where repository data will be stored
5. **Conflict Detection**: Any naming conflicts with existing sources

### Example Output

```bash
$ claude-template-sources add team-alpha git@github.com:myorg/alpha-commands.git --dry-run

DRY RUN: Would add source 'team-alpha'
Repository: git@github.com:myorg/alpha-commands.git

Validation Results:
✅ Repository is accessible
✅ Repository contains slash-commands/ directory
✅ Found 5 command files:
   - deploy.md
   - build.md
   - test.md
   - release.md
   - monitor.md
✅ All command files have valid YAML frontmatter
⚠️  2 commands have mismatched source field (expected 'team-alpha'):
   - deploy.md: source is 'legacy-team'
   - build.md: source is 'old-alpha'

Configuration Changes:
Would add to: ~/.config/claude-templates/sources.csv
Entry: team-alpha,git@github.com:myorg/alpha-commands.git

Cache Location:
Would cache to: ~/.cache/claude-templates/abc123def456.../team-alpha/

Use 'claude-template-sources add team-alpha git@github.com:myorg/alpha-commands.git' to proceed
```

### Validation Checks Performed

During dry run, the add command performs comprehensive validation:

#### 1. Source Name Validation
```bash
# Checks performed:
✅ Source name is unique (not already configured)
✅ Source name format is valid (alphanumeric, hyphens, underscores)
✅ Source name is not reserved ('user', 'all', 'claude-toolkit')
```

#### 2. Repository Validation  
```bash
# Checks performed:
✅ Repository URL is valid
✅ Repository is accessible with current credentials
✅ Repository is not already configured with different name
```

#### 3. Content Validation
```bash
# Checks performed:
✅ Repository contains slash-commands/ directory
✅ Directory contains at least one .md file
✅ Command files have valid YAML frontmatter
⚠️  Source field consistency warnings displayed
```

### Error Examples

**Source name conflict:**
```bash
$ claude-template-sources add team-alpha git@github.com:different/repo.git --dry-run

DRY RUN: Cannot add source 'team-alpha'
❌ Source name 'team-alpha' already exists
Current configuration: git@github.com:myorg/existing-repo.git
Use 'claude-template-sources list' to see all configured sources
```

**Repository inaccessible:**
```bash
$ claude-template-sources add team-beta git@github.com:private/repo.git --dry-run

DRY RUN: Cannot add source 'team-beta'  
❌ Repository is not accessible
Error: remote: Repository not found
Check your SSH keys or repository permissions
```

**Invalid repository structure:**
```bash
$ claude-template-sources add empty-repo git@github.com:myorg/empty.git --dry-run

DRY RUN: Cannot add source 'empty-repo'
❌ Repository does not contain slash-commands directory
Template source repositories must have a 'slash-commands/' directory with .md files
```

## Remove Command Dry Run

### What It Shows

When using `--dry-run` with the remove command, you'll see:

1. **Source Information**: Current source configuration details
2. **Cache Location**: What cache directories will be deleted
3. **Disk Space**: Amount of space that will be freed
4. **Command Status**: Information about installed commands from the source
5. **Cleanup Actions**: Summary of what will be removed

### Example Output

```bash
$ claude-template-sources remove team-alpha --dry-run

DRY RUN: Would remove source 'team-alpha'
Configuration: git@github.com:myorg/alpha-commands.git
Cache directory: ~/.cache/claude-templates/abc123def456.../team-alpha/
Installed commands: 5 commands (deploy.md, build.md, test.md, release.md, monitor.md)
Disk space to free: 2.3 MB

Configuration Changes:
Would remove from: ~/.config/claude-templates/sources.csv
Line to remove: team-alpha,git@github.com:myorg/alpha-commands.git

Cache Cleanup:
Would delete: ~/.cache/claude-templates/abc123def456.../team-alpha/
├── slash-commands/
│   ├── deploy.md
│   ├── build.md
│   ├── test.md
│   ├── release.md
│   └── monitor.md
└── .git/

Note: Installed commands will remain in ~/.claude/commands/
Use 'claude-slash uninstall --source team-alpha' to remove them

Use 'claude-template-sources remove team-alpha' to proceed
```

### Error Examples

**Source not found:**
```bash
$ claude-template-sources remove nonexistent --dry-run

DRY RUN: Cannot remove source 'nonexistent'
❌ Source 'nonexistent' not found in configuration
Available sources: team-alpha, team-beta, dev-tools
Use 'claude-template-sources list' to see all configured sources
```

## List Command Dry Run

The list command behaves identically with `--dry-run`:

```bash
$ claude-template-sources list --dry-run

# Output identical to: claude-template-sources list
Template Sources:
┌────────────────┬─────────────────────────────────────────────────┐
│ Name           │ Repository URL                                  │
├────────────────┼─────────────────────────────────────────────────┤
│ team-alpha     │ git@github.com:myorg/alpha-commands.git         │
│ team-beta      │ git@github.com:myorg/beta-commands.git          │
└────────────────┴─────────────────────────────────────────────────┘
```

## Integration with Debug Mode

Combine `--dry-run` with `--debug` for maximum visibility:

```bash
# Comprehensive preview with debug information
claude-template-sources add team-gamma git@github.com:myorg/gamma.git --dry-run --debug

# Example debug output:
DEBUG: Parsing arguments: add team-gamma git@github.com:myorg/gamma.git --dry-run --debug
DEBUG: Dry run mode enabled, no changes will be made
DEBUG: Source name validation: team-gamma
DEBUG: Checking source name uniqueness...
DEBUG: Loading existing sources from ~/.config/claude-templates/sources.csv
DEBUG: Source name 'team-gamma' is available
DEBUG: Repository URL validation: git@github.com:myorg/gamma.git
DEBUG: Testing repository accessibility...
DEBUG: git ls-remote git@github.com:myorg/gamma.git
DEBUG: Repository is accessible
DEBUG: Cloning to temporary directory for validation...
DEBUG: Temporary clone: /tmp/claude-templates-validate-abc123
DEBUG: Checking repository structure...
DEBUG: Found slash-commands/ directory
DEBUG: Scanning for command files...
DEBUG: Found 3 .md files in slash-commands/
DEBUG: Validating YAML frontmatter...
DEBUG: All files have valid frontmatter
DEBUG: Cleanup: removing temporary directory

DRY RUN: Would add source 'team-gamma'
[... rest of dry run output ...]
```

## Scripting with Dry Run

### Validation Scripts

```bash
#!/bin/bash
# validate-source-addition.sh - Validate source before adding

source_name="$1"
source_url="$2"

if [[ -z "$source_name" || -z "$source_url" ]]; then
  echo "Usage: $0 <source-name> <source-url>"
  exit 1
fi

echo "Validating source addition: $source_name"
echo "Repository: $source_url"
echo ""

# Run dry run and capture output
dry_run_output=$(claude-template-sources add "$source_name" "$source_url" --dry-run 2>&1)
exit_code=$?

if [[ $exit_code -eq 0 ]]; then
  echo "✅ Validation successful"
  echo ""
  echo "$dry_run_output"
  echo ""
  echo "Ready to add source. Run:"
  echo "claude-template-sources add '$source_name' '$source_url'"
else
  echo "❌ Validation failed"
  echo ""
  echo "$dry_run_output"
  exit 1
fi
```

### Pre-Removal Check

```bash
#!/bin/bash
# check-before-removal.sh - Check source impact before removal

source_name="$1"

if [[ -z "$source_name" ]]; then
  echo "Usage: $0 <source-name>"
  exit 1
fi

echo "Checking impact of removing source: $source_name"
echo ""

# Check if source exists
if ! claude-template-sources list --format simple | grep -q "^$source_name$"; then
  echo "❌ Source '$source_name' not found"
  exit 1
fi

# Show what would be removed
echo "=== Removal Preview ==="
claude-template-sources remove "$source_name" --dry-run

echo ""
echo "=== Installed Commands from This Source ==="
installed_commands=$(claude-slash list --source "$source_name" 2>/dev/null)
if [[ -n "$installed_commands" ]]; then
  echo "$installed_commands"
  echo ""
  echo "⚠️  These commands will remain installed after source removal"
  echo "   Use 'claude-slash uninstall --source $source_name' to remove them"
else
  echo "No commands installed from this source"
fi
```

### Batch Validation

```bash
#!/bin/bash
# validate-all-sources.sh - Validate all configured sources

echo "Validating all configured template sources..."
echo ""

sources=($(claude-template-sources list --format simple))

if [[ ${#sources[@]} -eq 0 ]]; then
  echo "No sources configured"
  exit 0
fi

for source in "${sources[@]}"; do
  echo "Checking source: $source"
  
  # Get source URL
  source_url=$(claude-template-sources list --porcelain | grep "^$source	" | cut -f2)
  
  if [[ -n "$source_url" ]]; then
    # Test repository access
    if git ls-remote "$source_url" >/dev/null 2>&1; then
      echo "  ✅ Repository accessible"
    else
      echo "  ❌ Repository not accessible"
    fi
    
    # Check cache status
    cache_info=$(claude-template-sources list --format detailed | grep -A10 "━━━ $source ━━━")
    if echo "$cache_info" | grep -q "✅ Active"; then
      echo "  ✅ Cache is current"
    elif echo "$cache_info" | grep -q "⚠️ Cache Missing"; then
      echo "  ⚠️  Cache needs update"
    else
      echo "  ❓ Cache status unknown"
    fi
  else
    echo "  ❌ Source URL not found"
  fi
  
  echo ""
done

echo "Validation complete"
```

## Best Practices

### Always Preview First

```bash
# Recommended workflow for adding sources
# 1. Preview the addition
claude-template-sources add new-source git@github.com:org/repo.git --dry-run

# 2. Review the output carefully
# 3. If everything looks good, proceed
claude-template-sources add new-source git@github.com:org/repo.git
```

### Combine with List for Context

```bash
# Check current state before making changes
claude-template-sources list

# Preview the change
claude-template-sources add new-source git@github.com:org/repo.git --dry-run

# Make the change  
claude-template-sources add new-source git@github.com:org/repo.git

# Verify the result
claude-template-sources list
```

### Use Debug Mode for Troubleshooting

```bash
# When dry run shows unexpected results, add debug mode
claude-template-sources add problematic-source git@github.com:org/repo.git --dry-run --debug
```

## Common Use Cases

### 1. Testing Repository Access

```bash
# Verify repository is accessible before adding
claude-template-sources add test-source git@new-server.com:org/repo.git --dry-run
```

### 2. Checking Command Conflicts

```bash
# Preview to see if new source has conflicting command names
claude-template-sources add team-new git@github.com:org/new-commands.git --dry-run
```

### 3. Estimating Storage Impact

```bash
# See how much cache space a source will use
claude-template-sources add large-source git@github.com:org/large-repo.git --dry-run
```

### 4. Validating Bulk Operations

```bash
# Test multiple source additions
sources=(
  "team-alpha git@github.com:org/alpha.git"
  "team-beta git@github.com:org/beta.git"  
  "team-gamma git@github.com:org/gamma.git"
)

for source_config in "${sources[@]}"; do
  echo "Testing: $source_config"
  claude-template-sources add $source_config --dry-run
  echo ""
done
```

## Troubleshooting Dry Run Issues

### Dry Run Shows Different Results Than Expected

**Problem**: Dry run passes but actual operation fails
```bash
# Common causes:
# 1. Repository state changed between dry run and execution
# 2. Network connectivity issues  
# 3. Permission changes

# Solution: Re-run dry run immediately before actual operation
claude-template-sources add source-name git@repo.url --dry-run && \
claude-template-sources add source-name git@repo.url
```

### Dry Run Takes Too Long

**Problem**: Repository validation is slow
```bash
# This can happen with large repositories or slow network connections
# The dry-run process includes:
# 1. git ls-remote (to check accessibility)
# 2. Temporary clone (to validate structure)
# 3. File scanning (to count commands)

# Solutions:
# - Use faster network connection
# - Repository may be very large
# - Check if repository server is responsive
```

### Debug Mode Shows Authentication Issues

```bash
# If dry run with debug shows authentication problems:
claude-template-sources add source git@repo.url --dry-run --debug

# Check SSH configuration:
ssh -T git@github.com
ssh -T git@github.pie.apple.com

# Check git credentials:
git config --list | grep credential
```

## Related Commands

- [`add`](add.md) - Add new template source repositories (with --dry-run examples)
- [`remove`](remove.md) - Remove source configurations (with --dry-run examples)  
- [`list`](list.md) - List configured sources
- [`troubleshooting`](troubleshooting.md) - Troubleshooting guide for common issues

## Advanced Examples

### Source Migration Preview

```bash
# Preview migrating from old to new repository URL
echo "Current source configuration:"
claude-template-sources list | grep old-source

echo -e "\nRemoving old source:"
claude-template-sources remove old-source --dry-run

echo -e "\nAdding new source:"
claude-template-sources add new-source git@new-location.com:org/repo.git --dry-run
```

### Comprehensive Pre-Change Validation

```bash
#!/bin/bash
# comprehensive-validation.sh - Full validation before source changes

operation="$1"  # add or remove
source_name="$2"
source_url="$3"

echo "Comprehensive validation for: $operation $source_name"
echo "========================================================"

# Current state
echo "1. Current source configuration:"
claude-template-sources list
echo ""

# Operation preview
echo "2. Operation preview:"
case "$operation" in
  "add")
    if [[ -z "$source_url" ]]; then
      echo "Error: URL required for add operation"
      exit 1
    fi
    claude-template-sources add "$source_name" "$source_url" --dry-run --debug
    ;;
  "remove")
    claude-template-sources remove "$source_name" --dry-run --debug
    ;;
  *)
    echo "Error: Operation must be 'add' or 'remove'"
    exit 1
    ;;
esac

echo ""
echo "3. Current command installation status:"
claude-slash list --source "$source_name" 2>/dev/null || echo "No commands from this source"

echo ""
echo "Validation complete. Review output before proceeding."
```