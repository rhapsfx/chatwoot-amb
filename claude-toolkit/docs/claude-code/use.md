# Use Command

Switch the current active version to a different installed Claude Code version without reinstallation.

## Overview

The `use` command provides fast version switching between already-installed Claude Code versions. This operation updates only the current version symlink to point to the specified version, making it the new active default without requiring any downloads, installations, or wrapper script modifications.

## Basic Usage

```bash
# Show current version information (no version specified)
./scripts/claude-code.sh use

# Switch to specific installed version
./scripts/claude-code.sh use --version 0.0.85

# Switch and verify the change
./scripts/claude-code.sh use --version 0.0.87
claude --check-version

# Preview version switch without changes
./scripts/claude-code.sh use --version 0.0.85 --dry-run
```

## Command Syntax

```bash
./scripts/claude-code.sh use [options]
```

### Core Options

| Option | Description |
|--------|-------------|
| `--version <version>` | Switch to specified installed version (omit to show current version info) |

### Global Options

| Option | Description |
|--------|-------------|
| `--verbose` | Show detailed switching progress and diagnostic information |
| `--dry-run` | Preview version switch without making system modifications |
| `--porcelain` | Machine-readable output format |
| `--yes`, `-y`, `--force` | Skip confirmation prompts and auto-accept |
| `--help`, `-h` | Show command help information |

**Note**: When no `--version` is specified, the command shows current version information (equivalent to `list --mode installed`).

## Version Switching Process

### 1. Installation Validation

The switch begins by validating the target version:
- **Version Exists**: Confirms specified version is installed locally
- **Installation Integrity**: Verifies version directory structure is complete
- **Executable Check**: Ensures Claude Code executable exists and is functional
- **Node.js Runtime**: Validates Node.js runtime is properly installed for the version

### 2. Current State Capture

Records current configuration before making changes:
- **Active Version**: Identifies currently active version
- **Symlink State**: Records current symlink target
- **Shell Configuration**: Captures current shell configuration status
- **Wrapper Script**: Backs up current wrapper script state

### 3. Symlink Update

Updates the current version pointer:
- **Current Symlink**: Updates `~/.local/share/claude/current` to point to target version
- **Atomic Operation**: Ensures symlink update is atomic (succeeds completely or fails)
- **Permission Verification**: Confirms proper permissions on new target
- **Access Validation**: Tests that new symlink is accessible and functional

### 4. Version Activation

Activates the new version through symlink management:
- **Current Symlink Update**: The version-agnostic wrapper script automatically follows the updated `current` symlink
- **No Script Changes**: Wrapper script remains unchanged as it dynamically resolves version at runtime
- **Instant Availability**: New version becomes immediately available without script regeneration
- **Path Preservation**: All existing PATH configurations remain valid

### 5. Configuration Verification

Validates the complete switch operation:
- **Version Check**: Confirms `claude --check-version` returns correct version
- **Functionality Test**: Verifies basic Claude Code functionality works
- **Shell Integration**: Tests wrapper script works from all configured shells
- **Rollback Preparation**: Prepares rollback information in case of issues

## Use Cases

### Development Workflow

Switch versions for testing and development:
```bash
# Check currently installed versions
claude-code.sh list --mode installed
# 0.0.83 (installed)
# 0.0.85 (installed, current)
# 0.0.87 (installed)

# Switch to older version for compatibility testing
claude-code.sh use --version 0.0.83
# [SUCCESS] Switched to version 0.0.83

# Verify the switch
claude --check-version
# 0.0.83

# Switch to latest for new feature testing
claude-code.sh use --version 0.0.87
claude --check-version  
# 0.0.87
```

### Bug Isolation

Quickly switch versions to isolate issues:
```bash
# Current version has issues
claude --version
# 0.0.86

# Switch to known good version
claude-code.sh use --version 0.0.85
# [SUCCESS] Switched to version 0.0.85

# Test if issue persists
claude --help  # Should work correctly

# Switch back to problematic version for debugging
claude-code.sh use --version 0.0.86
```

### Feature Comparison

Compare features across versions:
```bash
# Test feature in current version
claude --help | grep "new-feature"

# Switch to older version to see differences
claude-code.sh use --version 0.0.83
claude --help | grep "new-feature"  # Feature not present

# Switch back to newer version
claude-code.sh use --version 0.0.87
claude --help | grep "new-feature"  # Feature available
```

### Project-Specific Requirements

Switch to version required for specific project:
```bash
# Project requires specific Claude Code version
cd /path/to/legacy-project

# Switch to compatible version
claude-code.sh use --version 0.0.84
# [SUCCESS] Switched to version 0.0.84

# Work on project with compatible version
claude  # Runs with 0.0.84

# Switch back to latest after project work
claude-code.sh use --version 0.0.87
```

## Version Switching Examples

### Basic Version Switch

```bash
./scripts/claude-code.sh use --version 0.0.85
```

**Expected Output:**
```
[INFO] Switching to Claude Code version 0.0.85...
[INFO] Validating target version installation...
[SUCCESS] Version 0.0.85 is properly installed
[INFO] Updating current version symlink...
[SUCCESS] Updated current symlink: ~/.local/share/claude/current -> versions/0.0.85
[SUCCESS] Successfully switched to version 0.0.85
[INFO] Verify with: claude --check-version
```

### Verbose Version Switch

```bash
./scripts/claude-code.sh use --version 0.0.87 --verbose
```

**Expected Output:**
```
[INFO] Verbose mode enabled
[INFO] Switching to Claude Code version 0.0.87...
[VERBOSE] Previous version: 0.0.85
[VERBOSE] Target version: 0.0.87
[INFO] Validating target version installation...
[VERBOSE] Checking directory: ~/.local/share/claude/versions/0.0.87
[VERBOSE] Checking Node.js runtime: ~/.local/share/claude/versions/0.0.87/nodejs
[VERBOSE] Validating Claude Code executable
[SUCCESS] Version 0.0.87 is properly installed
[INFO] Updating current version symlink...
[VERBOSE] Removing old symlink: ~/.local/share/claude/current
[VERBOSE] Creating new symlink: current -> versions/0.0.87
[SUCCESS] Updated current symlink: ~/.local/share/claude/current -> versions/0.0.87
[VERBOSE] Testing new configuration...
[VERBOSE] claude --check-version returns: 0.0.87
[SUCCESS] Successfully switched to version 0.0.87
[INFO] Verify with: claude --check-version
```

### Dry-Run Preview

```bash
./scripts/claude-code.sh use --version 0.0.86 --dry-run
```

**Expected Output:**
```
[INFO] Verbose mode enabled
dryrun:use_claude_version(0.0.86)
```

## Error Scenarios and Troubleshooting

### Version Not Installed

```bash
$ claude-code.sh use --version 0.0.90
[ERROR] Version 0.0.90 is not installed
[INFO] Available installed versions:
[INFO]   0.0.83 (installed)
[INFO]   0.0.85 (installed)  
[INFO]   0.0.87 (installed, current)
[INFO] Install version first with: claude-code.sh install --version 0.0.90
```

**Solution:**
```bash
# Install the desired version first
claude-code.sh install --version 0.0.90

# Then switch to it
claude-code.sh use --version 0.0.90
```

### Corrupted Version Installation

```bash
$ claude-code.sh use --version 0.0.85
[ERROR] Version 0.0.85 installation appears corrupted
[INFO] Missing or invalid Claude Code executable
[INFO] Reinstall version with: claude-code.sh reinstall --version 0.0.85
```

**Solution:**
```bash
# Reinstall the corrupted version
claude-code.sh reinstall --version 0.0.85

# Then switch to it
claude-code.sh use --version 0.0.85
```

### Permission Issues

```bash
$ claude-code.sh use --version 0.0.87
[ERROR] Permission denied: Cannot update ~/.local/share/claude/current
```

**Solutions:**
1. **Fix Permissions:**
   ```bash
   chmod u+w ~/.local/share/claude/
   claude-code.sh use --version 0.0.87
   ```

2. **Check Directory Ownership:**
   ```bash
   ls -la ~/.local/share/claude/
   # Ensure you own the directory
   ```

### Symlink Creation Failed

```bash
$ claude-code.sh use --version 0.0.85
[ERROR] Failed to create current version symlink
```

**Solutions:**
1. **Manual Cleanup:**
   ```bash
   rm -f ~/.local/share/claude/current
   claude-code.sh use --version 0.0.85
   ```

2. **Verify Target Exists:**
   ```bash
   ls -la ~/.local/share/claude/versions/0.0.85
   ```

### Wrapper Script Issues

```bash
$ claude-code.sh use --version 0.0.87
[SUCCESS] Successfully switched to version 0.0.87
$ claude --version
-bash: /Users/username/.local/bin/claude: Permission denied
```

**Solutions:**
1. **Fix Script Permissions:**
   ```bash
   chmod +x ~/.local/bin/claude
   ```

2. **Verify Installation:**
   ```bash
   ls -la ~/.local/share/claude/versions/0.0.87/nodejs/bin/claude
   ```

## Advanced Usage

### Shell-Specific Configuration

Update configuration for specific shell only:
```bash
# Update zsh configuration only
claude-code.sh use --version 0.0.85 --shell zsh

# Update multiple shells separately
claude-code.sh use --version 0.0.85 --shell bash
claude-code.sh use --version 0.0.85 --shell fish
```

### Automated Version Switching

Skip confirmation prompts for scripting:
```bash
# Non-interactive version switch
claude-code.sh use --version 0.0.87 --yes
```

### Verification After Switch

Always verify the switch was successful:
```bash
# Switch version
claude-code.sh use --version 0.0.85

# Verify the switch
claude --check-version
# Should output: 0.0.85

# Test functionality
claude --help
# Should work without errors

# Check installation status
claude-code.sh list --mode installed
# Should show 0.0.85 as (installed, current)
```

## Integration with Version Management

### Complete Version Management Workflow

```bash
# Check current state
claude --check-version
claude-code.sh list --mode installed

# Install new version
claude-code.sh install --version 0.0.88

# Switch to new version
claude-code.sh use --version 0.0.88

# Test new version
claude --help

# Switch back if issues
claude-code.sh use --version 0.0.87

# Remove problematic version if needed
claude-code.sh uninstall --version 0.0.88
```

### Multiple Version Testing

```bash
# Install multiple versions for testing
claude-code.sh install --version 0.0.85
claude-code.sh install --version 0.0.86
claude-code.sh install --version 0.0.87

# Test each version systematically
for version in 0.0.85 0.0.86 0.0.87; do
    echo "Testing version $version..."
    claude-code.sh use --version $version
    claude --check-version
    # Run tests here
done

# Switch back to preferred version
claude-code.sh use --version 0.0.87
```

## Performance Notes

- **Fast Operation**: Version switching is very fast (symlink update + script regeneration)
- **No Downloads**: Uses existing installations, no network access required
- **Atomic Updates**: Symlink updates are atomic, minimizing risk of broken state
- **Instant Availability**: New version is immediately available after successful switch
- **Rollback Ready**: Previous version information maintained for easy rollback

## Directory Structure Impact

### Before Version Switch
```
~/.local/share/claude/
├── current -> versions/0.0.85  # Points to 0.0.85
├── versions/
│   ├── 0.0.83/
│   ├── 0.0.85/  # Currently active
│   └── 0.0.87/
└── registry-tools/

~/.local/bin/claude  # Configured for 0.0.85
```

### After Version Switch (use 0.0.87)
```
~/.local/share/claude/
├── current -> versions/0.0.87  # Updated to point to 0.0.87
├── versions/
│   ├── 0.0.83/
│   ├── 0.0.85/
│   └── 0.0.87/  # Now active
└── registry-tools/

~/.local/bin/claude  # Reconfigured for 0.0.87
```

## Safety Features

- **Pre-Validation**: Confirms target version exists and is functional before switching
- **Atomic Operations**: Symlink updates are atomic to prevent broken states
- **Rollback Information**: Maintains information needed for rollback if issues occur
- **Non-Destructive**: Never modifies or removes version installations
- **Verification**: Tests new configuration before declaring success

## Integration with Other Commands

The use command works seamlessly with other toolkit operations:

```bash
# Version management workflow
claude-code.sh list --mode installed     # Check available versions
claude-code.sh use --version 0.0.85         # Switch to specific version
claude --check-version                     # Verify switch
claude-code.sh reinstall           # Reinstall current version if needed
claude-code.sh uninstall --version 0.0.83   # Clean up old versions
```

## Related Commands

- [`install`](install.md) - Install new Claude Code versions for switching
- [`list`](list.md) - View available versions for switching
- [`reinstall`](reinstall.md) - Fix corrupted versions before switching
- [`uninstall`](uninstall.md) - Remove unused versions
- [`claudectl`](../claudectl/index.md) - Alternative command interface for version management
