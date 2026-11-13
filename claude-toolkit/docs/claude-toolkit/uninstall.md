# Uninstall Command

Remove Claude Toolkit installation and clean up all associated files.

## Syntax

```bash
./scripts/claude-toolkit.sh uninstall [options]
```

## Description

The `uninstall` command completely removes Claude Toolkit from the system by:

1. **Interactive Confirmation**: Prompts user to confirm removal (unless `--yes` used)
2. **Symlink Removal**: Removes all command symlinks from `~/.local/bin/`
3. **Repository Removal**: Deletes the toolkit repository from `~/.local/share/`
4. **Shell Configuration Cleanup**: Removes toolkit-specific configuration from shell RC files

This operation is reversible by reinstalling, but will require re-downloading the repository.

## Options

- `--yes, -y, --force` - Skip confirmation prompts (auto-accept)
- `--shell <shell>` - Target specific shell cleanup (bash, zsh, fish)
- `--dry-run` - Preview uninstallation without making changes
- `--debug` - Enable debug output
- `--help, -h` - Show help message

## Uninstallation Process

### 1. Installation Detection

First checks if toolkit is actually installed:

```bash
# Check for repository directory
test -d ~/.local/share/claude-toolkit

# Check for symlinks
test -L ~/.local/bin/claude-code
test -L ~/.local/bin/claude-slash
```

If nothing is found, reports that toolkit is not installed.

### 2. User Confirmation

Unless `--yes` flag is used, prompts for confirmation:

```bash
[WARNING] This will remove Claude Toolkit from your system.
Proceed with uninstall? [y/N]:
```

User must type 'y' or 'Y' to proceed. Any other response cancels the operation.

### 3. Component Removal

Removes components in safe order:

```bash
# Remove symlinks first (stops commands from working)
rm -f ~/.local/bin/claude-toolkit
rm -f ~/.local/bin/claude-code
rm -f ~/.local/bin/claude-slash

# Remove repository directory
rm -rf ~/.local/share/claude-toolkit
```

### 4. Shell Configuration Cleanup

Removes toolkit-specific configuration blocks from shell files:

**Removes these blocks**:
```bash
# >>> claude-toolkit.sh start >>>
# environment for claude-toolkit.sh
# <<< claude-toolkit.sh end <<<
```

**Preserves these blocks** (shared by other applications):
```bash
# >>> xdg-user-bin start >>>
# XDG user executables directory
export PATH="${XDG_BIN_DIR:-$HOME/.local/bin}:$PATH"
# <<< xdg-user-bin end <<<
```

## Examples

### Interactive Uninstall

```bash
./scripts/claude-toolkit.sh uninstall
```

Output:
```
[INFO] Uninstalling Claude Toolkit...
[WARNING] This will remove Claude Toolkit from your system.
Proceed with uninstall? [y/N]: y
[INFO] Proceeding with uninstall
[INFO] Removing claude-toolkit symlink...
[INFO] Removing claude-code symlink...
[INFO] Removing claude-slash symlink...
[INFO] Removing local repository...
[SUCCESS] Claude Toolkit uninstalled
```

### Automatic Uninstall

```bash
# Skip confirmation prompt
./scripts/claude-toolkit.sh uninstall --yes

# Alternative flags
./scripts/claude-toolkit.sh uninstall -y
./scripts/claude-toolkit.sh uninstall --force
```

Output:
```
[INFO] Uninstalling Claude Toolkit...
[INFO] Removing claude-toolkit symlink...
[INFO] Removing claude-code symlink...
[INFO] Removing claude-slash symlink...
[INFO] Removing local repository...
[SUCCESS] Claude Toolkit uninstalled
```

### Shell-Specific Uninstall

```bash
# Clean up only zsh configuration
./scripts/claude-toolkit.sh uninstall --shell=zsh --yes

# Clean up only bash configuration  
./scripts/claude-toolkit.sh uninstall --shell=bash --yes
```

### Development Uninstall

```bash
# Preview uninstall steps
./scripts/claude-toolkit.sh uninstall --dry-run
# Output: dryrun:uninstall_toolkit

# Uninstall with detailed debugging
./scripts/claude-toolkit.sh uninstall --debug --yes
```

## What Gets Removed

### Files and Directories

```bash
# Symlinks removed
~/.local/bin/claude-toolkit
~/.local/bin/claude-code
~/.local/bin/claude-slash

# Repository completely removed
~/.local/share/claude-toolkit/
├── scripts/
├── slash-commands/  
├── tests/
└── .git/
```

### Shell Configuration

**Removed from shell RC files**:
```bash
# >>> claude-toolkit.sh start >>>
# environment for claude-toolkit.sh
# <<< claude-toolkit.sh end <<<
```

**Preserved in shell RC files**:
```bash
# >>> xdg-user-bin start >>>
# XDG user executables directory
export PATH="${XDG_BIN_DIR:-$HOME/.local/bin}:$PATH"
# <<< xdg-user-bin end <<<
```

The XDG PATH configuration is preserved because other applications may also use `~/.local/bin/`.

## What Gets Preserved

### Other Installations

Uninstalling toolkit does not affect:

```bash
# Claude Code installations (managed separately)
~/.local/share/claude/

# Slash commands directory (may contain user commands)
~/.claude/commands/

# Other applications using ~/.local/bin/
~/.local/bin/other-tools
```

### User Data

User-created content is preserved:

- **Custom slash commands**: User-created commands in `~/.claude/commands/`
- **Shell customizations**: Other PATH entries and shell configuration
- **Other toolkit installations**: If multiple toolkit versions exist

## Uninstall Scenarios

### Clean Uninstall

When toolkit is properly installed:

```bash
./scripts/claude-toolkit.sh uninstall --yes
```

Removes all components cleanly and reports success.

### Partial Installation

When only some components exist:

```bash
# Maybe only symlinks exist but no repository
[INFO] Uninstalling Claude Toolkit...
[INFO] Removing claude-code symlink...
[INFO] Removing claude-slash symlink...
[SUCCESS] Claude Toolkit uninstalled
```

Cleans up whatever components are found.

### No Installation

When toolkit is not installed:

```bash
./scripts/claude-toolkit.sh uninstall
```

Output:
```
[WARNING] Claude Toolkit is not installed, so there's nothing to uninstall
```

### Corrupted Installation

Even if installation is corrupted, uninstall attempts cleanup:

```bash
# Removes whatever can be found
[INFO] Removing claude-toolkit symlink...
[INFO] Removing claude-code symlink...  
[INFO] Removing claude-slash symlink...
# Skips repository removal if directory doesn't exist
[SUCCESS] Claude Toolkit uninstalled
```

## Impact on Other Components

### Claude Code Installations

Uninstalling toolkit does NOT remove Claude Code:

```bash
# After toolkit uninstall, Claude Code still exists
ls ~/.local/share/claude/versions/
# 0.0.84/  0.0.85/

# But claude command becomes unavailable
claude --version
# bash: claude: command not found
```

To access Claude Code after toolkit removal, you need direct path:
```bash
~/.local/share/claude/current/bin/claude --version
```

### Slash Commands

Uninstalling toolkit does NOT remove slash commands directory:

```bash
# Slash commands directory preserved
ls ~/.claude/commands/
# smart-commit.md  add-command.md  my-custom-command.md

# But claude-slash command becomes unavailable
claude-slash list
# bash: claude-slash: command not found
```

### Shell Integration

After uninstall, shell integration changes:

```bash
# PATH still includes ~/.local/bin (for other tools)
echo $PATH
# /home/user/.local/bin:/usr/local/bin:/usr/bin:/bin

# But toolkit commands are no longer available
which claude-toolkit claude-code claude-slash
# (no output - commands not found)
```

## Reinstallation After Uninstall

### Complete Reinstallation

To reinstall after uninstall:

```bash
# Clone repository again
git clone git@github.pie.apple.com:AI-for-Devs-Community/claude-toolkit.git
cd claude-toolkit

# Install toolkit
./scripts/claude-toolkit.sh install

# Optionally reinstall other components
./scripts/claude-code.sh install
./scripts/claude-slash.sh install
```

### Quick Reinstallation

If you have the repository locally:

```bash
# From existing repository
./scripts/claude-toolkit.sh install
# Will clone to ~/.local/share/ and set up symlinks
```

## Troubleshooting

### Common Uninstall Issues

1. **Permission denied removing files**:
   ```bash
   [ERROR] Permission denied: ~/.local/share/claude-toolkit
   # Fix ownership and retry
   sudo chown -R $USER:$USER ~/.local/
   ./scripts/claude-toolkit.sh uninstall --yes
   ```

2. **Directory not empty errors**:
   ```bash
   # Some files may be in use or have special permissions
   # Force removal
   chmod -R u+w ~/.local/share/claude-toolkit
   ./scripts/claude-toolkit.sh uninstall --yes
   ```

3. **Shell configuration issues**:
   ```bash
   # If shell config cleanup fails, manual cleanup needed
   # Edit ~/.zshrc, ~/.bashrc, ~/.config/fish/config.fish
   # Remove lines between toolkit markers
   ```

### Manual Cleanup

If automatic uninstall fails, manual cleanup:

```bash
# Remove symlinks
rm -f ~/.local/bin/claude-toolkit
rm -f ~/.local/bin/claude-code
rm -f ~/.local/bin/claude-slash

# Remove repository
rm -rf ~/.local/share/claude-toolkit

# Manual shell cleanup
# Edit shell RC files and remove:
# # >>> claude-toolkit.sh start >>>
# # environment for claude-toolkit.sh  
# # <<< claude-toolkit.sh end <<<
```

### Verification After Uninstall

Confirm complete removal:

```bash
# Check symlinks removed
ls -la ~/.local/bin/claude-*
# ls: cannot access '~/.local/bin/claude-*': No such file or directory

# Check repository removed  
ls ~/.local/share/claude-toolkit
# ls: cannot access '~/.local/share/claude-toolkit': No such file or directory

# Check commands not available
which claude-toolkit claude-code claude-slash
# (no output)

# Check shell configuration
grep -n "claude-toolkit" ~/.zshrc
# (no output if properly cleaned)
```

## Security Considerations

### Clean Removal

Uninstall ensures clean removal:

- **No Residual Files**: All toolkit files completely removed
- **No Broken Symlinks**: All symlinks cleanly removed
- **No Configuration Pollution**: Shell configurations cleaned up

### Privacy

Uninstall preserves user privacy:

- **User Data Preserved**: Custom commands and settings preserved
- **No Data Transmission**: Uninstall is completely local operation
- **Audit Trail**: Debug mode shows exactly what is removed

## Related Commands

- **[`install`](install.md)** - Install toolkit (reverse of uninstall)
- **[`reinstall`](reinstall.md)** - Uninstall and install in one operation
- **[`validate`](validate.md)** - Check if uninstall is needed
- **[`update`](update.md)** - Alternative to uninstall/reinstall cycle
