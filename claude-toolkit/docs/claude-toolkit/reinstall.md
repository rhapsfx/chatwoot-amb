# Reinstall Command

Force complete reinstallation of Claude Toolkit infrastructure.

## Syntax

```bash
./scripts/claude-toolkit.sh reinstall [options]
```

## Description

The `reinstall` command performs a complete fresh installation of Claude Toolkit, replacing any existing installation. It:

1. **Preserves Current Script**: Creates backup of current script in cache
2. **Uninstalls Existing**: Cleanly removes current installation
3. **Fresh Clone**: Downloads fresh copy from remote repository
4. **Complete Installation**: Performs full installation process

This command is useful when the installation is corrupted or you need to ensure a completely clean state.

## Options

- `--https` - Use HTTPS git URLs instead of SSH
- `--dry-run` - Preview reinstallation without making changes
- `--debug` - Enable debug output
- `--help, -h` - Show help message

## Reinstallation Process

### 1. Script Preservation

Before starting, the current script is preserved:

```bash
# Calculate repository hash for cache organization
repo_hash=$(echo "$remote_repository" | compute_checksum)

# Create cache directory
mkdir -p ~/.cache/claude-toolkit/$repo_hash/reinstall

# Copy current script and library to cache
cp /path/to/current/claude-toolkit.sh ~/.cache/claude-toolkit/$repo_hash/reinstall/
cp /path/to/current/library.sh ~/.cache/claude-toolkit/$repo_hash/reinstall/
```

### 2. Execution Handoff

The reinstall process executes from the cached copy:

```bash
# Execute the preserved script with _reinstall command
exec ~/.cache/claude-toolkit/$repo_hash/reinstall/claude-toolkit.sh _reinstall --remote-repository "$remote_repository"
```

This ensures the reinstallation continues even if the original script is removed.

### 3. Clean Removal

The cached script performs clean removal:

```bash
# Remove symlinks
rm -f ~/.local/bin/claude-toolkit
rm -f ~/.local/bin/claude-code  
rm -f ~/.local/bin/claude-slash

# Remove repository
rm -rf ~/.local/share/claude-toolkit

# Clean shell configurations
# (removes toolkit-specific blocks from shell RC files)
```

### 4. Fresh Installation

Downloads and installs fresh copy:

```bash
# Clone fresh repository to cache
git clone "$remote_repository" ~/.cache/claude-toolkit/$repo_hash/install

# Execute installation from fresh copy
exec ~/.cache/claude-toolkit/$repo_hash/install/scripts/claude-toolkit.sh install
```

## Examples

### Basic Reinstallation

```bash
./scripts/claude-toolkit.sh reinstall
```

Output:
```
[INFO] Reinstalling Claude Toolkit...
[INFO] Uninstalling Claude Toolkit...
[INFO] Removing claude-toolkit symlink...
[INFO] Removing claude-code symlink...
[INFO] Removing claude-slash symlink...
[INFO] Removing local repository...
[SUCCESS] Claude Toolkit uninstalled
[INFO] Cloning Claude Toolkit repository into cache directory
Cloning into '~/.cache/claude-toolkit/a1b2c3d4/install'...
remote: Enumerating objects: 1234, done.
remote: Counting objects: 100% (1234/1234), done.
remote: Compressing objects: 100% (567/567), done.
remote: Total 1234 (delta 456), reused 890 (delta 234), pack-reused 0
Receiving objects: 100% (1234/1234), 2.34 MiB | 5.67 MiB/s, done.
Resolving deltas: 100% (456/456), done.
[INFO] Installing Claude Toolkit...
# ... (continues with normal installation) ...
[SUCCESS] Claude Toolkit installed
```

### HTTPS Reinstallation

```bash
./scripts/claude-toolkit.sh reinstall --https
```

This uses HTTPS for all git operations during reinstallation.

### Development Reinstallation

```bash
# Preview reinstallation steps
./scripts/claude-toolkit.sh reinstall --dry-run

# Reinstall with detailed debugging  
./scripts/claude-toolkit.sh reinstall --debug
```

## When to Use Reinstall

### Repository Corruption

When validation fails due to repository issues:

```bash
[ERROR] Repository at ~/.local/share/claude-toolkit is invalid or corrupted
[ERROR] fatal: not a git repository
```

**Solution**: Use reinstall to start fresh:
```bash
./scripts/claude-toolkit.sh reinstall
```

### Broken Installation

When multiple components are broken:

```bash
# Multiple validation failures
[ERROR] File not found: ~/.local/share/claude-toolkit/scripts/claude-code.sh
[ERROR] File is not executable: ~/.local/share/claude-toolkit/scripts/claude-slash.sh
```

**Solution**: Reinstall ensures all components are properly restored.

### Permission Issues

When ownership or permissions are corrupted:

```bash
# Permission denied errors
[ERROR] Failed to create directory: ~/.local/share/claude-toolkit
[ERROR] Permission denied
```

**Solution**: Reinstall with proper ownership:
```bash
./scripts/claude-toolkit.sh reinstall
```

### Clean State Required

When you need to ensure completely clean installation:

```bash
# For troubleshooting or testing
./scripts/claude-toolkit.sh reinstall

# To reset to known good state
./scripts/claude-toolkit.sh reinstall
```

## Reinstall vs Other Commands

### Reinstall vs Update

| Reinstall | Update |
|-----------|--------|
| Complete fresh installation | Incremental changes only |
| Removes all existing files | Preserves existing files |
| Downloads entire repository | Downloads only changes |
| Slower but comprehensive | Faster but preserves issues |

### Reinstall vs Install

| Reinstall | Install |
|-----------|---------|
| Forces replacement of existing | Preserves existing if valid |
| Always downloads fresh copy | May use existing repository |
| Removes before installing | Installs alongside existing |

## Cache Management

### Cache Directory Structure

Reinstall uses organized cache structure:

```
~/.cache/claude-toolkit/
└── $repo_hash/
    ├── reinstall/
    │   ├── claude-toolkit.sh  # Preserved current script
    │   └── library.sh         # Preserved library
    └── install/
        └── # Fresh repository clone
```

### Cache Benefits

1. **Isolation**: Each repository URL gets separate cache
2. **Safety**: Current script preserved during process
3. **Recovery**: Failed reinstalls don't lose current script
4. **Performance**: Cached scripts available for debugging

### Cache Cleanup

Cache is automatically managed:

- **Old Caches**: Automatically overwritten on new reinstalls
- **Failed Installs**: Cleaned up automatically
- **Manual Cleanup**: Can be safely removed:
  ```bash
  rm -rf ~/.cache/claude-toolkit/
  ```

## Safety Features

### Script Preservation

The reinstall process preserves the currently executing script:

1. **Never Removes Active Script**: Current script copied to cache before removal
2. **Continues Execution**: Process continues from cached copy
3. **Rollback Possible**: Original script available if reinstall fails

### Atomic Operations

Reinstallation is designed to be atomic:

1. **Complete Removal**: Old installation completely removed before new installation
2. **All or Nothing**: Either completely succeeds or fails cleanly
3. **No Partial States**: Never leaves system in partially installed state

### Error Recovery

If reinstall fails:

1. **Current Script Preserved**: Original script still available in cache
2. **Clean Failure**: System left in clean uninstalled state
3. **Manual Recovery**: Can run original script from cache if needed

## Performance Considerations

### Network Usage

Reinstall downloads entire repository:

- **Full Clone**: Downloads complete repository (larger than update)
- **Fresh Copy**: Ensures no local corruption issues
- **Network Required**: Requires stable internet connection

### Time Requirements

Reinstall takes longer than other operations:

- **Complete Process**: Uninstall + download + install
- **Network Dependent**: Speed depends on connection
- **Validation Included**: Full validation after installation

### Disk Usage

Temporary disk usage during reinstall:

- **Cache Directory**: Additional copy in cache
- **Temporary Overlap**: Brief period with multiple copies
- **Cleanup**: Cache can be cleaned after completion

## Integration Points

### Automatic Triggering

Reinstall is automatically triggered by other commands:

```bash
# Update command triggers reinstall if repository is corrupted
./scripts/claude-toolkit.sh update
# → Detects corruption
# → Automatically runs reinstall

# Install command triggers reinstall if existing installation is invalid  
./scripts/claude-toolkit.sh install
# → Detects invalid existing installation
# → Automatically runs reinstall
```

### Manual Triggering

Use reinstall when you need guaranteed clean state:

```bash
# Force clean reinstallation
./scripts/claude-toolkit.sh reinstall

# Reinstall with specific options
./scripts/claude-toolkit.sh reinstall --https --debug
```

## Troubleshooting

### Common Reinstall Issues

1. **Network connectivity problems**:
   ```bash
   [ERROR] Failed to clone repository from git@github.pie.apple.com:...
   # Solution: Check VPN, try --https option
   ./scripts/claude-toolkit.sh reinstall --https
   ```

2. **Permission errors during removal**:
   ```bash
   [ERROR] Failed to remove directory: ~/.local/share/claude-toolkit
   # Solution: Fix permissions and retry
   sudo chown -R $USER:$USER ~/.local/
   ./scripts/claude-toolkit.sh reinstall
   ```

3. **Cache directory issues**:
   ```bash
   [ERROR] Failed to create cache directory
   # Solution: Clear cache and retry
   rm -rf ~/.cache/claude-toolkit/
   ./scripts/claude-toolkit.sh reinstall
   ```

4. **Authentication failures**:
   ```bash
   [ERROR] Permission denied (publickey)
   # Solution: Check SSH keys or use HTTPS
   ./scripts/claude-toolkit.sh reinstall --https
   ```

### Recovery Procedures

If reinstall fails partway through:

1. **Check Error Message**: Identify specific failure point
2. **Fix Root Cause**: Address network, permissions, or authentication
3. **Retry Reinstall**: Run command again
4. **Manual Recovery**: If needed, run from cache:
   ```bash
   ~/.cache/claude-toolkit/$hash/reinstall/claude-toolkit.sh install
   ```

### Debug Information

For troubleshooting reinstall issues:

```bash
./scripts/claude-toolkit.sh reinstall --debug
```

This provides detailed information about:
- Cache operations
- Uninstallation steps
- Repository cloning
- Installation process
- Error details

## Related Commands

- **[`install`](install.md)** - Initial installation (may trigger reinstall)
- **[`update`](update.md)** - Incremental updates (may trigger reinstall)
- **[`validate`](validate.md)** - Verify installation (helps determine if reinstall needed)
- **[`uninstall`](uninstall.md)** - Remove installation
