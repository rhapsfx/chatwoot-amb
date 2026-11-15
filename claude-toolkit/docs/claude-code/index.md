# claude-code.sh

The `claude-code.sh` script provides comprehensive management of Claude Code installations with version-aware architecture and multi-shell support.

## Overview

Claude Code installation management with enterprise-grade features:

- **Version Management**: Install, switch, and manage multiple Claude Code versions side-by-side
- **Command-First Interface**: Explicit commands required for all operations (no defaults)
- **Corporate Integration**: Apple internal npm registry and JWT token authentication
- **Shell Integration**: Automatic configuration for bash, zsh, and fish shells
- **XDG Compliance**: Follows standard directory specifications for clean organization

## Quick Start

```bash
# Install latest Claude Code version
./scripts/claude-code.sh install

# Install specific version
./scripts/claude-code.sh install --version 0.0.85

# List available versions
./scripts/claude-code.sh list

# Switch between installed versions
./scripts/claude-code.sh use --version 0.0.83
```

## Command Structure

All operations follow the command-first pattern:

```bash
./scripts/claude-code.sh <command> [options]
```

**Available Commands:**

| Command | Purpose | Documentation |
|---------|---------|---------------|
| `install` | Install Claude Code version | [Installation Guide](install.md) |
| `uninstall` | Remove Claude Code installation | [Uninstall Guide](uninstall.md) |
| `reinstall` | Clean reinstall with backup | [Reinstall Guide](reinstall.md) |
| `use` | Switch to installed version | [Version Switching](use.md) |
| `list` | Show available/installed versions | [Version Listing](list.md) |

## Key Features

### Version-Aware Architecture
Each Claude Code version gets its own isolated Node.js runtime and package installation, preventing conflicts between versions.

### XDG Directory Compliance
- `~/.local/share/claude/` - Main installation and version directories
- `~/.cache/claude/` - Cache and temporary files
- `~/.local/bin/claude` - User executable wrapper

### Safety & Reliability
- Automatic backups before destructive operations
- [Dry-run mode](dry-run.md) for safe operation preview
- Comprehensive error handling and recovery
- Smart version switching when removing current version

## Common Usage Patterns

```bash
# Version management workflow
./scripts/claude-code.sh list                    # See what's available
./scripts/claude-code.sh install --version 0.0.85 # Install specific version
./scripts/claude-code.sh use --version 0.0.85     # Switch to it
./scripts/claude-code.sh list --mode installed    # See what's installed

# Maintenance operations
./scripts/claude-code.sh reinstall               # Clean reinstall current version
./scripts/claude-code.sh uninstall --version 0.0.83 # Remove specific version
./scripts/claude-code.sh uninstall --all         # Remove everything
```

## Global Options

Available with all commands:
- `--dry-run` - Preview operations without making changes
- `--debug` - Enable debug output (verbose logging)
- `--porcelain` - Machine-readable output format
- `--help, -h` - Show detailed help information

## Authentication

The script supports JWT token authentication for Apple's corporate npm registry:

```bash
# Set JWT token for non-interactive authentication
export NPM_JWT_TOKEN="your_jwt_token_here"
./scripts/claude-code.sh install
```

## Quick Troubleshooting

**Command not found after installation:**
- Restart terminal: `exec $SHELL -l`
- Check installation: `./scripts/claude-code.sh list --mode installed`

**Installation failures:**
- Try dry-run first: `./scripts/claude-code.sh install --dry-run`
- Check network/VPN connectivity to Apple internal services
- Verify JWT token if using corporate registry

## Related Documentation

- **[Installation Process](install.md)** - Complete installation guide with options
- **[Version Management](use.md)** - Switching between installed versions
- **[Listing Versions](list.md)** - Viewing available and installed versions
- **[Reinstall Process](reinstall.md)** - Clean reinstallation with backup/restore
- **[Uninstall Process](uninstall.md)** - Safe removal with version-aware cleanup
- **[Dry Run Mode](dry-run.md)** - Testing operations safely before execution
- **[Argument Processing Architecture](argument-processing.md)** - Technical details of the command-line argument processing system
- **[Troubleshooting Guide](troubleshooting.md)** - Common issues and solutions
