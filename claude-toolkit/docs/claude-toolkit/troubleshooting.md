# Troubleshooting

Common issues and solutions for claude-toolkit.sh operations.

## Installation Issues

### Repository Access Problems

#### SSH Authentication Failures

**Symptoms**:
```bash
[ERROR] Permission denied (publickey).
[ERROR] Failed to clone repository from git@github.pie.apple.com:AI-for-Devs-Community/claude-toolkit.git
```

**Causes**:
- SSH key not configured
- SSH key not added to GitHub
- VPN not connected to Apple network

**Solutions**:

1. **Use HTTPS instead**:
   ```bash
   ./scripts/claude-toolkit.sh install --https
   ```

2. **Check SSH key setup**:
   ```bash
   # Test SSH connection
   ssh -T git@github.pie.apple.com
   
   # Generate SSH key if needed
   ssh-keygen -t ed25519 -C "your.email@apple.com"
   
   # Add to ssh-agent
   ssh-add ~/.ssh/id_ed25519
   
   # Add public key to GitHub
   cat ~/.ssh/id_ed25519.pub
   ```

3. **Verify VPN connection**:
   ```bash
   ping github.pie.apple.com
   ```

#### HTTPS Authentication Issues

**Symptoms**:
```bash
[ERROR] remote: Invalid username or password.
[ERROR] fatal: Authentication failed for 'https://github.pie.apple.com/...'
```

**Solutions**:

1. **Create personal access token**:
   - Go to https://github.pie.apple.com/settings/tokens
   - Create new token with repo access
   - Use token as password when prompted

2. **Set environment variable**:
   ```bash
   export GITHUB_PIE_APPLE_TOKEN="your_token_here"
   ./scripts/claude-toolkit.sh install --https
   ```

### Network Connectivity Issues

#### VPN Connection Problems

**Symptoms**:
```bash
[ERROR] Could not resolve hostname github.pie.apple.com
[ERROR] Failed to connect to github.pie.apple.com port 443
```

**Solutions**:

1. **Check VPN status**:
   ```bash
   # Test connectivity to Apple internal network
   ping github.pie.apple.com
   nslookup github.pie.apple.com
   ```

2. **Reconnect VPN**: Disconnect and reconnect to Apple VPN

3. **Check proxy settings**:
   ```bash
   echo $HTTP_PROXY
   echo $HTTPS_PROXY
   # Clear if set incorrectly
   unset HTTP_PROXY HTTPS_PROXY
   ```

### Permission Issues

#### Directory Permission Errors

**Symptoms**:
```bash
[ERROR] Failed to create directory: ~/.local/share
[ERROR] Permission denied
```

**Solutions**:

1. **Fix directory ownership**:
   ```bash
   sudo chown -R $USER:$USER ~/.local/
   chmod 755 ~/.local/
   ```

2. **Create directories manually**:
   ```bash
   mkdir -p ~/.local/share ~/.local/bin
   chmod 755 ~/.local/share ~/.local/bin
   ```

#### Script Permission Issues

**Symptoms**:
```bash
[ERROR] File is not executable: ~/.local/share/claude-toolkit/scripts/claude-toolkit.sh
```

**Solutions**:

1. **Fix script permissions**:
   ```bash
   chmod +x ~/.local/share/claude-toolkit/scripts/*.sh
   ```

2. **Reinstall with proper permissions**:
   ```bash
   ./scripts/claude-toolkit.sh reinstall
   ```

## Shell Integration Issues

### Commands Not Found After Installation

**Symptoms**:
```bash
claude-toolkit: command not found
claude-code: command not found
```

**Causes**:
- Shell not restarted after installation
- PATH not updated correctly
- Shell configuration not loaded

**Solutions**:

1. **Restart shell**:
   ```bash
   exec $SHELL -l
   ```
   Or open new terminal window

2. **Check PATH configuration**:
   ```bash
   echo $PATH | grep ".local/bin"
   ```

3. **Manually add to PATH**:
   ```bash
   # For bash/zsh
   echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
   source ~/.zshrc
   
   # For fish
   echo 'set -gx PATH "$HOME/.local/bin" $PATH' >> ~/.config/fish/config.fish
   source ~/.config/fish/config.fish
   ```

4. **Verify symlinks exist**:
   ```bash
   ls -la ~/.local/bin/claude-*
   ```

### Shell Configuration Conflicts

**Symptoms**:
- PATH entries duplicated multiple times
- Shell startup becomes slow
- Environment variables not set correctly

**Solutions**:

1. **Clean duplicate entries**:
   ```bash
   # Edit shell RC file manually
   vim ~/.zshrc  # or ~/.bashrc, ~/.config/fish/config.fish
   
   # Remove duplicate PATH entries
   # Keep only one copy of:
   # export PATH="$HOME/.local/bin:$PATH"
   ```

2. **Reset shell configuration**:
   ```bash
   # Backup current config
   cp ~/.zshrc ~/.zshrc.backup
   
   # Remove toolkit entries
   ./scripts/claude-toolkit.sh uninstall
   
   # Clean install
   ./scripts/claude-toolkit.sh install
   ```

### Specific Shell Issues

#### Bash on macOS

**Issue**: Configuration goes to wrong file (`.bashrc` vs `.bash_profile`)

**Solution**:
```bash
# Ensure .bash_profile sources .bashrc
echo 'source ~/.bashrc' >> ~/.bash_profile

# Or target .bash_profile specifically
./scripts/claude-toolkit.sh install --shell=bash
```

#### Fish Shell Integration

**Issue**: Fish syntax different from bash/zsh

**Solution**:
```bash
# Install specifically for fish
./scripts/claude-toolkit.sh install --shell=fish

# Manually verify fish config
cat ~/.config/fish/config.fish
```

## Update and Validation Issues

### Repository Corruption

**Symptoms**:
```bash
[ERROR] Repository at ~/.local/share/claude-toolkit is invalid or corrupted
[ERROR] Not a git repository
```

**Solutions**:

1. **Automatic recovery** (update triggers reinstall):
   ```bash
   ./scripts/claude-toolkit.sh update
   ```

2. **Manual reinstall**:
   ```bash
   ./scripts/claude-toolkit.sh reinstall
   ```

3. **Manual cleanup and install**:
   ```bash
   rm -rf ~/.local/share/claude-toolkit
   ./scripts/claude-toolkit.sh install
   ```

### Git Operations Failing

**Symptoms**:
```bash
[ERROR] fatal: not a git repository
[ERROR] git pull failed
```

**Solutions**:

1. **Validate repository state**:
   ```bash
   ./scripts/claude-toolkit.sh validate --debug
   ```

2. **Check git repository manually**:
   ```bash
   cd ~/.local/share/claude-toolkit
   git status
   git log -1
   ```

3. **Reset repository**:
   ```bash
   cd ~/.local/share/claude-toolkit
   git reset --hard origin/main
   ```

4. **Force reinstall if needed**:
   ```bash
   ./scripts/claude-toolkit.sh reinstall
   ```

## Symlink Issues

### Broken Symlinks

**Symptoms**:
```bash
# Symlinks exist but point to wrong location
ls -la ~/.local/bin/claude-toolkit
# claude-toolkit -> ../share/claude-toolkit/scripts/claude-toolkit.sh (broken)
```

**Solutions**:

1. **Check symlink targets**:
   ```bash
   readlink ~/.local/bin/claude-toolkit
   ls -la ~/.local/bin/claude-*
   ```

2. **Recreate symlinks**:
   ```bash
   # Remove broken symlinks
   rm ~/.local/bin/claude-toolkit ~/.local/bin/claude-code ~/.local/bin/claude-slash
   
   # Reinstall to recreate
   ./scripts/claude-toolkit.sh install
   ```

### Symlink Permission Issues

**Symptoms**:
```bash
[ERROR] Failed to create symlink
[ERROR] Operation not permitted
```

**Solutions**:

1. **Check directory permissions**:
   ```bash
   ls -la ~/.local/bin/
   chmod 755 ~/.local/bin/
   ```

2. **Remove conflicting files**:
   ```bash
   # If regular files exist instead of symlinks
   rm ~/.local/bin/claude-toolkit
   ./scripts/claude-toolkit.sh install
   ```

## Argument Processing Issues

### Unknown Command Errors

**Symptoms**:
```bash
[ERROR] Unknown command: instal
[ERROR] Valid commands: install, uninstall, update
```

**Solutions**:

1. **Check command spelling**:
   ```bash
   # Correct command names
   ./scripts/claude-toolkit.sh install
   ./scripts/claude-toolkit.sh update
   ./scripts/claude-toolkit.sh uninstall
   ```

2. **Use help for syntax**:
   ```bash
   ./scripts/claude-toolkit.sh --help
   ```

### Invalid Option Values

**Symptoms**:
```bash
[ERROR] Unsupported shell: sh (supported: bash, zsh, fish)
[ERROR] --shell requires a value
```

**Solutions**:

1. **Use supported values**:
   ```bash
   ./scripts/claude-toolkit.sh install --shell=bash
   ./scripts/claude-toolkit.sh install --shell=zsh
   ./scripts/claude-toolkit.sh install --shell=fish
   ```

2. **Provide required values**:
   ```bash
   # Wrong: --shell without value
   # Correct: --shell=bash
   ./scripts/claude-toolkit.sh install --shell=bash
   ```

## Debug and Diagnostic Commands

### Basic Diagnostics

```bash
# Check installation status
./scripts/claude-toolkit.sh validate

# Check with debug output
./scripts/claude-toolkit.sh validate --debug

# Check specific components
ls -la ~/.local/bin/claude-*
ls -la ~/.local/share/claude-toolkit/
```

### Path and Environment Check

```bash
# Check PATH
echo $PATH | grep -E "(\.local/bin|claude)"

# Check which commands are available
which claude-toolkit claude-code claude-slash

# Check shell configuration
grep -n "claude-toolkit" ~/.zshrc ~/.bashrc ~/.config/fish/config.fish 2>/dev/null
```

### Network Diagnostics

```bash
# Test connectivity
ping -c 3 github.pie.apple.com

# Test SSH connection
ssh -T git@github.pie.apple.com

# Test git operations
cd ~/.local/share/claude-toolkit
git remote -v
git fetch --dry-run
```

### Repository Health Check

```bash
# Manual repository validation
cd ~/.local/share/claude-toolkit
git status
git log -1
git fsck

# Check file permissions
find ~/.local/share/claude-toolkit -name "*.sh" -not -perm -u+x
```

## Recovery Procedures

### Complete Recovery

When multiple issues exist:

```bash
# 1. Complete cleanup
./scripts/claude-toolkit.sh uninstall --yes 2>/dev/null || true
rm -rf ~/.local/share/claude-toolkit
rm -f ~/.local/bin/claude-*

# 2. Clean shell configurations manually
# Edit ~/.zshrc, ~/.bashrc, ~/.config/fish/config.fish
# Remove lines between ">>> claude-toolkit.sh start/end >>>"

# 3. Fresh installation
git clone git@github.pie.apple.com:AI-for-Devs-Community/claude-toolkit.git
cd claude-toolkit
./scripts/claude-toolkit.sh install

# 4. Verify
exec $SHELL -l
claude-toolkit validate
```

### Partial Recovery

For specific issues:

```bash
# Fix symlinks only
rm ~/.local/bin/claude-*
./scripts/claude-toolkit.sh install

# Fix repository only
rm -rf ~/.local/share/claude-toolkit
./scripts/claude-toolkit.sh install

# Fix shell config only
./scripts/claude-toolkit.sh uninstall --yes
./scripts/claude-toolkit.sh install
```

## Prevention

### Regular Maintenance

```bash
# Weekly validation
./scripts/claude-toolkit.sh validate

# Monthly updates
./scripts/claude-toolkit.sh update
```

### Backup Important Configurations

```bash
# Backup shell configurations before changes
cp ~/.zshrc ~/.zshrc.backup
cp ~/.bashrc ~/.bashrc.backup
cp ~/.config/fish/config.fish ~/.config/fish/config.fish.backup
```

### Environment Documentation

```bash
# Document your environment for troubleshooting
echo "Shell: $SHELL" > ~/toolkit-env.txt
echo "OS: $(uname -a)" >> ~/toolkit-env.txt
echo "PATH: $PATH" >> ~/toolkit-env.txt
ls -la ~/.local/bin/claude-* >> ~/toolkit-env.txt
```

## Getting Help

### Information to Provide

When reporting issues, include:

1. **Command that failed**:
   ```bash
   ./scripts/claude-toolkit.sh install --debug
   ```

2. **Environment information**:
   ```bash
   uname -a
   echo $SHELL
   echo $PATH
   ```

3. **Error output**:
   ```bash
   ./scripts/claude-toolkit.sh validate --debug 2>&1 | tee debug-output.log
   ```

4. **File states**:
   ```bash
   ls -la ~/.local/bin/claude-*
   ls -la ~/.local/share/claude-toolkit/
   ```

### Contact Information

- **Slack**: [#insights-platform-team](https://apple.enterprise.slack.com/archives/C021R2PFEJU)
- **Repository Issues**: Create issue with debug output
- **Internal Documentation**: Check Apple's Claude Code documentation

## Related Documentation

- **[Installation Guide](../installation.md)** - Complete setup instructions
- **[Argument Processing](argument-processing.md)** - Command-line syntax help
- **[Dry-Run Mode](dry-run.md)** - Testing without making changes
- **[Validate Command](validate.md)** - Installation verification
