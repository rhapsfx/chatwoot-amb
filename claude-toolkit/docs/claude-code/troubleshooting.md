# Troubleshooting claude-code.sh

Common issues, solutions, and debugging techniques for Claude Code installation and management.

## Debug Mode

Enable detailed logging for troubleshooting:

```bash
# Enable debug mode
export DEBUG=true
./scripts/claude-code.sh install

# Or inline debug
DEBUG=true ./scripts/claude-code.sh install --version 0.0.85
```

## Installation Issues

### Command Not Found After Installation

**Problem:** `claude: command not found` after successful installation.

**Diagnosis:**
```bash
# Check if installation exists
./scripts/claude-code.sh list --mode installed

# Check wrapper script exists
ls -la ~/.local/bin/claude

# Check PATH includes ~/.local/bin
echo $PATH | grep ".local/bin"
```

**Solutions:**
```bash
# Option 1: Restart terminal (recommended)
exec $SHELL -l

# Option 2: Source shell configuration
source ~/.zshrc  # or ~/.bash_profile for bash

# Option 3: Check shell configuration was added
grep -A 5 "claude-code-shell-setup" ~/.zshrc
```

### Download/Network Issues

**Problem:** Installation fails during Node.js or package download.

**Common Errors:**
```
Failed to download Node.js distribution
Connection timeout to artifacts.apple.com
Registry authentication failed
```

**Solutions:**

1. **Check Network Connectivity:**
   ```bash
   # Test Apple internal services
   curl -I https://artifacts.apple.com/node-distributions
   curl -I https://npm.apple.com/
   
   # Check VPN connection
   ping artifacts.apple.com
   ```

2. **JWT Token Authentication:**
   ```bash
   # Set JWT token for corporate registry
   export NPM_JWT_TOKEN="your_jwt_token_here"
   ./scripts/claude-code.sh install
   
   # Verify token works
   curl -H "Authorization: Bearer $NPM_JWT_TOKEN" https://npm.apple.com/
   ```

3. **Corporate Network Issues:**
   - Connect to Apple VPN
   - Verify corporate firewall allows access
   - Check proxy settings if applicable

### Permission and Directory Issues

**Problem:** Installation fails due to permission errors.

**Common Errors:**
```
Permission denied: ~/.local/share/claude
Failed to create directory
```

**Solutions:**
```bash
# Check and fix directory permissions
ls -la ~/.local/
chmod 755 ~/.local/share ~/.local/bin

# Create directories manually if needed
mkdir -p ~/.local/share/claude ~/.cache/claude ~/.local/bin

# Check disk space
df -h ~
```

### Version Conflicts and Dependencies

**Problem:** Installation conflicts with existing Claude Code or Node.js installations.

**Diagnosis:**
```bash
# Check what's currently installed
./scripts/claude-code.sh list --mode installed

# Check for conflicting installations
which claude
which node

# Check current version info
./scripts/claude-code.sh use
```

**Solutions:**
```bash
# Clean reinstall
./scripts/claude-code.sh uninstall --all
./scripts/claude-code.sh install

# Or reinstall specific version
./scripts/claude-code.sh reinstall --version 0.0.85
```

## Version Management Issues

### Cannot Switch Versions

**Problem:** `use` command fails or doesn't switch versions properly.

**Diagnosis:**
```bash
# Check what versions are installed
./scripts/claude-code.sh list --mode installed

# Check current symlink
ls -la ~/.local/share/claude/current

# Verify target version exists
ls ~/.local/share/claude/versions/
```

**Solutions:**
```bash
# Try dry-run first
./scripts/claude-code.sh use --version 0.0.85 --dry-run

# Force reinstall if version is corrupted
./scripts/claude-code.sh reinstall --version 0.0.85

# Check wrapper script is correct
cat ~/.local/bin/claude
```

### Version Not Found

**Problem:** Requested version not available for installation.

**Solutions:**
```bash
# List available versions
./scripts/claude-code.sh list

# List with machine-readable format
./scripts/claude-code.sh list --porcelain

# Try latest version
./scripts/claude-code.sh install
```

## Corporate Environment Issues

### Registry Authentication Failures

**Problem:** Cannot authenticate with Apple's internal npm registry.

**Solutions:**

1. **JWT Token Setup:**
   ```bash
   # Obtain JWT token from Apple's auth system
   # Set token environment variable
   export NPM_JWT_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
   
   # Make token permanent
   echo 'export NPM_JWT_TOKEN="your_token"' >> ~/.zshrc
   ```

2. **Registry Configuration:**
   ```bash
   # Verify registry URL
   echo $CORPORATE_NPM_REGISTRY
   
   # Test registry access
   curl -H "Authorization: Bearer $NPM_JWT_TOKEN" \
        https://npm.apple.com/@apple/claude-code
   ```

### Proxy and Firewall Issues

**Problem:** Corporate network blocks required connections.

**Solutions:**
```bash
# Check proxy settings
echo $HTTP_PROXY
echo $HTTPS_PROXY
echo $NO_PROXY

# Test specific endpoints
curl --proxy $HTTP_PROXY https://artifacts.apple.com/node-distributions
curl --proxy $HTTP_PROXY https://npm.apple.com/
```

## Shell Integration Issues

### Multiple Shell Conflicts

**Problem:** Claude works in one shell but not others.

**Diagnosis:**
```bash
# Check which shells have configuration
grep -l "claude-code-shell-setup" ~/.zshrc ~/.bash_profile ~/.config/fish/config.fish

# Test each shell
bash -c 'echo $PATH'
zsh -c 'echo $PATH'
fish -c 'echo $PATH'
```

**Solutions:**
```bash
# Configure specific shell
./scripts/claude-code.sh reinstall --shell=zsh

# Or configure all shells
./scripts/claude-code.sh reinstall
```

### Configuration Not Applied

**Problem:** Shell configuration exists but PATH not updated.

**Solutions:**
```bash
# Check configuration syntax
bash -n ~/.bash_profile  # Test bash syntax
zsh -n ~/.zshrc          # Test zsh syntax

# Source configuration manually
source ~/.zshrc

# Check for duplicate or conflicting entries
grep -n PATH ~/.zshrc
```

## Version Directory Issues

### Corrupted Installation

**Problem:** Version directory exists but installation is broken.

**Diagnosis:**
```bash
# Check version directory structure
ls -la ~/.local/share/claude/versions/0.0.85/

# Check Node.js installation
~/.local/share/claude/versions/0.0.85/bin/node --version

# Check Claude package
ls ~/.local/share/claude/versions/0.0.85/lib/node_modules/@apple/
```

**Solutions:**
```bash
# Reinstall specific version
./scripts/claude-code.sh reinstall --version 0.0.85

# Or remove and reinstall
./scripts/claude-code.sh uninstall --version 0.0.85
./scripts/claude-code.sh install --version 0.0.85
```

### Disk Space Issues

**Problem:** Installation fails due to insufficient disk space.

**Diagnosis:**
```bash
# Check disk space
df -h ~/.local/share/claude
du -sh ~/.local/share/claude/*

# Check cache directory
du -sh ~/.cache/claude
```

**Solutions:**
```bash
# Clean up old versions
./scripts/claude-code.sh uninstall --version old_version

# Clear cache
rm -rf ~/.cache/claude/*

# Remove all and reinstall
./scripts/claude-code.sh uninstall --all
./scripts/claude-code.sh install
```

## Advanced Debugging

### Dry Run Testing

**Test operations without making changes:**
```bash
# Test installation
./scripts/claude-code.sh install --dry-run --version 0.0.85

# Test version switching
./scripts/claude-code.sh use --dry-run --version 0.0.83

# Test uninstall
./scripts/claude-code.sh uninstall --dry-run --all
```

### Porcelain Mode for Automation

**Machine-readable output for scripting:**
```bash
# List versions in porcelain format
./scripts/claude-code.sh list --porcelain

# Use version with porcelain output
./scripts/claude-code.sh use --porcelain --version 0.0.85
```

### Manual Recovery

**When automatic operations fail:**

1. **Check Installation State:**
   ```bash
   # Examine directory structure
   find ~/.local/share/claude -type f -name "node" -exec ls -la {} \;
   
   # Check wrapper script
   cat ~/.local/bin/claude
   
   # Verify symlinks
   ls -la ~/.local/share/claude/current
   ```

2. **Manual Cleanup:**
   ```bash
   # Remove broken symlinks
   find ~/.local/share/claude -type l -! -exec test -e {} \; -delete
   
   # Fix permissions
   chmod +x ~/.local/bin/claude
   chmod +x ~/.local/share/claude/versions/*/bin/node
   ```

3. **Rebuild from Scratch:**
   ```bash
   # Complete clean slate
   rm -rf ~/.local/share/claude ~/.cache/claude ~/.local/bin/claude
   
   # Remove shell configuration
   # Edit ~/.zshrc, ~/.bash_profile to remove claude-code sections
   
   # Fresh installation
   ./scripts/claude-code.sh install
   ```

## Environment Variable Override

**Custom installation paths for testing:**
```bash
# Override XDG directories
export XDG_DATA_HOME="/custom/path/share"
export XDG_CACHE_HOME="/custom/path/cache"
./scripts/claude-code.sh install

# Override specific Claude directories (advanced)
export CLAUDE_DATA_DIR="/custom/claude/path"
./scripts/claude-code.sh install
```

## Getting Diagnostic Information

**Collect information for support:**
```bash
# System information
uname -a
echo "Shell: $SHELL"

# Environment variables
echo "PATH: $PATH"
echo "XDG_DATA_HOME: $XDG_DATA_HOME"
echo "NPM_JWT_TOKEN: ${NPM_JWT_TOKEN:+[SET]}"

# Installation status
./scripts/claude-code.sh list --mode installed --porcelain
ls -la ~/.local/bin/claude
ls -la ~/.local/share/claude/current

# Shell configuration
grep -A 10 -B 5 "claude-code-shell-setup" ~/.zshrc ~/.bash_profile ~/.config/fish/config.fish

# Network connectivity
curl -I https://artifacts.apple.com/node-distributions
curl -I https://npm.apple.com/
```

## Common Resolution Patterns

1. **80% of issues**: Clean reinstall resolves most problems
2. **Network issues**: VPN connection + JWT token authentication
3. **Shell issues**: Restart terminal or source configuration
4. **Version issues**: Use dry-run mode to test first
5. **Permission issues**: Check ~/.local/ directory permissions
6. **Corporate issues**: JWT token + proper network connectivity
