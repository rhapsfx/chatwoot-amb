# Install Command

Install Claude Code versions with comprehensive version management and shell integration.

## Overview

The `install` command downloads and installs Claude Code versions with complete isolation using the XDG Base Directory specification. Each version is installed independently, allowing multiple versions to coexist while maintaining clean separation and easy switching.

## Basic Usage

```bash
# Install latest version
claude-code install

# Install specific version
claude-code install --version 0.0.85

# Install with debug output
claude-code install --debug

# Preview installation without changes
claude-code install --dry-run
```

## Command Syntax

```bash
claude-code install [options]
```

### Core Options

| Option | Description |
|--------|-------------|
| `--version <version>` | Install specific Claude Code version (default: latest) |
| `--nodejs-version <version>` | Use specific Node.js version (default: 22.17.1) |
| `--shell <shell>` | Configure specific shell only (bash, zsh, fish) |

### Global Options  

| Option | Description |
|--------|-------------|
| `--debug` | Enable debug output (verbose logging) |
| `--dry-run` | Preview installation without making system modifications |
| `--porcelain` | Machine-readable output format |
| `--help`, `-h` | Show command help information |

## Installation Process

### 1. Prerequisites Check

The installer verifies system requirements:
- **macOS 10.15+**: Checks operating system compatibility
- **Internet Connection**: Tests connectivity to download Node.js and packages
- **Required Commands**: Verifies `curl` and `tar` are available
- **Shell Support**: Validates specified shell if `--shell` is used

### 2. Registry Tools Setup

Automatically installs dedicated Node.js runtime for package management:
- Downloads Node.js to isolated registry tools directory (`~/.local/share/claude/registry-tools/`)
- Configures npm for package registry access
- Creates `.npmrc` in the registry tools directory (does not modify user's `~/.npmrc`)

### 3. Version Resolution

Determines which version to install:
```bash
# Latest version (queries npm registry)
claude-code install

# Specific version
claude-code install --version 0.0.85
```

### 4. Isolated Installation

Each version gets its own complete environment:
- **Version Directory**: `~/.local/share/claude/versions/<version>/`
- **Node.js Runtime**: Independent Node.js installation per version
- **Package Installation**: Claude Code installed via npm to version directory
- **Configuration**: Version-specific `.npmrc` created in version directory (preserves user's `~/.npmrc`)

### 5. Shell Integration

Automatically configures detected shells:
- **bash**: Updates `~/.bashrc` or `~/.bash_profile` (macOS)  
- **zsh**: Updates `~/.zshrc`
- **fish**: Updates `~/.config/fish/config.fish`
- **XDG PATH**: Adds `~/.local/bin` to PATH for all shells

### 6. Wrapper Script Creation

Creates version-aware wrapper at `~/.local/bin/claude`:
- Automatically resolves current active version
- Validates installation integrity before execution
- Provides helpful error messages for common issues
- Supports `--check` and `--check-version` diagnostic options

## Version Management

### Default Version Setting

The most recently installed version automatically becomes the default:
```bash
# Install and set as default
claude-code install --version 0.0.86

# Verify default version
claude --check-version
```

### Multiple Versions

Install multiple versions side by side:
```bash
# Install several versions
claude-code install --version 0.0.83
claude-code install --version 0.0.85  
claude-code install --version 0.0.87

# List all installed versions
claude-code list --mode installed

# Switch between versions
claude-code use --version 0.0.85
```

### Version Isolation

Each version maintains complete isolation:
- **Node.js Runtime**: Version-specific Node.js installation
- **Dependencies**: Independent package installations
- **Configuration**: Separate `.npmrc` files in each version directory (never modifies user's `~/.npmrc`)
- **No Conflicts**: Versions cannot interfere with each other or user's npm configuration

## Advanced Usage

### Node.js Version Selection

Install with specific Node.js version:
```bash
# Use different Node.js version
claude-code install --version 0.0.85 --nodejs-version 22.18.0

# Verify Node.js version used
ls ~/.local/share/claude/versions/0.0.85/nodejs/
```

### Shell-Specific Installation

Configure only specific shells:
```bash
# Configure zsh only
claude-code install --shell zsh

# Configure multiple specific shells
claude-code install --shell bash
claude-code install --shell zsh
```

## Directory Structure

The installer creates an XDG-compliant directory structure:

```
~/.local/share/claude/          # Main data directory
├── current -> versions/0.0.85  # Symlink to active version
├── versions/                   # Version-specific installations
│   ├── 0.0.83/
│   │   ├── nodejs/             # Node.js runtime for this version
│   │   └── .npmrc              # npm configuration
│   ├── 0.0.85/
│   │   ├── nodejs/
│   │   └── .npmrc
│   └── 0.0.87/
│       ├── nodejs/
│       └── .npmrc
└── registry-tools/             # Shared registry query tools
    ├── nodejs/                 # Dedicated Node.js for queries
    └── .npmrc                  # Registry configuration

~/.local/bin/claude             # Version-aware wrapper script
~/.cache/claude/                # Download and npm cache
```

## Common Use Cases

### Development Environment Setup

```bash
# Initial setup for development team
claude-code install --debug

# Verify installation
claude --version
claude --check

# Initialize project (run once per project)
cd /path/to/project
claude
# Inside Claude: /init
```

### Version Upgrade Workflow

```bash
# Check current installation
claude-code list --mode installed

# Install new version
claude-code install --version 0.0.87

# Verify upgrade
claude --version

# Test new version
claude --help
```

### Multi-Version Development

```bash
# Install multiple versions for testing
claude-code install --version 0.0.85
claude-code install --version 0.0.86
claude-code install --version 0.0.87

# Switch between versions
claude-code use --version 0.0.85    # Test with older version
claude-code use --version 0.0.87    # Test with latest
```

## Error Scenarios and Troubleshooting

### Prerequisites Failures

**macOS Version Too Old**:
```bash
$ claude-code install
[ERROR] macOS 10.15+ required, found: 10.14
```
*Solution*: Upgrade macOS to 10.15 or later

**Missing Internet Connection**:
```bash
$ claude-code install  
[ERROR] Internet connection required to download Node.js
```
*Solution*: Connect to internet or VPN

### Installation Failures

**Node.js Download Failed**:
```bash
$ claude-code install
[ERROR] Failed to download Node.js from nodejs.org
```
*Solutions*:
1. Check firewall allows HTTPS connections to nodejs.org
2. Verify corporate proxy settings
3. Try with VPN if corporate network blocks access

**Package Installation Failed**:
```bash
$ claude-code install
[ERROR] Failed to install @apple/claude-code@0.0.85
```
*Solutions*:
1. Verify package version exists: `claude-code list`
2. Check registry authentication
3. Ensure sufficient disk space
4. Try with `--debug` for detailed error information

### Verification Failures

**Wrapper Script Issues**:
```bash
$ claude --version
Error: Current version symlink does not exist
```
*Solutions*:
1. Run installation again: `claude-code install`
2. Check permissions on `~/.local/share/claude/`
3. Verify no manual modifications to directory structure

**Shell Configuration Not Applied**:
```bash
$ claude --version
command not found: claude
```
*Solutions*:
1. Open new terminal or reload shell: `source ~/.bashrc`
2. Check PATH contains `~/.local/bin`: `echo $PATH`
3. Manually add to PATH if needed: `export PATH="$HOME/.local/bin:$PATH"`

## Idempotent Installation

The installer is idempotent - running it multiple times is safe:

```bash
# First installation
claude-code install --version 0.0.85
# [INFO] Installing version 0.0.85...
# [SUCCESS] Installation completed!

# Second run with same version
claude-code install --version 0.0.85  
# [WARNING] Version 0.0.85 is already installed
# [INFO] Installation is idempotent - no changes needed
```

## Performance Notes

- **First Installation**: Takes longer due to Node.js download and registry setup
- **Subsequent Installations**: Faster due to cached Node.js archives and registry tools
- **Registry Tools**: Shared across all versions for efficiency
- **Network Optimization**: Downloads cached locally to reduce repeated network access

## Integration with Other Commands

The install command works seamlessly with other toolkit operations:

```bash
# Complete workflow
claude-code install              # Install
claude-code list --mode installed # Verify
claude-code use --version 0.0.85 # Switch versions  
claude-code reinstall            # Reinstall if needed
claude-code uninstall --version 0.0.83 # Clean up old versions
```

## Related Commands

- [`list`](list.md) - View available and installed versions
- [`reinstall`](reinstall.md) - Reinstall existing versions
- [`uninstall`](uninstall.md) - Remove Claude Code versions
- [`use`](use.md) - Switch between installed versions
