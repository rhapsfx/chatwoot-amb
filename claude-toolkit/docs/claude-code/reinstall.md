# Reinstall Command

Reinstall existing Claude Code versions with clean removal and fresh installation while preserving version settings.

## Overview

The `reinstall` command performs a complete removal and clean installation of an existing Claude Code version. This operation is useful for fixing corrupted installations, updating Node.js versions, or resolving configuration issues while preserving the version's role as the current default if applicable.

## Basic Usage

```bash
# Reinstall current active version
./scripts/claude-code.sh reinstall

# Reinstall specific version
./scripts/claude-code.sh reinstall --version 0.0.85

# Reinstall with different Node.js version
./scripts/claude-code.sh reinstall --nodejs-version 22.18.0

# Preview reinstall without changes
./scripts/claude-code.sh reinstall --dry-run
```

## Command Syntax

```bash
./scripts/claude-code.sh reinstall [options]
```

### Core Options

| Option | Description |
|--------|-------------|
| `--version <version>` | Reinstall specific version (default: current active version) |
| `--nodejs-version <version>` | Use different Node.js version during reinstall |
| `--shell <shell>` | Configure specific shell only (bash, zsh, fish) |

### Global Options

| Option | Description |
|--------|-------------|
| `--verbose` | Show detailed reinstall progress and diagnostic information |
| `--dry-run` | Preview reinstall without making system modifications |
| `--porcelain` | Machine-readable output format |
| `--yes`, `-y`, `--force` | Skip confirmation prompts and auto-accept |
| `--help`, `-h` | Show command help information |

## Reinstall Process

### 1. Version Determination

The system determines which version to reinstall:

**Current Version (default)**:
```bash
# Reinstall the currently active version
claude-code.sh reinstall
```

**Specific Version**:
```bash
# Reinstall a specific installed version
claude-code.sh reinstall --version 0.0.85
```

### 2. Pre-Reinstall Validation

Before starting, the system validates:
- Target version is currently installed
- Installation directory structure exists
- Current version status (active/non-active) for restoration

### 3. Backup Phase (Future Enhancement)

Currently implemented as stubs for future functionality:
- Creates backup metadata before removal (Phase 2+ implementation)
- Preserves configuration state for restoration if needed
- Logs backup location for recovery scenarios

### 4. Clean Removal

Performs complete removal of the target version:
- **Version Directory**: Removes `~/.local/share/claude/versions/<version>/`
- **Node.js Runtime**: Deletes version-specific Node.js installation
- **Dependencies**: Removes all installed packages and dependencies
- **Configuration**: Cleans up version-specific `.npmrc` files

### 5. Smart Version Switching

If reinstalling the current active version:
- **Temporary Switching**: Automatically switches to latest remaining version during reinstall
- **Current Preservation**: Remembers that this version was active
- **Restoration**: Re-establishes as active version after successful reinstall

If reinstalling a non-active version:
- **Preservation**: Maintains existing active version unchanged
- **Isolation**: No impact on current version or wrapper functionality

### 6. Fresh Installation

Performs complete fresh installation:
- **Registry Tools**: Ensures registry tools are available
- **Directory Creation**: Recreates version-specific directory structure
- **Node.js Installation**: Downloads and installs Node.js (potentially different version)
- **npm Configuration**: Creates fresh `.npmrc` with corporate registry settings
- **Authentication**: Re-authenticates with corporate npm registry
- **Package Installation**: Installs Claude Code package from registry

### 7. Restoration and Verification

Completes the reinstall process:
- **Default Status**: Restores as active version if it was active before
- **Wrapper Update**: Updates version-aware wrapper script
- **Shell Integration**: Ensures shell configurations remain intact
- **Installation Validation**: Verifies successful reinstall

## Use Cases

### Fix Corrupted Installation

When Claude Code isn't working properly:
```bash
# Diagnose the issue
claude --check
# Error: Node.js binary missing

# Fix with clean reinstall
claude-code.sh reinstall --verbose
# [SUCCESS] Successfully reinstalled Claude Code version 0.0.85
```

### Update Node.js Version

Change the Node.js version for an existing Claude Code installation:
```bash
# Check current setup
claude-code.sh list --mode installed
# 0.0.85 (installed, current)

# Reinstall with newer Node.js
claude-code.sh reinstall --nodejs-version 22.18.0
# [INFO] Using specified Node.js version: 22.18.0
```

### Resolve Configuration Issues

Fix npm registry or authentication problems:
```bash
# Clear any authentication issues and start fresh
claude-code.sh reinstall
# [INFO] Starting reinstall of version 0.0.85
# [INFO] Performing fresh installation...
```

### Development Environment Reset

Reset development environment to known good state:
```bash
# List installed versions
claude-code.sh list --mode installed

# Reinstall multiple versions cleanly
claude-code.sh reinstall --version 0.0.83
claude-code.sh reinstall --version 0.0.85
claude-code.sh reinstall --version 0.0.87
```

## Advanced Usage

### Reinstall with Specific Node.js Version

Change Node.js runtime during reinstall:
```bash
# Current installation uses Node.js 22.17.1
claude --check-version
# 0.0.85

# Reinstall with newer Node.js
claude-code.sh reinstall --nodejs-version 22.18.0 --verbose
# [VERBOSE] Using specified Node.js version: 22.18.0
# [VERBOSE] Target version 0.0.85 is currently the active version
```

### Non-Active Version Reinstall

Reinstall versions that aren't currently active:
```bash
# Check current active version
claude --check-version
# 0.0.87

# Reinstall older version (won't change active version)
claude-code.sh reinstall --version 0.0.85
# [VERBOSE] Target version 0.0.85 is not the current active version
# [VERBOSE] Not setting as default version since it was not current before reinstall
```

### Automated Reinstall

Skip confirmations for scripted environments:
```bash
# Non-interactive reinstall
claude-code.sh reinstall --yes --verbose
```

## Current vs Target Version Behavior

### Reinstalling Active Version

```bash
# Current active version: 0.0.85
claude --check-version
# 0.0.85

claude-code.sh reinstall
# [INFO] Target version 0.0.85 is currently the active version
# [INFO] Switching to latest installed version: 0.0.87
# [INFO] Performing fresh installation of version 0.0.85  
# [INFO] Restoring as default version since it was current before reinstall
# [SUCCESS] Successfully reinstalled Claude Code version 0.0.85

claude --check-version
# 0.0.85 (restored as active)
```

### Reinstalling Non-Active Version

```bash
# Current active version: 0.0.87
claude --check-version
# 0.0.87

claude-code.sh reinstall --version 0.0.85
# [INFO] Target version 0.0.85 is not the current active version
# [INFO] Performing fresh installation of version 0.0.85
# [INFO] Not setting as default version since it was not current before reinstall
# [SUCCESS] Successfully reinstalled Claude Code version 0.0.85

claude --check-version
# 0.0.87 (unchanged)
```

## Error Scenarios and Troubleshooting

### Version Not Installed

```bash
$ claude-code.sh reinstall --version 0.0.90
[ERROR] Version 0.0.90 is not installed
Available versions: 0.0.83 0.0.85 0.0.87
```
*Solution*: Install the version first or specify an existing version

### No Current Version

```bash
$ claude-code.sh reinstall
[ERROR] No current version installed to reinstall
[INFO] Use --version to specify a version to reinstall, or install first
```
*Solution*: Install Claude Code first or specify a version explicitly

### Registry Access Issues

```bash
$ claude-code.sh reinstall --verbose
[INFO] Performing fresh installation of version 0.0.85
[ERROR] Failed to install @apple/claude-code@0.0.85
```
*Solutions*:
1. Check `NPM_JWT_TOKEN` environment variable
2. Verify VPN connection for corporate registry access
3. Test registry access: `npm whoami --registry=https://npm.apple.com/`

### Node.js Download Failures

```bash
$ claude-code.sh reinstall --nodejs-version 22.18.0
[ERROR] Failed to download Node.js from nodejs.org
```
*Solutions*:
1. Check internet connectivity
2. Verify firewall allows access to Node.js distribution URLs
3. Try without specifying Node.js version to use default

### Validation Failures

```bash
$ claude-code.sh reinstall
[ERROR] Reinstall validation failed
[ERROR] Restoring from backup after failed reinstall
```
*Solutions*:
1. Check disk space availability
2. Verify directory permissions in `~/.local/share/claude/`
3. Try with `--verbose` flag for detailed error information
4. Manual cleanup: remove version directory and reinstall fresh

## Backup and Recovery (Future Enhancement)

Current implementation includes stubs for future backup/recovery functionality:

### Phase 2+ Features (Planned)

- **Automatic Backup**: Create snapshots before reinstall
- **Rollback Capability**: Restore previous state on reinstall failure  
- **Backup Management**: List and manage available backups
- **Selective Restoration**: Restore specific components (config, packages, etc.)

### Current Behavior

```bash
# Current stub implementations log but don't perform actual backup
claude-code.sh reinstall --verbose
# [VERBOSE] Creating backup before reinstall (stub implementation)
# [VERBOSE] Backup functionality will be implemented in Phase 2
```

## Performance Characteristics

- **Registry Tools**: Reuses existing registry tools (no re-download)
- **Node.js Caching**: Benefits from cached Node.js archives
- **npm Cache**: Leverages npm package cache for faster reinstalls
- **Network Optimization**: Minimizes redundant downloads
- **Parallel Operations**: Version isolation allows concurrent operations

## Integration with Other Commands

Reinstall works seamlessly with other toolkit operations:

```bash
# Complete maintenance workflow
claude-code.sh list --mode installed        # Check current state
claude-code.sh reinstall --verbose   # Clean reinstall
claude-code.sh list --mode installed        # Verify result
claude --check                               # Test functionality

# Version management workflow  
claude-code.sh reinstall --version 0.0.85
claudectl use 0.0.85                         # Switch if needed
claude-code.sh uninstall --version 0.0.83      # Clean up old versions
```

## Safety Features

- **Idempotent Operation**: Safe to run multiple times
- **Atomic Transactions**: Either succeeds completely or rolls back
- **Version Isolation**: No impact on other installed versions
- **Configuration Preservation**: Maintains shell integration and PATH setup
- **Error Recovery**: Attempts restoration on failure (future enhancement)

## Related Commands

- [`install`](install.md) - Install new Claude Code versions
- [`list`](list.md) - View available and installed versions
- [`uninstall`](uninstall.md) - Remove Claude Code versions
- [`use`](use.md) - Switch between installed versions
- [`claudectl`](../claudectl/index.md) - Alternative command interface for version management
