# Install Command

Install Claude Toolkit infrastructure and shell integration.

## Syntax

```bash
./scripts/claude-toolkit.sh install [options]
```

## Description

The `install` command sets up the Claude Toolkit infrastructure by:

1. **Repository Setup**: Clones or validates the toolkit repository
2. **Symlink Creation**: Creates executable symlinks in `~/.local/bin/`
3. **Shell Integration**: Configures PATH and environment variables
4. **Validation**: Verifies successful installation

This is the foundational command that must be run before other toolkit components can be used.

## Options

- `--shell <shell>` - Target specific shell (bash, zsh, fish)
- `--https` - Use HTTPS git URLs instead of SSH
- `--dry-run` - Preview installation without making changes
- `--debug` - Enable debug output
- `--help, -h` - Show help message

## Installation Process

### 1. Repository Management

The installer handles repository setup intelligently:

```bash
# If running from a valid toolkit repository
# (common during development or first-time setup)
./scripts/claude-toolkit.sh install
# → Clones current repository to ~/.local/share/claude-toolkit/
# → Sets remote origin to Apple's internal GitHub
# → Pulls latest changes

# If running from downloaded script only
./scripts/claude-toolkit.sh install  
# → Clones directly from remote repository
```

### 2. Symlink Creation

Creates symlinks for easy command access:

```bash
~/.local/bin/claude-toolkit -> ../share/claude-toolkit/scripts/claude-toolkit.sh
~/.local/bin/claude-code -> ../share/claude-toolkit/scripts/claude-code.sh  
~/.local/bin/claude-slash -> ../share/claude-toolkit/scripts/claude-slash.sh
```

### 3. Shell Integration

Automatically configures shell environments:

**For bash** (Linux: `~/.bashrc`, macOS: `~/.bash_profile`):
```bash
# >>> claude-toolkit.sh start >>>
# environment for claude-toolkit.sh
# <<< claude-toolkit.sh end <<<

# >>> xdg-user-bin start >>>
# XDG user executables directory
export PATH="${XDG_BIN_DIR:-$HOME/.local/bin}:$PATH"
# <<< xdg-user-bin end <<<
```

**For zsh** (`~/.zshrc`):
```bash
# >>> claude-toolkit.sh start >>>
# environment for claude-toolkit.sh  
# <<< claude-toolkit.sh end <<<

# >>> xdg-user-bin start >>>
# XDG user executables directory
export PATH="${XDG_BIN_DIR:-$HOME/.local/bin}:$PATH"
# <<< xdg-user-bin end <<<
```

**For fish** (`~/.config/fish/config.fish`):
```fish
# >>> claude-toolkit.sh start >>>
# environment for claude-toolkit.sh
# <<< claude-toolkit.sh end <<<

# >>> xdg-user-bin start >>>  
# XDG user executables directory
if set -q XDG_BIN_DIR
    set -gx PATH "$XDG_BIN_DIR" $PATH
else
    set -gx PATH "$HOME/.local/bin" $PATH
end
# <<< xdg-user-bin end <<<
```

## Examples

### Basic Installation

```bash
# Install with automatic shell detection
./scripts/claude-toolkit.sh install
```

Output:
```
[INFO] Installing Claude Toolkit...
[INFO] Cloning Claude Toolkit repository...
[INFO] Creating symlink for claude-toolkit.sh...
[INFO] Creating symlink for claude-code.sh...
[INFO] Creating symlink for claude-slash.sh...
[INFO] Updating shell configs...
[SUCCESS] Claude Toolkit installed
[INFO] Validating Claude Toolkit...
[SUCCESS] Claude Toolkit validated, everything looks OK

Next Steps:

  1. Restart your shell or run:
     exec $SHELL -l

  2. Verify installation:
     claude-toolkit --help

  3. Basic usage:
     claude-code install      # Install Claude Code
     claude-code list         # List available Claude Code versions
     claude-slash install     # Install slash commands
     claude-slash list        # List slash commands
```

### Shell-Specific Installation

```bash
# Install for zsh only
./scripts/claude-toolkit.sh install --shell=zsh

# Install for bash only (useful in mixed environments)
./scripts/claude-toolkit.sh install --shell=bash

# Install for fish only
./scripts/claude-toolkit.sh install --shell=fish
```

### HTTPS Installation

When SSH access is not available:

```bash
# Use HTTPS for git operations
./scripts/claude-toolkit.sh install --https
```

This uses `https://github.pie.apple.com/AI-for-Devs-Community/claude-toolkit.git` instead of the default SSH URL.

### Development Installation

```bash
# Preview installation steps
./scripts/claude-toolkit.sh install --dry-run

# Install with detailed debugging
./scripts/claude-toolkit.sh install --debug
```

## Installation Validation

After installation, the toolkit automatically validates the setup:

1. **Repository Integrity**: Verifies git repository state
2. **Script Validation**: Checks that all scripts exist and are executable
3. **Symlink Verification**: Ensures symlinks point to correct locations

## Directory Structure

After successful installation:

```
~/.local/
├── bin/
│   ├── claude-toolkit -> ../share/claude-toolkit/scripts/claude-toolkit.sh
│   ├── claude-code -> ../share/claude-toolkit/scripts/claude-code.sh
│   └── claude-slash -> ../share/claude-toolkit/scripts/claude-slash.sh
└── share/
    └── claude-toolkit/
        ├── scripts/
        │   ├── claude-toolkit.sh
        │   ├── claude-code.sh
        │   ├── claude-slash.sh
        │   └── library.sh
        ├── slash-commands/
        ├── tests/
        └── .git/
```

## Error Handling

The installation process includes comprehensive error handling:

### Repository Access Issues

```bash
# SSH key problems
[ERROR] Failed to clone repository from git@github.pie.apple.com:AI-for-Devs-Community/claude-toolkit.git
[ERROR] Permission denied (publickey).
[INFO] Please check:
[INFO]   1. Internet/VPN connectivity
[INFO]   2. Access to Apple's internal GitHub
[INFO]   3. SSH key configuration
```

**Solution**: Use `--https` flag or configure SSH keys.

### Permission Issues

```bash
[ERROR] Failed to create directory: ~/.local/share
[INFO] Check file system permissions
```

**Solution**: Ensure user has write permissions to home directory.

### Existing Installation

```bash
[WARNING] Claude Toolkit is already installed
[INFO] If you want to update Claude Toolkit, invoke `./scripts/claude-toolkit.sh update`.
```

**Solution**: Use `update` or `reinstall` command instead.

## Post-Installation Steps

### 1. Shell Restart

**Required**: Restart your shell to activate new PATH configuration:

```bash
# Option 1: Restart shell
exec $SHELL -l

# Option 2: Source configuration manually
# For bash/zsh:
source ~/.zshrc  # or ~/.bashrc, ~/.bash_profile

# For fish:
source ~/.config/fish/config.fish
```

### 2. Verification

```bash
# Verify commands are available
which claude-toolkit claude-code claude-slash

# Test toolkit
claude-toolkit --help
claude-toolkit validate

# Check installation
ls -la ~/.local/bin/claude-*
ls -la ~/.local/share/claude-toolkit/
```

### 3. Install Additional Components

```bash
# Install Claude Code
claude-code install

# Install slash commands  
claude-slash install
```

## Reinstallation Behavior

If installation is run when already installed:

1. **Detection**: Recognizes existing installation
2. **Validation**: Checks repository integrity
3. **Recovery**: If corrupted, automatically triggers reinstallation
4. **Preservation**: If valid, preserves existing installation

## Integration with Development Workflow

### Team Setup

```bash
# Standard team installation script
#!/bin/bash
git clone git@github.pie.apple.com:AI-for-Devs-Community/claude-toolkit.git
cd claude-toolkit
./scripts/claude-toolkit.sh install --yes
exec $SHELL -l
echo "Toolkit installed successfully"
```

### CI/CD Integration

```bash
# Automated installation for CI environments
./scripts/claude-toolkit.sh install --yes --shell=bash
```

## Troubleshooting

### Common Issues

1. **Command not found after installation**
   - Restart shell: `exec $SHELL -l`
   - Manually check PATH: `echo $PATH`

2. **Permission denied errors**
   - Check directory permissions: `ls -la ~/.local/`
   - Ensure user ownership: `chown -R $USER:$USER ~/.local/`

3. **Repository clone failures**
   - Check VPN connection to Apple network
   - Verify SSH key access to GitHub
   - Try HTTPS installation: `--https`

4. **Shell configuration not working**
   - Manually verify shell config files were updated
   - Check for conflicting PATH entries
   - Try targeting specific shell: `--shell=zsh`

### Debug Output

Enable detailed debugging:

```bash
./scripts/claude-toolkit.sh install --debug
```

This provides comprehensive logging of all installation steps.

## Related Commands

- **[`update`](update.md)** - Update existing installation
- **[`validate`](validate.md)** - Verify installation integrity
- **[`reinstall`](reinstall.md)** - Force complete reinstallation
- **[`uninstall`](uninstall.md)** - Remove installation
