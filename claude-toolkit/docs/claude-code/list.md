# List Command

View available and installed Claude Code versions with installation status indicators.

## Overview

The `list` command provides a comprehensive view of Claude Code versions, showing which versions are available for download, currently installed, and which is set as the default. This is essential for version management and understanding your current installation state.

## Basic Usage

```bash
# Show all available versions with installation status (default)
./scripts/claude-code.sh list

# Show only installed versions  
./scripts/claude-code.sh list --mode installed

# Show available versions explicitly
./scripts/claude-code.sh list --mode available

# Preview list operation without changes
./scripts/claude-code.sh list --dry-run
```

## Command Syntax

```bash
./scripts/claude-code.sh list [options]
```

### Core Options

| Option | Description |
|--------|-------------|
| `--mode <mode>` | Specify listing mode: `available` (default) or `installed` |

### Global Options

| Option | Description |
|--------|-------------|
| `--verbose` | Show detailed output with additional logging |
| `--dry-run` | Preview list operation without making system modifications |
| `--porcelain` | Machine-readable output format |
| `--help`, `-h` | Show command help information |

## Output Format

### Available Mode (Default)

Shows all versions available for download and installation, with status indicators for installed versions:

```bash
$ claude-code.sh list
0.0.82
0.0.83 (installed)
0.0.84
0.0.85 (installed, current)
0.0.86
0.0.87 (installed)
```

**Status Indicators:**
- **No indicator**: Version is available for download but not installed locally
- **(installed)**: Version is installed locally but not currently the default
- **(installed, current)**: Version is installed and currently set as the active default

### Installed Mode

Shows only versions that are currently installed on your system:

```bash
$ claude-code.sh list --mode installed
0.0.83 (installed)
0.0.85 (installed, current)
0.0.87 (installed)
```

## Version Sorting

Versions are displayed in semantic version order (using `sort -V`), ensuring proper ordering:
- `0.0.9` comes before `0.0.10`
- `0.0.85` comes before `0.1.0`
- Pre-release versions are handled appropriately

## Common Use Cases

### Check Installation Status

Before installing or managing versions, see what's currently available:

```bash
# See all versions and their status
claude-code.sh list

# Focus on what's already installed
claude-code.sh list --mode installed
```

### Version Management Workflow

```bash
# 1. Check current state
claude-code.sh list --mode installed

# 2. See what versions are available to install
claude-code.sh list

# 3. Install a specific version (example)
claude-code.sh install --version 0.0.86

# 4. Verify the installation
claude-code.sh list --mode installed
```

### Automation and Scripting

The list command output is designed to work well with standard Unix tools:

```bash
# Get all installed version numbers
claude-code.sh list --mode installed | cut -d' ' -f1

# Find non-default installed versions
claude-code.sh list --mode installed | grep -v default | cut -d' ' -f1

# Count installed versions
claude-code.sh list --mode installed | wc -l

# Check if a specific version is installed
if claude-code.sh list --mode installed | grep -q "0.0.85"; then
    echo "Version 0.0.85 is installed"
fi
```

## System Administration

### Multi-System Inventory

```bash
# Check versions across multiple systems
for host in server1 server2 server3; do
    echo "$host: $(ssh $host 'claude-code.sh list --mode installed')"
done
```

### Cleanup Preparation

```bash
# See all installed versions before cleanup
claude-code.sh list --mode installed

# Identify versions to remove (keeping only default)
claude-code.sh list --mode installed | grep -v default
```

## Error Scenarios

### No Versions Installed

When no Claude Code versions are installed locally:

```bash
$ claude-code.sh list --mode installed
No Claude Code versions installed
```

### Network Issues

If the remote registry is unreachable, only local versions are shown with a warning:

```bash
$ claude-code.sh list
Warning: Unable to fetch remote versions, showing local only
0.0.85 (installed, current)
```

### No Versions Found

In rare cases where no versions are available anywhere:

```bash
$ claude-code.sh list
No Claude Code versions found
```

## Troubleshooting

### Command Not Found

If the command isn't recognized, ensure Claude Toolkit is properly installed:

```bash
# Check if the script exists
ls -la scripts/claude-code.sh

# Run from the correct directory or use full path
/path/to/claude-code-toolkit/scripts/claude-code.sh --list
```

### Registry Access Issues

If you see authentication or network errors:

1. **Corporate Network**: Ensure your `NPM_JWT_TOKEN` environment variable is set
2. **VPN Required**: Connect to your organization's VPN if required
3. **Firewall Issues**: Check that outbound HTTPS connections are allowed

### Inconsistent Output

If the output seems inconsistent:

```bash
# Use verbose mode for diagnostic information
claude-code.sh list --verbose

# Check your installation directory
ls -la ~/.local/share/claude/versions/
```

## Integration with Other Commands

The list command works seamlessly with other Claude Toolkit operations:

```bash
# After installation
claude-code.sh install --version 0.0.86
claude-code.sh list --mode installed  # Verify installation

# Before uninstall
claude-code.sh list --mode installed  # See what's installed
claude-code.sh uninstall --version 0.0.85  # Remove specific version
claude-code.sh list --mode installed  # Confirm removal

# Version switching workflow
claude-code.sh list --mode installed  # Check available versions
claudectl use 0.0.86                        # Switch versions (if available)
```

## Performance Notes

- **First Run**: The initial list command may take a few seconds as it sets up registry tools and queries the remote npm registry
- **Subsequent Runs**: Faster due to cached registry tools and network optimizations
- **Offline Mode**: When network is unavailable, only local versions are shown instantly

## Related Commands

- [`install`](install.md) - Install Claude Code versions
- [`reinstall`](reinstall.md) - Reinstall existing versions
- [`uninstall`](uninstall.md) - Remove Claude Code versions
- [`use`](use.md) - Switch between installed versions
- [`claudectl`](../claudectl/index.md) - Alternative command interface for version management
