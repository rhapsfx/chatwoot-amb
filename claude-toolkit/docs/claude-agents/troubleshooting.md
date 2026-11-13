# Troubleshooting claude-agents.sh

Common issues, solutions, and debugging techniques for subagent installation and management.

## Debug and Verbose Mode

Enable detailed logging for troubleshooting:

```bash
# Enable debug mode (detailed progress)
claude-agents install --debug

# Enable porcelain mode for machine-readable output
claude-agents install --porcelain

# Combine for maximum detail
claude-agents install --debug --porcelain
```

## Installation Issues

### Subagents Not Appearing After Installation

**Problem:** Subagents don't show up in Claude Code Task tool after successful installation.

**Diagnosis:**
```bash
# Check if subagents were installed
claude-agents list

# Check directory contents
ls -la ~/.claude/agents/

# Verify source subagents are marked correctly
grep -l "source:" ~/.claude/agents/*.md
```

**Solutions:**
1. **Restart Claude Code** - Subagents are loaded at startup
2. **Check Installation Location:**
   ```bash
   # Ensure agents directory exists
   mkdir -p ~/.claude/agents
   
   # Verify permissions
   ls -la ~/.claude/
   ```
3. **Verify Subagent Format:**
   ```bash
   # Check subagent has proper frontmatter
   head -10 ~/.claude/agents/architect.md
   ```

### Directory Structure Issues

**Problem:** Script cannot find expected directories or files.

**Diagnosis:**
```bash
# Check if running from repository or installed globally
which claude-agents

# Check current directory if running locally
pwd
ls -la agents/  # Should exist when run from repository

# Check source configuration
claude-template-sources list
```

**Solutions:**
```bash
# If running from repository directory
cd /path/to/claude-toolkit
./scripts/claude-agents.sh install

# If using global command after toolkit installation
claude-agents install

# Verify you have proper source configuration
claude-template-sources list --debug
```

### Network and Authentication Issues

**Problem:** Installation fails when downloading from remote repository.

**Common Errors:**
```
Failed to clone repository
Permission denied (publickey)
Connection timed out
Error cloning repository git@github.com:org/agents.git
```

**Solutions:**

1. **Check Source Configuration:**
   ```bash
   # List configured sources
   claude-template-sources list
   
   # Add source if missing
   claude-template-sources add claude-toolkit git@github.com:myorg/claude-toolkit.git
   ```

2. **Check Network Connectivity:**
   ```bash
   # Test repository access
   git ls-remote git@github.com:myorg/claude-toolkit.git
   
   # Test HTTPS access
   git ls-remote https://github.com/myorg/claude-toolkit.git
   ```

3. **VPN and Corporate Network:**
   - Connect to required VPN
   - Verify corporate firewall allows GitHub access
   - Check proxy settings if applicable

4. **Git Authentication Setup:**
   ```bash
   # Check SSH keys
   ssh-add -l
   
   # Add SSH key if needed
   ssh-add ~/.ssh/id_rsa
   
   # Test SSH authentication
   ssh -T git@github.com
   ```

## Subagent Conflicts and User Protection

### Naming Conflicts

**Problem:** User subagent has same name as source subagent.

**How It's Handled:**
- User subagent is automatically renamed with source suffix
- Original user subagent is preserved
- Source subagent takes the original name

**Example:**
```
architect.md (user) → architect-user.md
architect.md (claude-toolkit) → installed as architect.md
```

**Manual Resolution:**
```bash
# List both versions
ls ~/.claude/agents/architect*

# Compare content
diff ~/.claude/agents/architect.md ~/.claude/agents/architect-user.md

# Restore user version if desired
mv ~/.claude/agents/architect-user.md ~/.claude/agents/my-architect.md
```

### Subagent Discovery Issues

**Problem:** Subagents marked with source aren't being found.

**Diagnosis:**
```bash
# Check frontmatter format
head -10 ~/.claude/agents/subagent-name.md

# Verify source marker
grep "source:" ~/.claude/agents/*.md
```

**Solutions:**
1. **Correct Frontmatter Format:**
   ```yaml
   ---
   description: Subagent description
   source: claude-toolkit
   ---
   ```

2. **File Extension Check:**
   ```bash
   # Subagents must be .md files
   ls ~/.claude/agents/*.md
   ```

3. **Force Reinstall:**
   ```bash
   claude-agents reinstall --debug
   ```

## Directory and Permission Issues

### Agents Directory Missing

**Problem:** `~/.claude/agents/` directory doesn't exist.

**Solutions:**
```bash
# Create directory structure
mkdir -p ~/.claude/agents

# Check permissions
ls -la ~/.claude/

# Fix permissions if needed
chmod 755 ~/.claude ~/.claude/agents
```

### Permission Denied Errors

**Problem:** Cannot write to agents directory or files.

**Diagnosis:**
```bash
# Check directory permissions
ls -la ~/.claude/

# Check individual file permissions
ls -la ~/.claude/agents/

# Test write access
touch ~/.claude/agents/test.txt && rm ~/.claude/agents/test.txt
```

**Solutions:**
```bash
# Fix directory permissions
chmod 755 ~/.claude ~/.claude/agents

# Fix file permissions
chmod 644 ~/.claude/agents/*.md

# Check disk space
df -h ~/.claude/
```

### Read-Only Subagents

**Problem:** Some subagents appear to be read-only and can't be updated.

**This is by design for source subagents** to prevent accidental modification.

**Solutions:**
```bash
# Check which subagents are from sources vs user-created
claude-agents list --source claude-toolkit
claude-agents list --source user

# To modify a source subagent, create a user version
cp ~/.claude/agents/architect.md ~/.claude/agents/my-architect.md
# Remove source field from frontmatter in the copy
```

## Source and Repository Issues

### Source Configuration Problems

**Problem:** No sources configured or source not found.

**Solutions:**
```bash
# Check configured sources
claude-template-sources list

# Add missing source
claude-template-sources add claude-toolkit git@github.com:myorg/claude-toolkit.git

# Add multiple sources
claude-template-sources add team-alpha git@github.com:myorg/alpha-agents.git
claude-template-sources add team-beta git@github.com:myorg/beta-agents.git
```

### Repository Caching Problems

**Problem:** Installation uses outdated cached repository.

**Solutions:**
```bash
# Clear cache and reinstall
rm -rf ~/.cache/claude-templates/
claude-agents install --debug

# Or force fresh clone
claude-agents reinstall --debug
```

### Git Clone Failures

**Problem:** Cannot clone repository.

**Diagnosis:**
```bash
# Test git clone manually
git clone git@github.com:myorg/claude-toolkit.git /tmp/test-clone

# Check git configuration
git config --list | grep user
```

**Solutions:**
```bash
# Configure git if needed
git config --global user.name "Your Name"
git config --global user.email "your.email@company.com"

# Fix SSH if needed
ssh-keygen -t ed25519 -C "your.email@company.com"
```

## List and Filtering Issues

### List Command Shows Unexpected Results

**Problem:** List command doesn't show expected subagents or filtering doesn't work.

**Diagnosis:**
```bash
# List all subagents
claude-agents list --source all

# List only source subagents
claude-agents list --source claude-toolkit

# List only user subagents
claude-agents list --source user

# Check files directly
ls -la ~/.claude/agents/
```

**Solutions:**
```bash
# Verify frontmatter in subagents
for agent in ~/.claude/agents/*.md; do
  echo "=== $agent ==="
  head -10 "$agent"
done

# Check for hidden files
ls -la ~/.claude/agents/.*
```

## Subagent Content Issues

### Malformed Subagent Files

**Problem:** Subagents have syntax errors or malformed frontmatter.

**Diagnosis:**
```bash
# Check specific subagent
cat ~/.claude/agents/problematic-agent.md

# Verify YAML frontmatter
head -20 ~/.claude/agents/problematic-agent.md
```

**Solutions:**
1. **Correct YAML Frontmatter:**
   ```yaml
   ---
   description: Valid description
   source: claude-toolkit
   tools: Read, Write, Bash, Grep
   ---
   
   # Subagent content starts here
   ```

2. **Validate YAML:**
   ```bash
   # Extract and test YAML (if yq is available)
   sed -n '1,/^---$/p' ~/.claude/agents/agent.md | yq .
   ```

3. **Reinstall Corrupted Subagents:**
   ```bash
   # Remove problematic subagent
   rm ~/.claude/agents/problematic-agent.md
   
   # Reinstall
   claude-agents reinstall --debug
   ```

## Task Tool Integration Issues

### Subagents Not Available in Task Tool

**Problem:** Installed subagents don't appear as options in Claude Code Task tool.

**Solutions:**
1. **Restart Claude Code** - Essential for subagent recognition
2. **Check Subagent Format:**
   ```bash
   # Verify proper structure
   head -15 ~/.claude/agents/architect.md
   ```
3. **Verify Installation:**
   ```bash
   # Confirm subagents are properly installed
   claude-agents list --format detailed
   ```

### Subagent Execution Errors

**Problem:** Subagents appear in Task tool but fail to execute properly.

**Diagnosis:**
```bash
# Check subagent tools configuration
grep -A 5 "tools:" ~/.claude/agents/*.md

# Verify subagent syntax
head -30 ~/.claude/agents/problematic-agent.md
```

**Solutions:**
```bash
# Check for valid tools specification
# Valid format: tools: Read, Write, Bash, Grep, Glob
# Or: tools: *

# Reinstall if source subagent is corrupted
claude-agents reinstall --source claude-toolkit
```

## Advanced Debugging

### Dry Run Testing

**Test operations safely:**
```bash
# Test installation
claude-agents install --dry-run --debug

# Test reinstall
claude-agents reinstall --dry-run --debug

# Test uninstall
claude-agents uninstall --dry-run --debug
```

### Manual Subagent Installation

**For debugging, manually install a single subagent:**
```bash
# Create test subagent
cat > ~/.claude/agents/test-agent.md << 'EOF'
---
description: Test subagent for debugging
tools: Read, Write
---

# Test Agent

This is a test subagent for debugging purposes.

You are a helpful debugging assistant. When invoked, help the user debug their code by:

1. Analyzing the provided code or error
2. Identifying potential issues
3. Suggesting specific fixes
4. Providing clear explanations

Always be thorough and helpful in your debugging assistance.
EOF

# Verify it appears in list
claude-agents list --source user
```

### Cache and Repository Inspection

**Examine cached repository:**
```bash
# Check cache location
ls -la ~/.cache/claude-templates/

# Examine cached repositories
find ~/.cache/claude-templates/ -name "*.git" -type d

# Check cached subagents
find ~/.cache/claude-templates/ -name "agents" -type d
ls -la ~/.cache/claude-templates/*/claude-toolkit/agents/
```

## Environment and Configuration Issues

### XDG Directory Override

**Problem:** Subagents installed to unexpected location.

**Diagnosis:**
```bash
# Check XDG environment variables
echo "XDG_CONFIG_HOME: $XDG_CONFIG_HOME"
echo "XDG_CACHE_HOME: $XDG_CACHE_HOME"

# Check actual installation path
claude-agents list --format detailed
```

**Solutions:**
```bash
# Reset to defaults
unset XDG_CONFIG_HOME XDG_CACHE_HOME
claude-agents install

# Or set explicit paths
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
claude-agents install
```

### Shell Environment Issues

**Problem:** Script behavior inconsistent across different shells.

**Solutions:**
```bash
# Test in different shells
bash -c 'claude-agents list'
zsh -c 'claude-agents list'

# Check shell-specific environment
echo $BASH_VERSION
echo $ZSH_VERSION
```

## Recovery Procedures

### Complete Reset

**When all else fails:**
```bash
# Backup user subagents
mkdir -p ~/subagents-backup
cp ~/.claude/agents/*.md ~/subagents-backup/ 2>/dev/null || true
# Keep only files without 'source:' field (user subagents)
for file in ~/subagents-backup/*.md; do
    if grep -q "^source:" "$file"; then
        rm "$file"  # Remove source subagents from backup
    fi
done

# Clean slate
rm -rf ~/.claude/agents ~/.cache/claude-templates ~/.config/claude-templates

# Fresh installation
claude-template-sources add claude-toolkit git@github.com:myorg/claude-toolkit.git
claude-agents install --debug

# Restore user subagents
cp ~/subagents-backup/* ~/.claude/agents/ 2>/dev/null || true
```

### Selective Subagent Repair

**Fix specific problematic subagents:**
```bash
# Remove specific source subagent
rm ~/.claude/agents/architect.md

# Reinstall to get fresh copy
claude-agents reinstall --source claude-toolkit --debug

# Or reinstall all sources
claude-agents reinstall --debug
```

## Getting Diagnostic Information

**Collect comprehensive diagnostic data:**
```bash
# System information
uname -a
echo "Shell: $SHELL"

# Environment
echo "XDG_CONFIG_HOME: $XDG_CONFIG_HOME"
echo "XDG_CACHE_HOME: $XDG_CACHE_HOME"
echo "PWD: $PWD"

# Git configuration
git config --list | grep user

# Source configuration
claude-template-sources list

# Installation status
claude-agents list --source all --format detailed

# Directory contents
ls -la ~/.claude/agents/
ls -la ~/.config/claude-templates/ 2>/dev/null || echo "No config directory"
ls -la ~/.cache/claude-templates/ 2>/dev/null || echo "No cache directory"

# Subagent samples
for agent in ~/.claude/agents/*.md; do
  echo "=== $agent ==="
  head -10 "$agent"
done

# Network connectivity (if using remote sources)
ping -c 1 github.com 2>/dev/null && echo "Network OK" || echo "Network issue"
```

## Common Resolution Patterns

1. **90% of issues**: Restart Claude Code after installation
2. **Source issues**: Check `claude-template-sources list` and add missing sources
3. **Permission issues**: Check `~/.claude/agents/` permissions
4. **Subagent conflicts**: Check for renamed files with source suffixes
5. **Directory structure**: Ensure proper XDG directories exist
6. **Cache issues**: Clear `~/.cache/claude-templates/` and reinstall
7. **Network issues**: Verify git authentication and repository access

## Integration with Claude Code

### Task Tool Troubleshooting

**Problem:** Subagents installed but not appearing in Task tool.

**Solutions:**
```bash
# Verify Claude Code can see the agents directory
ls -la ~/.claude/agents/

# Check subagent format requirements
head -15 ~/.claude/agents/architect.md

# Restart Claude Code (essential)
# Close and reopen Claude Code application

# Test manually
claude
# Try using Task tool and look for your subagents
```

### Subagent Type Recognition

**Problem:** Task tool doesn't recognize subagent types.

**Solutions:**
```bash
# Check subagent naming matches file names
claude-agents list

# Verify subagents have proper descriptions
grep "description:" ~/.claude/agents/*.md

# Ensure no duplicate subagent names
ls ~/.claude/agents/ | sort | uniq -d
```