# Installation Guide

This guide provides comprehensive installation options for the Claude Toolkit components.

## Quick Installation

For most users, install the complete toolkit:

```bash
# Using SSH (default)
git clone git@github.pie.apple.com:AI-for-Devs-Community/claude-toolkit.git
cd claude-toolkit

# Install toolkit infrastructure (creates global commands)
./scripts/claude-toolkit.sh install

# Install Claude Code (using global command)
claude-code install

# Install slash commands (using global command)
claude-slash install

# Install subagents (using global command)
claude-agents install

# Restart your shell to integrate new commands
exec $SHELL -l
```

**Important Notes:**
- **Shell Restart Required**: You must restart your shell (or open a new terminal) after installation to integrate the new commands into your environment.
- **Repository Cleanup**: After installation, all components are installed into standard XDG-compliant directories (`~/.local/share/`, `~/.local/bin/`, etc.) and operate independently. The cloned repository can be safely deleted as it's not needed for normal operation.

## Installation Methods

### Method 1: Complete Installation (Recommended)

Install all components in sequence:

#### Clone Repository
```bash
# Using SSH (default)
git clone git@github.pie.apple.com:AI-for-Devs-Community/claude-toolkit.git
cd claude-toolkit

# OR using HTTPS (if SSH is not available)
git clone https://github.pie.apple.com/AI-for-Devs-Community/claude-toolkit.git
cd claude-toolkit
```

#### Install Components
```bash
# 1. Install toolkit infrastructure (creates global commands, configures shell)
./scripts/claude-toolkit.sh install

# 2. Restart shell to activate toolkit commands
exec $SHELL -l

# 3. Install Claude Code (using global command)
claude-code install

# 4. Install slash commands (using global command)
claude-slash install

# 5. Install subagents (using global command)
claude-agents install

# 6. Final shell restart to activate all components
exec $SHELL -l
```

#### Verify Installation
```bash
# Check that all commands are available
which claude-toolkit claude-code claude-slash claude-agents claude

# Test Claude Code
claude --version

# List installed slash commands
claude-slash list

# List installed subagents
claude-agents list
```

### Method 2: Component-Specific Installation

Install only what you need:

#### Toolkit Infrastructure Only
```bash
git clone git@github.pie.apple.com:AI-for-Devs-Community/claude-toolkit.git
cd claude-toolkit
./scripts/claude-toolkit.sh install
exec $SHELL -l
```

#### Claude Code Only
```bash
# Requires toolkit infrastructure
claude-code install --version 0.0.85
```

#### Slash Commands Only
```bash
# Requires toolkit infrastructure  
claude-slash install                     # Install from all sources
claude-slash install --source claude-toolkit  # Install from specific source
```

#### Subagents Only
```bash
# Requires toolkit infrastructure  
claude-agents install                     # Install from all sources
claude-agents install --source claude-toolkit  # Install from specific source
```

### Method 3: HTTPS Installation

If SSH access is not available:

```bash
git clone https://github.pie.apple.com/AI-for-Devs-Community/claude-toolkit.git
cd claude-toolkit

# Use HTTPS for all git operations
./scripts/claude-toolkit.sh install --https

# Continue with normal installation (using global commands)
exec $SHELL -l
claude-code install
claude-slash install
claude-agents install
exec $SHELL -l
```

## Installation Options

### Shell-Specific Installation

Target specific shells:

```bash
# Install for zsh only (initial installation)
./scripts/claude-toolkit.sh install --shell=zsh
claude-code install --shell=zsh

# Install for bash only (initial installation)
./scripts/claude-toolkit.sh install --shell=bash
claude-code install --shell=bash

# Install for fish only (initial installation)
./scripts/claude-toolkit.sh install --shell=fish
claude-code install --shell=fish
```

### Version-Specific Installation

Install specific Claude Code versions:

```bash
# Install specific version (requires toolkit infrastructure)
claude-code install --version 0.0.84

# Install with specific Node.js version
claude-code install --nodejs-version 18.20.0

# Install multiple versions
claude-code install --version 0.0.84
claude-code install --version 0.0.85
```

### Preview Installation (Dry Run)

Preview operations without making changes:

```bash
# Preview toolkit installation (initial setup)
./scripts/claude-toolkit.sh install --dry-run

# Preview Claude Code installation (requires toolkit)
claude-code install --dry-run

# Preview slash commands installation (requires toolkit)
claude-slash install --dry-run
```

## Authentication Setup

### Apple Internal GitHub Access

For Apple employees using Apple's internal GitHub:

#### SSH Key Setup (Recommended)
```bash
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -C "your.email@apple.com"

# Add to ssh-agent
ssh-add ~/.ssh/id_ed25519

# Copy public key and add to GitHub
cat ~/.ssh/id_ed25519.pub
# Add this key to: https://github.pie.apple.com/settings/keys
```

#### HTTPS Token Setup (Alternative)
```bash
# Create personal access token at: https://github.pie.apple.com/settings/tokens
# Use token as password when prompted, or set environment variable:
export GITHUB_PIE_APPLE_TOKEN="your_token_here"

# Use HTTPS installation method
./scripts/claude-toolkit.sh install --https
```

## Verification

### Post-Installation Checks

Run these commands to verify your installation:

```bash
# Check that commands are in PATH
echo $PATH | grep ".local/bin"

# Verify all components are available
which claude-toolkit claude-code claude-slash claude-agents claude

# Test toolkit infrastructure
claude-toolkit validate

# Check Claude Code installation
claude-code list --mode installed

# List available slash commands
claude-slash list

# List available subagents
claude-agents list

# List configured command sources
claude-template-sources list

# Test Claude Code functionality
claude --version
```

### Directory Structure Verification

Verify the installation created the correct directory structure:

```bash
# Check XDG directories
ls -la ~/.local/bin/         # Should contain claude, claude-toolkit, etc.
ls -la ~/.local/share/       # Should contain claude-toolkit/, claude/
ls -la ~/.claude/commands/   # Should contain slash command files
ls -la ~/.claude/agents/     # Should contain subagent files

# Check toolkit installation
ls -la ~/.local/share/claude-toolkit/scripts/

# Check Claude Code installation
ls -la ~/.local/share/claude/versions/
```

## Troubleshooting Installation

### Common Issues

#### Command Not Found After Installation

**Problem**: `claude` or other commands not found after installation.

**Solution**:
```bash
# Check if PATH was updated
echo $PATH | grep ".local/bin"

# If not, manually add to shell config
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc  # or ~/.bashrc
source ~/.zshrc  # or ~/.bashrc

# Or restart terminal
exec $SHELL -l
```

#### Permission Denied Errors

**Problem**: Permission errors during installation.

**Solution**:
```bash
# Ensure directories are writable
chmod 755 ~/.local/bin ~/.local/share

# Check directory ownership
ls -la ~/.local/

# If needed, fix ownership (replace 'username' with your username)
sudo chown -R username:username ~/.local/
```

#### Git Clone Failures

**Problem**: Cannot clone repository.

**Solutions**:

1. **SSH Issues**:
```bash
# Test SSH connection
ssh -T git@github.pie.apple.com

# If SSH fails, use HTTPS instead
git clone https://github.pie.apple.com/AI-for-Devs-Community/claude-toolkit.git
```

2. **VPN/Network Issues**:
```bash
# Ensure you're connected to Apple VPN
# Check network connectivity
ping github.pie.apple.com
```

3. **Authentication Issues**:
```bash
# For HTTPS, ensure you have a valid token
# For SSH, ensure your key is added to GitHub
```

#### Node.js Download Failures

**Problem**: Claude Code installation fails downloading Node.js.

**Solution**:
```bash
# Check internet connectivity
curl -I https://nodejs.org/

# Try with specific Node.js version (requires toolkit)
claude-code install --nodejs-version 18.20.0

# Check for proxy/firewall issues
echo $HTTP_PROXY
echo $HTTPS_PROXY
```

### Debug Mode

Enable debug output for troubleshooting:

```bash
# Enable debug for initial toolkit installation
./scripts/claude-toolkit.sh install --debug

# Enable debug for component installations (requires toolkit)
claude-code install --debug
claude-slash install --debug
claude-agents install --debug
```

### Clean Reinstallation

If you need to start fresh:

```bash
# Uninstall all components (using global commands if available)
claude-agents uninstall --yes 2>/dev/null || true
claude-slash uninstall --yes 2>/dev/null || true
claude-code uninstall --all --yes 2>/dev/null || true
claude-toolkit uninstall --yes 2>/dev/null || true

# Remove directories
rm -rf ~/.local/share/claude*
rm -rf ~/.claude/commands/
rm -rf ~/.claude/agents/

# Clean PATH from shell configs (manual)
# Edit ~/.zshrc, ~/.bashrc, ~/.config/fish/config.fish
# Remove lines containing ".local/bin"

# Reinstall from scratch
./scripts/claude-toolkit.sh install
exec $SHELL -l
claude-code install  
claude-slash install
claude-agents install
exec $SHELL -l
```

## Advanced Installation

### Automated Installation Script

For team deployments or CI/CD:

```bash
#!/bin/bash
set -e

# Clone repository
git clone git@github.pie.apple.com:AI-for-Devs-Community/claude-toolkit.git
cd claude-toolkit

# Install toolkit infrastructure with automatic confirmation
./scripts/claude-toolkit.sh install --yes

# Install components using global commands
claude-code install --yes
claude-slash install --yes
claude-agents install --yes

echo "Claude Toolkit installation complete"
echo "Please restart your shell: exec \$SHELL -l"
```

### Custom Installation Paths

The toolkit follows XDG Base Directory specification. You can customize paths using environment variables:

```bash
# Customize installation directories
export XDG_DATA_HOME="$HOME/custom/share"
export XDG_BIN_DIR="$HOME/custom/bin"
export XDG_CONFIG_HOME="$HOME/custom/config"

# Install with custom paths
./scripts/claude-toolkit.sh install
```

## Uninstallation

### Complete Removal

To completely remove the Claude Toolkit:

```bash
# Remove components in reverse order (using global commands if available)
claude-agents uninstall --yes 2>/dev/null || true
claude-slash uninstall --yes 2>/dev/null || true
claude-code uninstall --all --yes 2>/dev/null || true
claude-toolkit uninstall --yes 2>/dev/null || true

# Manually clean up shell configurations
# Edit ~/.zshrc, ~/.bashrc, ~/.config/fish/config.fish
# Remove toolkit-related PATH entries
```

### Partial Removal

Remove specific components:

```bash
# Remove only slash commands (keeps user commands)
claude-slash uninstall

# Remove only subagents (keeps user subagents)
claude-agents uninstall

# Remove specific Claude Code version
claude-code uninstall --version 0.0.84

# Keep toolkit infrastructure for future use
# (just remove Claude Code, slash commands, and subagents)
```

## Support

If you encounter issues not covered in this guide:

- **Slack**: [#insights-platform-team](https://apple.enterprise.slack.com/archives/C021R2PFEJU)
- **Repository Issues**: Report bugs and request features
- **Internal Documentation**: Check Apple's internal Claude Code documentation
