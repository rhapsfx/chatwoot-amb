# Troubleshooting claude-slash.sh

Common issues, solutions, and debugging techniques for slash command installation and management.

## Debug and Verbose Mode

Enable detailed logging for troubleshooting:

```bash
# Enable verbose mode (detailed progress)
./scripts/claude-slash.sh install --verbose

# Enable debug mode (even more detail)
DEBUG=true ./scripts/claude-slash.sh install

# Combine for maximum detail
DEBUG=true ./scripts/claude-slash.sh install --verbose
```

## Installation Issues

### Commands Not Appearing After Installation

**Problem:** Slash commands don't show up in Claude Code after successful installation.

**Diagnosis:**
```bash
# Check if commands were installed
./scripts/claude-slash.sh list

# Check directory contents
ls -la ~/.claude/commands/

# Verify toolkit commands are marked correctly
grep -l "toolkit-command: true" ~/.claude/commands/*.md
```

**Solutions:**
1. **Restart Claude Code** - Commands are loaded at startup
2. **Check Installation Location:**
   ```bash
   # Ensure commands directory exists
   mkdir -p ~/.claude/commands
   
   # Verify permissions
   ls -la ~/.claude/
   ```
3. **Verify Command Format:**
   ```bash
   # Check command has proper frontmatter
   head -10 ~/.claude/commands/smart-commit.md
   ```

### Directory Structure Issues

**Problem:** Script cannot find expected directories or files.

**Diagnosis:**
```bash
# Check if running from repository
ls -la slash-commands/  # Should exist when run from repository
ls -la .git/           # Should exist when run from repository

# Check current directory
pwd
```

**Solutions:**
```bash
# Make sure you're in the repository directory
cd /path/to/claude-code-toolkit
./scripts/claude-slash.sh install

# Verify you have proper directory structure
./scripts/claude-slash.sh install --verbose
```

### Network and Authentication Issues

**Problem:** Installation fails when downloading from remote repository.

**Common Errors:**
```
Failed to clone repository
Permission denied (publickey)
Connection timed out
```

**Solutions:**

1. **Use HTTPS Instead of SSH:**
   ```bash
   ./scripts/claude-slash.sh install --https
   ./scripts/claude-slash.sh reinstall --https
   ```

2. **Check Network Connectivity:**
   ```bash
   # Test GitHub access
   ping github.pie.apple.com
   
   # Test SSH authentication
   ssh -T git@github.pie.apple.com
   
   # Test HTTPS access
   curl -I https://github.pie.apple.com/AI-for-Devs-Community/claude-code-toolkit
   ```

3. **VPN and Corporate Network:**
   - Connect to Apple VPN
   - Verify corporate firewall allows GitHub access
   - Check proxy settings if applicable

4. **Git Authentication Setup:**
   ```bash
   # Check SSH keys
   ssh-add -l
   
   # Add SSH key if needed
   ssh-add ~/.ssh/id_rsa
   
   # Configure Git user
   git config --global user.name "Your Name"
   git config --global user.email "your.email@apple.com"
   ```

## Command Conflicts and User Protection

### Naming Conflicts

**Problem:** User command has same name as toolkit command.

**How It's Handled:**
- User command is automatically renamed with `.user-backup` suffix
- Original user command is preserved
- Toolkit command takes the original name

**Example:**
```
smart-commit.md (user) → smart-commit.user-backup.md
smart-commit.md (toolkit) → installed as smart-commit.md
```

**Manual Resolution:**
```bash
# List both versions
ls ~/.claude/commands/smart-commit*

# Compare content
diff ~/.claude/commands/smart-commit.md ~/.claude/commands/smart-commit.user-backup.md

# Restore user version if desired
mv ~/.claude/commands/smart-commit.user-backup.md ~/.claude/commands/my-smart-commit.md
```

### Command Discovery Issues

**Problem:** Commands marked as toolkit commands aren't being found.

**Diagnosis:**
```bash
# Check frontmatter format
head -10 ~/.claude/commands/command-name.md

# Verify toolkit-command marker
grep "toolkit-command:" ~/.claude/commands/*.md
```

**Solutions:**
1. **Correct Frontmatter Format:**
   ```yaml
   ---
   description: Command description
   toolkit-command: true
   ---
   ```

2. **File Extension Check:**
   ```bash
   # Commands must be .md files
   ls ~/.claude/commands/*.md
   ```

3. **Force Reinstall:**
   ```bash
   ./scripts/claude-slash.sh reinstall --verbose
   ```

## Directory and Permission Issues

### Commands Directory Missing

**Problem:** `~/.claude/commands/` directory doesn't exist.

**Solutions:**
```bash
# Create directory structure
mkdir -p ~/.claude/commands

# Check permissions
ls -la ~/.claude/

# Fix permissions if needed
chmod 755 ~/.claude ~/.claude/commands
```

### Permission Denied Errors

**Problem:** Cannot write to commands directory or files.

**Diagnosis:**
```bash
# Check directory permissions
ls -la ~/.claude/

# Check individual file permissions
ls -la ~/.claude/commands/

# Test write access
touch ~/.claude/commands/test.txt && rm ~/.claude/commands/test.txt
```

**Solutions:**
```bash
# Fix directory permissions
chmod 755 ~/.claude ~/.claude/commands

# Fix file permissions
chmod 644 ~/.claude/commands/*.md

# Check disk space
df -h ~/.claude/
```

### Read-Only Commands

**Problem:** Some commands appear to be read-only and can't be updated.

**This is by design for toolkit commands** to prevent accidental modification.

**Solutions:**
```bash
# Check which commands are read-only
ls -la ~/.claude/commands/

# Toolkit commands should show read-only permissions
# User commands should be writable

# To modify a toolkit command, create a user version
cp ~/.claude/commands/smart-commit.md ~/.claude/commands/my-smart-commit.md
chmod 644 ~/.claude/commands/my-smart-commit.md
```

## Git Repository Issues

### Repository Caching Problems

**Problem:** Standalone mode uses outdated cached repository.

**Solutions:**
```bash
# Clear cache and reinstall
rm -rf ~/.cache/slash-commands/
./scripts/claude-slash.sh install --verbose

# Or force fresh clone
./scripts/claude-slash.sh reinstall --verbose
```

### Git Clone Failures

**Problem:** Cannot clone repository.

**Diagnosis:**
```bash
# Test git clone manually
git clone git@github.pie.apple.com:AI-for-Devs-Community/claude-code-toolkit.git /tmp/test-clone

# Check git configuration
git config --list | grep user
```

**Solutions:**
```bash
# Use HTTPS instead
./scripts/claude-slash.sh install --https

# Configure git if needed
git config --global user.name "Your Name"
git config --global user.email "your.email@apple.com"

# Fix SSH if needed
ssh-keygen -t rsa -b 4096 -C "your.email@apple.com"
```

## List and Filtering Issues

### List Command Shows Unexpected Results

**Problem:** List command doesn't show expected commands or filtering doesn't work.

**Diagnosis:**
```bash
# List all commands
./scripts/claude-slash.sh list --filter all

# List only toolkit commands
./scripts/claude-slash.sh list --filter toolkit-only

# List only user commands
./scripts/claude-slash.sh list --filter user-only

# Check files directly
ls -la ~/.claude/commands/
```

**Solutions:**
```bash
# Verify frontmatter in commands
for cmd in ~/.claude/commands/*.md; do
  echo "=== $cmd ==="
  head -10 "$cmd"
done

# Check for hidden files
ls -la ~/.claude/commands/.*
```

## Command Content Issues

### Malformed Command Files

**Problem:** Commands have syntax errors or malformed frontmatter.

**Diagnosis:**
```bash
# Check specific command
cat ~/.claude/commands/problematic-command.md

# Verify YAML frontmatter
head -20 ~/.claude/commands/problematic-command.md
```

**Solutions:**
1. **Correct YAML Frontmatter:**
   ```yaml
   ---
   description: Valid description
   argument-hint: <arguments>
   toolkit-command: true
   ---
   
   # Command content starts here
   ```

2. **Validate YAML:**
   ```bash
   # Extract and test YAML (if yq is available)
   sed -n '1,/^---$/p' ~/.claude/commands/command.md | yq .
   ```

3. **Reinstall Corrupted Commands:**
   ```bash
   # Remove problematic command
   rm ~/.claude/commands/problematic-command.md
   
   # Reinstall
   ./scripts/claude-slash.sh reinstall --verbose
   ```

## Advanced Debugging

### Dry Run Testing

**Test operations safely:**
```bash
# Test installation
./scripts/claude-slash.sh install --dry-run --verbose

# Test reinstall
./scripts/claude-slash.sh reinstall --dry-run --verbose

# Test uninstall
./scripts/claude-slash.sh uninstall --dry-run --verbose
```

### Manual Command Installation

**For debugging, manually install a single command:**
```bash
# Create test command
cat > ~/.claude/commands/test-command.md << 'EOF'
---
description: Test command
toolkit-command: false
---

# Test Command

This is a test command.

Arguments: $ARGUMENTS
EOF

# Verify it appears in list
./scripts/claude-slash.sh list --filter user-only
```

### Cache and Repository Inspection

**Examine cached repository:**
```bash
# Check cache location
ls -la ~/.cache/slash-commands/

# Examine cached repository
cd ~/.cache/slash-commands/claude-code-toolkit
git status
git log --oneline -5

# Check cached commands
ls -la slash-commands/
```

## Environment and Configuration Issues

### XDG Directory Override

**Problem:** Commands installed to unexpected location.

**Diagnosis:**
```bash
# Check XDG environment variables
echo "XDG_HOME: $XDG_HOME"
echo "XDG_CACHE_HOME: $XDG_CACHE_HOME"

# Check actual installation path
./scripts/claude-slash.sh list
```

**Solutions:**
```bash
# Reset to defaults
unset XDG_HOME XDG_CACHE_HOME
./scripts/claude-slash.sh install

# Or set explicit paths
export XDG_HOME="$HOME"
./scripts/claude-slash.sh install
```

### Shell Environment Issues

**Problem:** Script behavior inconsistent across different shells.

**Solutions:**
```bash
# Test in different shells
bash -c './scripts/claude-slash.sh list'
zsh -c './scripts/claude-slash.sh list'

# Check shell-specific environment
echo $BASH_VERSION
echo $ZSH_VERSION
```

## Recovery Procedures

### Complete Reset

**When all else fails:**
```bash
# Backup user commands
mkdir -p ~/slash-commands-backup
cp ~/.claude/commands/*.user-backup.md ~/slash-commands-backup/ 2>/dev/null || true
cp ~/.claude/commands/my-*.md ~/slash-commands-backup/ 2>/dev/null || true

# Clean slate
rm -rf ~/.claude/commands ~/.cache/slash-commands

# Fresh installation
./scripts/claude-slash.sh install --verbose

# Restore user commands
cp ~/slash-commands-backup/* ~/.claude/commands/ 2>/dev/null || true
```

### Selective Command Repair

**Fix specific problematic commands:**
```bash
# Remove specific toolkit command
rm ~/.claude/commands/smart-commit.md

# Reinstall to get fresh copy
./scripts/claude-slash.sh reinstall --verbose

# Or manually download specific command
curl -o ~/.claude/commands/smart-commit.md \
  https://raw.github.pie.apple.com/AI-for-Devs-Community/claude-code-toolkit/main/slash-commands/smart-commit.md
```

## Getting Diagnostic Information

**Collect comprehensive diagnostic data:**
```bash
# System information
uname -a
echo "Shell: $SHELL"

# Environment
echo "XDG_HOME: $XDG_HOME"
echo "XDG_CACHE_HOME: $XDG_CACHE_HOME"
echo "PWD: $PWD"

# Git configuration
git config --list | grep user

# Installation status
./scripts/claude-slash.sh list --filter all

# Directory contents
ls -la ~/.claude/commands/
ls -la ~/.cache/slash-commands/ 2>/dev/null || echo "No cache directory"

# Command samples
for cmd in ~/.claude/commands/*.md; do
  echo "=== $cmd ==="
  head -5 "$cmd"
done

# Network connectivity
ping -c 1 github.pie.apple.com 2>/dev/null && echo "Network OK" || echo "Network issue"
```

## Common Resolution Patterns

1. **85% of issues**: Restart Claude Code after installation
2. **Network issues**: Use `--https` flag + VPN connection
3. **Permission issues**: Check `~/.claude/commands/` permissions
4. **Command conflicts**: Check for `.user-backup` files
5. **Directory structure**: Ensure running from correct repository directory
6. **Cache issues**: Clear `~/.cache/slash-commands/` and reinstall
