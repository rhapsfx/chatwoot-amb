# Troubleshooting Guide

Common issues and solutions for `claude-template-sources.sh`.

## Quick Diagnostic Commands

```bash
# Check current configuration
claude-template-sources list --format detailed

# Test git connectivity
ssh -T git@github.com
ssh -T git@github.pie.apple.com

# Verify directory structure
ls -la ~/.config/claude-templates/
ls -la ~/.cache/claude-templates/
```

## Installation and Configuration Issues

### Configuration File Not Found

**Problem**: `No template sources configured` message appears

**Symptoms**:
```bash
$ claude-template-sources list
No template sources configured.
```

**Solution**:
```bash
# Create configuration directory
mkdir -p ~/.config/claude-templates

# Add your first source
claude-template-sources add claude-toolkit git@github.pie.apple.com:AI-for-Devs-Community/claude-toolkit.git

# Verify configuration was created
ls -la ~/.config/claude-templates/sources.csv
```

### Permission Denied Errors

**Problem**: Cannot read or write configuration files

**Symptoms**:
```bash
$ claude-template-sources add source git@repo.url
❌ Error: Permission denied writing to ~/.config/claude-templates/sources.csv
```

**Solution**:
```bash
# Check directory permissions
ls -la ~/.config/

# Create directory with correct permissions
mkdir -p ~/.config/claude-templates
chmod 755 ~/.config/claude-templates

# Fix file permissions if file exists
chmod 644 ~/.config/claude-templates/sources.csv

# Ensure you own the files
sudo chown -R $(whoami) ~/.config/claude-templates/
```

### Malformed Configuration File

**Problem**: Configuration file is corrupted or has wrong format

**Symptoms**:
```bash
$ claude-template-sources list
❌ Error parsing configuration file
```

**Solution**:
```bash
# Backup existing file
cp ~/.config/claude-templates/sources.csv ~/.config/claude-templates/sources.csv.bak

# Check file format
cat ~/.config/claude-templates/sources.csv

# Expected format:
# # Claude Template Sources Configuration
# # Format: source_name<TAB>git_url
# # Lines starting with # are comments
# source1	git@github.com:org/repo1.git
# source2	git@github.com:org/repo2.git

# Fix by recreating with proper format:
cat > ~/.config/claude-templates/sources.csv << 'EOF'
# Claude Template Sources Configuration
# Format: source_name<TAB>git_url
# Lines starting with # are comments
EOF

# Re-add sources
claude-template-sources add source1 git@github.com:org/repo1.git
```

## Git and Repository Issues

### SSH Key Authentication Failures

**Problem**: Cannot access repositories via SSH

**Symptoms**:
```bash
$ claude-template-sources add source git@github.com:org/repo.git --dry-run
❌ Repository is not accessible
Error: Permission denied (publickey)
```

**Solution**:
```bash
# 1. Check SSH key configuration
ssh-add -l

# 2. Add your SSH key if missing
ssh-add ~/.ssh/id_ed25519
# or
ssh-add ~/.ssh/id_rsa

# 3. Test SSH connectivity
ssh -T git@github.com

# 4. For Apple internal GitHub
ssh -T git@github.pie.apple.com

# 5. Generate new SSH key if needed
ssh-keygen -t ed25519 -C "your.email@apple.com"
```

### HTTPS Authentication Issues

**Problem**: Cannot access repositories via HTTPS

**Symptoms**:
```bash
$ claude-template-sources add source https://github.com/org/repo.git --dry-run
❌ Repository is not accessible
Error: Authentication failed
```

**Solution**:
```bash
# 1. Configure git credentials helper
git config --global credential.helper store

# 2. Or use token-based authentication
git config --global credential.helper 'cache --timeout=3600'

# 3. Test repository access manually
git clone https://github.com/org/repo.git /tmp/test-clone

# 4. For private repositories, use personal access token
# Create token at: https://github.com/settings/tokens
# Use format: https://token@github.com/org/repo.git
```

### Repository Not Found

**Problem**: Repository URL is incorrect or inaccessible

**Symptoms**:
```bash
$ claude-template-sources add source git@github.com:org/nonexistent.git --dry-run
❌ Repository is not accessible
Error: remote: Repository not found
```

**Solution**:
```bash
# 1. Verify repository URL
# Check the actual repository URL in browser or git service

# 2. Test with git directly
git ls-remote git@github.com:org/repo.git

# 3. Check repository permissions
# Ensure you have read access to the repository

# 4. Verify organization/owner name
# GitHub URLs are case-sensitive for organization names
```

### Network Connectivity Issues

**Problem**: Network timeouts or DNS resolution failures

**Symptoms**:
```bash
$ claude-template-sources add source git@github.com:org/repo.git --dry-run
❌ Repository is not accessible
Error: ssh: connect to host github.com port 22: Connection timed out
```

**Solution**:
```bash
# 1. Test basic connectivity
ping github.com
ping github.pie.apple.com

# 2. Check DNS resolution
nslookup github.com

# 3. Test SSH connectivity with verbose output
ssh -vT git@github.com

# 4. Check if you're behind a corporate firewall/proxy
# Contact IT support if needed

# 5. Try HTTPS if SSH fails
claude-template-sources add source https://github.com/org/repo.git --dry-run
```

## Repository Structure Issues

### Missing slash-commands Directory

**Problem**: Repository doesn't have required directory structure

**Symptoms**:
```bash
$ claude-template-sources add source git@github.com:org/repo.git --dry-run
❌ Repository does not contain slash-commands directory
```

**Solution**:
```bash
# 1. Clone and check repository structure
git clone git@github.com:org/repo.git /tmp/check-repo
ls -la /tmp/check-repo/

# 2. Required structure:
# repository-root/
# ├── slash-commands/          # Required directory
# │   ├── command1.md         # Command files
# │   └── command2.md
# └── README.md               # Optional

# 3. If you control the repository, add the required structure:
mkdir slash-commands
# Add .md files with proper YAML frontmatter

# 4. If you don't control the repository:
# Contact repository maintainer to add slash-commands structure
```

### No Command Files Found

**Problem**: slash-commands directory exists but contains no .md files

**Symptoms**:
```bash
$ claude-template-sources add source git@github.com:org/repo.git --dry-run
❌ No command files found in slash-commands directory
```

**Solution**:
```bash
# 1. Check directory contents
git clone git@github.com:org/repo.git /tmp/check-repo
ls -la /tmp/check-repo/slash-commands/

# 2. Ensure files have .md extension
# Files must end with .md

# 3. Check for hidden files or wrong extensions
find /tmp/check-repo/slash-commands/ -type f -name "*"

# 4. Repository needs at least one .md file in slash-commands/
```

### Invalid YAML Frontmatter

**Problem**: Command files have malformed YAML frontmatter

**Symptoms**:
```bash
$ claude-template-sources add source git@github.com:org/repo.git --dry-run
❌ Invalid YAML frontmatter in command file: command.md
```

**Solution**:
```bash
# 1. Check file format
git clone git@github.com:org/repo.git /tmp/check-repo
head -10 /tmp/check-repo/slash-commands/command.md

# 2. Required format:
---
description: Command description
source: source-name
argument-hint: <arguments>    # Optional
allowed-tools: Read, Write    # Optional
---

# Command Content
Instructions for Claude...

# 3. Common YAML issues:
# - Missing opening/closing --- lines
# - Indentation errors (use spaces, not tabs)
# - Missing required fields (description, source)
# - Invalid YAML syntax

# 4. Validate YAML syntax:
python3 -c "
import yaml
with open('/tmp/check-repo/slash-commands/command.md') as f:
    content = f.read()
    # Extract frontmatter between --- lines
    if content.startswith('---'):
        parts = content.split('---', 2)
        if len(parts) >= 2:
            yaml.safe_load(parts[1])
"
```

## Cache and Performance Issues

### Cache Directory Issues

**Problem**: Cache directories not being created or cleaned up properly

**Symptoms**:
```bash
$ claude-template-sources list --format detailed
⚠️ Cache Missing
```

**Solution**:
```bash
# 1. Check cache directory exists and is writable
ls -la ~/.cache/
mkdir -p ~/.cache/claude-templates
chmod 755 ~/.cache/claude-templates

# 2. Check available disk space
df -h ~/.cache/

# 3. Manual cache cleanup if needed
rm -rf ~/.cache/claude-templates/*

# 4. Test cache creation
claude-template-sources add test-source git@github.com:org/repo.git --dry-run
```

### Slow Repository Operations

**Problem**: Commands take very long to complete

**Symptoms**:
- Long delays during add operations
- Timeouts during repository validation

**Solution**:
```bash
# 1. Test repository access speed
time git ls-remote git@github.com:org/repo.git

# 2. Check if repository is very large
# Large repositories take longer to clone and validate

# 3. Use dry-run mode for testing without full clone
claude-template-sources add source git@repo.url --dry-run

# 4. Check network connectivity
ping github.com

# 5. Consider using HTTPS instead of SSH if SSH is slow
claude-template-sources add source https://github.com/org/repo.git
```

### Disk Space Issues

**Problem**: Not enough disk space for repository caches

**Symptoms**:
```bash
$ claude-template-sources add source git@github.com:org/large-repo.git
❌ Error: No space left on device
```

**Solution**:
```bash
# 1. Check available disk space
df -h ~/.cache/

# 2. Clean up old caches
du -sh ~/.cache/claude-templates/*
# Remove old/unused caches manually if needed

# 3. Use dry-run to estimate space requirements
claude-template-sources add source git@repo.url --dry-run

# 4. Consider using smaller repositories or cleaning up disk space
```

## Command Integration Issues

### Source Commands Not Available

**Problem**: Added source but commands don't appear in claude-slash

**Symptoms**:
```bash
$ claude-slash list --source new-source
No commands found for source 'new-source'
```

**Solution**:
```bash
# 1. Verify source was added correctly
claude-template-sources list | grep new-source

# 2. Install commands from the source
claude-slash install --source new-source

# 3. Check command installation location
ls -la ~/.claude/commands/

# 4. Verify command files have correct source field
grep "source:" ~/.claude/commands/*.md | grep new-source
```

### Source Field Mismatches

**Problem**: Commands have wrong source field in YAML frontmatter

**Symptoms**:
```bash
$ claude-template-sources add team-alpha git@repo.url --dry-run
⚠️ 2 commands have mismatched source field (expected 'team-alpha'):
   - deploy.md: source is 'legacy-team'
```

**This is a warning, not an error. Solutions**:

**Option 1: Accept the mismatch** (commands will still work)
```bash
# Commands will install and function normally
# Source field mismatch is informational only
claude-template-sources add team-alpha git@repo.url
claude-slash install --source team-alpha
```

**Option 2: Fix the source repository** (if you control it)
```bash
# Update YAML frontmatter in repository files
# Change source: legacy-team to source: team-alpha
```

**Option 3: Use a different source name** (to match existing files)
```bash
# Use source name that matches the files
claude-template-sources add legacy-team git@repo.url
```

## Advanced Troubleshooting

### Debug Mode Analysis

Use debug mode to get detailed information about what's happening:

```bash
# Enable debug mode for detailed output
claude-template-sources add source git@repo.url --debug --dry-run

# Debug output shows:
# - Argument parsing
# - Validation steps
# - Git commands executed
# - File operations
# - Error details
```

### Manual Repository Testing

```bash
# Test repository operations manually

# 1. Test basic git access
git ls-remote git@github.com:org/repo.git

# 2. Test full clone
git clone git@github.com:org/repo.git /tmp/test-clone

# 3. Check repository structure
find /tmp/test-clone -name "slash-commands" -type d

# 4. Validate command files
find /tmp/test-clone/slash-commands -name "*.md" -exec head -5 {} \;

# 5. Test YAML parsing
python3 -c "
import yaml
import os
for root, dirs, files in os.walk('/tmp/test-clone/slash-commands'):
    for file in files:
        if file.endswith('.md'):
            filepath = os.path.join(root, file)
            with open(filepath) as f:
                content = f.read()
                if content.startswith('---'):
                    parts = content.split('---', 2)
                    if len(parts) >= 2:
                        try:
                            yaml.safe_load(parts[1])
                            print(f'{file}: Valid YAML')
                        except Exception as e:
                            print(f'{file}: Invalid YAML - {e}')
"

# 6. Cleanup
rm -rf /tmp/test-clone
```

### Configuration File Recovery

If configuration is corrupted beyond repair:

```bash
# 1. Backup current configuration
cp ~/.config/claude-templates/sources.csv ~/.config/claude-templates/sources.csv.broken

# 2. Start fresh
rm ~/.config/claude-templates/sources.csv

# 3. Re-add sources one by one
claude-template-sources add claude-toolkit git@github.pie.apple.com:AI-for-Devs-Community/claude-toolkit.git
# Add other sources...

# 4. Verify configuration
claude-template-sources list
```

### Cache Directory Recovery

If cache is corrupted:

```bash
# 1. Remove all cached data
rm -rf ~/.cache/claude-templates/

# 2. Let sources rebuild cache as needed
claude-slash install  # Will rebuild caches for configured sources

# 3. Verify cache recreation
ls -la ~/.cache/claude-templates/
```

## Getting Help

### Collecting Debug Information

When reporting issues, collect this information:

```bash
# System information
uname -a
echo "Shell: $SHELL"

# Git configuration
git --version
git config --list | grep -E "(user|credential|core)"

# SSH configuration  
ssh-add -l
ssh -T git@github.com
ssh -T git@github.pie.apple.com

# Template sources configuration
claude-template-sources list --format detailed

# Directory permissions and contents
ls -la ~/.config/claude-templates/
ls -la ~/.cache/claude-templates/

# Recent error messages (if any)
# Include full error output and command that caused the error
```

### Common Command Patterns for Support

```bash
# Test suite for comprehensive debugging
echo "=== Configuration Test ==="
claude-template-sources list --format detailed

echo -e "\n=== Git Connectivity Test ==="
ssh -T git@github.com 2>&1
ssh -T git@github.pie.apple.com 2>&1

echo -e "\n=== Directory Structure Test ==="
ls -la ~/.config/claude-templates/ 2>&1
ls -la ~/.cache/claude-templates/ 2>&1

echo -e "\n=== Add Test (Dry Run) ==="
claude-template-sources add test-source git@github.pie.apple.com:AI-for-Devs-Community/claude-toolkit.git --dry-run --debug 2>&1

echo -e "\n=== Integration Test ==="
claude-slash list 2>&1
```

### Contact Information

- **Slack**: [#insights-platform-team](https://apple.enterprise.slack.com/archives/C021R2PFEJU)
- **Issues**: Report bugs in the repository
- **Documentation**: See [main documentation](index.md) for usage examples

## Related Documentation

- [`add`](add.md) - Add command documentation and examples
- [`remove`](remove.md) - Remove command documentation and examples
- [`list`](list.md) - List command documentation and examples
- [`dry-run`](dry-run.md) - Dry run mode for safe testing
- [Main Documentation](index.md) - Complete usage guide