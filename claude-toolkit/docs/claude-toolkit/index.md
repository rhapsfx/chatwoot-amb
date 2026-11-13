# claude-toolkit.sh

The `claude-toolkit.sh` script provides the core infrastructure management for the Claude Toolkit, handling repository management, shell integration, and system-wide toolkit operations.

## Overview

Claude Toolkit infrastructure management with enterprise-grade features:

- **Infrastructure Management**: Installs and maintains toolkit core components and shell integration
- **Repository Management**: Handles git repository operations, updates, and validation
- **Shell Integration**: Automatic configuration for bash, zsh, and fish shells with XDG compliance
- **Symlink Management**: Creates and manages command symlinks in user's PATH
- **Self-Update Capabilities**: Can update itself and the entire toolkit from remote repository
- **Atomic Operations**: Safe installation and removal with rollback capabilities

## Quick Start

```bash
# Install toolkit infrastructure
claude-toolkit install

# Update toolkit from remote repository  
claude-toolkit update

# Validate current installation
claude-toolkit validate

# Reinstall completely
claude-toolkit reinstall

# Remove toolkit infrastructure
claude-toolkit uninstall
```

## Commands

### Core Operations

- **[`install`](install.md)** - Install toolkit infrastructure and shell integration
- **[`update`](update.md)** - Update toolkit from remote repository
- **[`validate`](validate.md)** - Validate toolkit installation integrity
- **[`reinstall`](reinstall.md)** - Completely reinstall toolkit infrastructure
- **[`uninstall`](uninstall.md)** - Remove toolkit infrastructure and clean up

## Global Options

All commands support these global options:

- `--shell <shell>` - Target specific shell (bash, zsh, fish)
- `--https` - Use HTTPS git URLs instead of SSH (default: SSH)
- `--remote-repository <url>` - Override default git repository URL
- `--dry-run` - Preview operations without executing
- `--debug` - Enable debug output
- `--yes, -y, --force` - Skip confirmation prompts (auto-accept)
- `--help, -h` - Show help message

## Architecture

### Repository Structure

The toolkit manages a complete git repository installation:

```
~/.local/share/claude-toolkit/
├── scripts/
│   ├── claude-toolkit.sh    # This script (symlinked)
│   ├── claude-code.sh       # Claude Code management
│   ├── claude-slash.sh      # Slash commands management
│   └── library.sh           # Shared utilities
├── slash-commands/          # Toolkit slash commands
├── tests/                   # Test suite
└── .git/                   # Git repository
```

### Symlink Integration

Creates symlinks in `~/.local/bin/` for easy access:

```
~/.local/bin/
├── claude-toolkit -> ../share/claude-toolkit/scripts/claude-toolkit.sh
├── claude-code -> ../share/claude-toolkit/scripts/claude-code.sh
└── claude-slash -> ../share/claude-toolkit/scripts/claude-slash.sh
```

### Shell Integration

Automatically configures shell environments:

- **bash**: Updates `~/.bashrc` or `~/.bash_profile` (macOS)
- **zsh**: Updates `~/.zshrc`
- **fish**: Updates `~/.config/fish/config.fish`

Adds `~/.local/bin` to PATH and configures XDG environment variables.

## Installation Locations

- **Main Installation**: `~/.local/share/claude-toolkit/`
- **Executable Symlinks**: `~/.local/bin/`
- **Cache Directory**: `~/.cache/claude-toolkit/`
- **Shell Configuration**: Various shell RC files

## Dependencies

- **git** - Required for repository operations
- **bash** - Required shell (zsh and fish supported for configuration)
- **internet connection** - Required for installation and updates
- **SSH or HTTPS access** - To Apple's internal GitHub

## Security Model

- **User-space only**: No system-wide modifications or sudo required
- **XDG compliant**: Follows standard directory specifications
- **Atomic operations**: Safe installation with automatic rollback on failure
- **Repository validation**: Comprehensive integrity checks

## Error Handling

The script includes comprehensive error handling:

- **Pre-flight checks**: Validates environment before operations
- **Atomic operations**: Either fully succeed or cleanly fail
- **Rollback capabilities**: Automatic cleanup on installation failures
- **Detailed logging**: Comprehensive debug output for troubleshooting

## Examples

### Basic Operations

```bash
# Install with automatic shell detection
claude-toolkit install

# Install for specific shell only
claude-toolkit install --shell=zsh

# Install using HTTPS instead of SSH
claude-toolkit install --https

# Update from remote repository
claude-toolkit update

# Validate installation
claude-toolkit validate
```

### Advanced Operations

```bash
# Preview installation without making changes
claude-toolkit install --dry-run

# Install with debug output
claude-toolkit install --debug

# Force reinstallation without prompts
claude-toolkit reinstall --yes

# Uninstall with confirmation skip
claude-toolkit uninstall --force
```

## Integration

### With Other Toolkit Components

The toolkit script provides the foundation for other components:

```bash
# After toolkit installation, install other components
claude-toolkit install
exec $SHELL -l                    # Restart shell
claude-code install               # Requires toolkit
claude-slash install              # Requires toolkit
```

### Environment Integration

Integrates seamlessly with development environments:

- **CI/CD**: Supports automated installation with `--yes` flag
- **Team Setup**: Consistent installation across development teams
- **Shell Agnostic**: Works with bash, zsh, and fish shells

## Troubleshooting

For installation and usage issues, see:

- **[Troubleshooting Guide](troubleshooting.md)** - Common issues and solutions
- **[Argument Processing](argument-processing.md)** - Command-line argument details

## Related Documentation

- **[Installation Guide](../installation.md)** - Complete setup instructions
- **[Architecture](../architecture.md)** - System design overview
- **[Claude Code Management](../claude-code/index.md)** - Claude Code specific operations
- **[Slash Commands Management](../claude-slash/index.md)** - Slash commands operations
