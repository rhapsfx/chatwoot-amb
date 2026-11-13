# Uninstall Command

Remove Claude Code versions with intelligent version switching and infrastructure cleanup.

## Overview

The `uninstall` command removes Claude Code installations with smart version management. It can remove specific versions, the current active version, or all versions completely. The system automatically handles version switching when removing the current active version and performs complete cleanup when no versions remain.

## Basic Usage

```bash
# Remove current active version
./scripts/claude-code.sh uninstall

# Remove specific version
./scripts/claude-code.sh uninstall --version 0.0.85

# Remove all versions and infrastructure
./scripts/claude-code.sh uninstall --all

# Preview uninstall without changes
./scripts/claude-code.sh uninstall --dry-run
```

## Command Syntax

```bash
./scripts/claude-code.sh uninstall [options]
```

### Core Options

| Option | Description |
|--------|-------------|
| `--version <version>` | Remove specific installed version |
| `--all` | Remove all versions and complete infrastructure |

### Global Options

| Option | Description |
|--------|-------------|
| `--verbose` | Show detailed uninstall progress and diagnostic information |
| `--dry-run` | Preview uninstall without making system modifications |
| `--porcelain` | Machine-readable output format |
| `--shell <shell>` | Clean configuration for specific shell only (bash, zsh, fish) |
| `--yes`, `-y`, `--force` | Skip confirmation prompts and auto-accept |
| `--help`, `-h` | Show command help information |

## Uninstall Modes

### 1. Current Version Removal (Default)

Removes the currently active version:
```bash
# Remove whatever version is currently active
claude-code.sh uninstall
```

**Behavior:**
- Identifies current active version automatically
- Removes version directory and all contents
- Switches to latest remaining version if others exist
- Cleans up infrastructure if no versions remain

### 2. Specific Version Removal

Removes a specific version by name:
```bash
# Remove specific version (may or may not be current)
claude-code.sh uninstall --version 0.0.85
```

**Behavior:**
- Validates version exists before removal
- Preserves current active version if removing non-active version
- Switches to latest remaining version if removing active version
- Maintains infrastructure for remaining versions

### 3. Complete Removal

Removes all versions and infrastructure:
```bash
# Nuclear option - removes everything
claude-code.sh uninstall --all
```

**Behavior:**
- Removes all version directories
- Deletes wrapper scripts and symlinks
- Cleans up registry tools and cache
- Removes shell configurations
- Returns system to pre-installation state

## Smart Version Switching Logic

### Removing Non-Active Version

When removing a version that isn't currently active:
```bash
# Current active: 0.0.87
claude --check-version
# 0.0.87

# Remove non-active version
claude-code.sh uninstall --version 0.0.85
# [SUCCESS] Removed version directory for 0.0.85
# [INFO] Removed non-current version, preserving existing infrastructure

# Active version unchanged
claude --check-version  
# 0.0.87
```

### Removing Active Version with Alternatives

When removing the current version but others remain:
```bash
# Current active: 0.0.85, others installed: 0.0.83, 0.0.87
claude-code.sh uninstall --version 0.0.85
# [INFO] Removed version was the current version, checking for remaining versions...
# [INFO] Switching to latest installed version: 0.0.87
# [SUCCESS] Switched default version from 0.0.85 to 0.0.87

# New active version
claude --check-version
# 0.0.87
```

### Removing Last Version

When removing the only remaining version:
```bash
# Only version installed: 0.0.85
claude-code.sh uninstall --version 0.0.85
# [INFO] No versions remaining, cleaning up Claude Code infrastructure...
# [SUCCESS] Claude Code infrastructure cleaned up completely

# Command no longer available
claude --version
# command not found: claude
```

## Infrastructure Cleanup

### Partial Cleanup (Versions Remain)

When versions still exist after removal:
- **Preserves**: Wrapper scripts, registry tools, cache, shell configurations
- **Updates**: Current version symlink if active version was removed
- **Maintains**: Full functionality for remaining versions

### Complete Cleanup (No Versions Remain)

When no versions remain after removal:
- **Removes**: `~/.local/bin/claude` wrapper script
- **Removes**: `~/.local/share/claude/current` symlink
- **Removes**: `~/.local/share/claude/registry-tools/` directory
- **Removes**: `~/.cache/claude/` cache directory
- **Removes**: Empty `~/.local/share/claude/versions/` directory
- **Removes**: Empty `~/.local/share/claude/` directory (if empty)
- **Cleans**: Shell configurations across all detected shells

## Use Cases

### Version Cleanup

Remove old versions to free disk space:
```bash
# Check what's installed
claude-code.sh list --mode installed
# 0.0.83 (installed)
# 0.0.85 (installed, current)
# 0.0.87 (installed)

# Remove older versions
claude-code.sh uninstall --version 0.0.83
claude-code.sh uninstall --version 0.0.87

# Keep only current
claude-code.sh list --mode installed  
# 0.0.85 (installed, current)
```

### Development Environment Reset

Complete removal for fresh start:
```bash
# Nuclear cleanup
claude-code.sh uninstall --all
# [SUCCESS] All Claude Code versions and infrastructure removed

# Verify complete removal
claude --version
# command not found: claude

# Fresh installation
claude-code.sh install
```

### Version Migration

Replace current version with different version:
```bash
# Current setup
claude --check-version
# 0.0.85

# Install new version
claude-code.sh install --version 0.0.87

# Remove old version  
claude-code.sh uninstall --version 0.0.85

# Verify migration
claude --check-version
# 0.0.87
```

### Targeted Cleanup

Remove specific problematic version:
```bash
# Identify problematic version
claude-code.sh list --mode installed
# 0.0.85 (installed)
# 0.0.86 (installed, current) <- corrupted
# 0.0.87 (installed)

# Remove problematic version (will switch to 0.0.87)
claude-code.sh uninstall --version 0.0.86
# [INFO] Switching to latest installed version: 0.0.87
```

## Directory Structure Impact

### Before Uninstall
```
~/.local/share/claude/
├── current -> versions/0.0.85
├── versions/
│   ├── 0.0.83/
│   ├── 0.0.85/  <- target for removal
│   └── 0.0.87/
└── registry-tools/

~/.local/bin/claude
~/.cache/claude/
```

### After Specific Version Uninstall
```
~/.local/share/claude/
├── current -> versions/0.0.87  <- updated
├── versions/
│   ├── 0.0.83/
│   └── 0.0.87/  <- 0.0.85 removed
└── registry-tools/  <- preserved

~/.local/bin/claude  <- preserved
~/.cache/claude/     <- preserved
```

### After Complete Uninstall (--all)
```
# All directories removed:
# ~/.local/share/claude/ (deleted)
# ~/.local/bin/claude (deleted)  
# ~/.cache/claude/ (deleted)
# Shell configurations cleaned
```

## Error Scenarios and Troubleshooting

### Version Not Found

```bash
$ claude-code.sh uninstall --version 0.0.90
[ERROR] Version 0.0.90 is not installed
```
*Solution*: Check available versions with `list --mode installed`

### No Current Version

```bash
$ claude-code.sh uninstall
[ERROR] No current version found to uninstall
```
*Solutions*:
1. Check if Claude Code is installed: `claude-code.sh list --mode installed`
2. Specify version explicitly: `claude-code.sh uninstall --version <version>`
3. Use `--all` flag to clean up any remaining infrastructure

### Permission Issues

```bash
$ claude-code.sh uninstall --all
[ERROR] Permission denied: Cannot remove ~/.local/share/claude/
```
*Solutions*:
1. Check file permissions: `ls -la ~/.local/share/claude/`
2. Ensure no running Claude processes: `ps aux | grep claude`
3. Remove manually if needed: `rm -rf ~/.local/share/claude/`

### Incomplete Cleanup

```bash
$ claude-code.sh uninstall --all
[SUCCESS] All Claude Code versions removed
$ claude --version
-bash: /Users/username/.local/bin/claude: No such file or directory
```
*Solutions*:
1. Restart terminal to refresh PATH
2. Check shell configuration files for remaining references
3. Manual cleanup: `hash -r` or `rehash` depending on shell

## Shell Configuration Cleanup

### Automatic Shell Detection

The uninstall process automatically detects and cleans configurations:
```bash
# Detects and cleans all available shells
claude-code.sh uninstall --all --verbose
# [VERBOSE] Cleaning configuration for detected shells: bash zsh fish
# [VERBOSE] Removed claude-code configuration from ~/.bash_profile
# [VERBOSE] Removed claude-code configuration from ~/.zshrc  
# [VERBOSE] Removed claude-code configuration from ~/.config/fish/config.fish
```

### Targeted Shell Cleanup

Clean specific shell configurations only:
```bash
# Clean only zsh configuration
claude-code.sh uninstall --all --shell zsh
# [VERBOSE] Cleaning configuration for specified shell: zsh
```

### XDG PATH Preservation

The cleanup intelligently preserves XDG PATH configuration:
```bash
# If other tools use XDG PATH, it's preserved
claude-code.sh uninstall --all --verbose
# [VERBOSE] Other tools detected, keeping XDG PATH configuration

# If no other tools detected, XDG PATH is also removed
# [VERBOSE] Removing XDG PATH configuration from ~/.bash_profile
```

## Advanced Usage

### Confirmation Bypass

Skip interactive confirmations:
```bash
# Automated uninstall for scripts
claude-code.sh uninstall --all --yes
```

### Verbose Operation

Get detailed information during uninstall:
```bash
# See exactly what's being removed
claude-code.sh uninstall --version 0.0.85 --verbose
# [VERBOSE] Removing version directory: ~/.local/share/claude/versions/0.0.85
# [VERBOSE] Updated current symlink to point to versions/0.0.87
# [VERBOSE] Created Claude Code wrapper script
```

### Shell-Specific Cleanup

Target specific shells during cleanup:
```bash
# Clean only specific shell configurations
claude-code.sh uninstall --all --shell bash
```

## Safety Features

- **Validation**: Confirms version exists before removal
- **Smart Switching**: Automatically maintains functionality when possible
- **Atomic Operations**: Version removal is atomic (succeeds or fails completely)
- **Shell Preservation**: Only removes Claude Code configurations, preserves other settings
- **Path Safety**: XDG PATH configuration preserved if other tools depend on it

## Performance Notes

- **Fast Operation**: Version removal is typically very fast (just directory deletion)
- **Network Independence**: No network access required for uninstall
- **Parallel Safe**: Can remove non-active versions while Claude Code is running
- **Cache Efficiency**: Shared cache and registry tools preserved when possible

## Integration with Other Commands

Uninstall works seamlessly with other toolkit operations:

```bash
# Maintenance workflow
claude-code.sh list --mode installed     # Check current state
claude-code.sh uninstall --version 0.0.83   # Remove old version
claude-code.sh install --version 0.0.88  # Install new version
claude-code.sh list --mode installed     # Verify final state

# Complete reset workflow
claude-code.sh uninstall --all    # Complete removal
claude-code.sh install            # Fresh installation
```

## Related Commands

- [`install`](install.md) - Install new Claude Code versions
- [`list`](list.md) - View available and installed versions
- [`reinstall`](reinstall.md) - Reinstall existing versions
- [`use`](use.md) - Switch between installed versions
- [`claudectl`](../claudectl/index.md) - Alternative command interface for version management
