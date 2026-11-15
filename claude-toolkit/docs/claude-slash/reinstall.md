# Reinstall Command

Reinstall Claude Code slash commands with fresh download from the repository HEAD, replacing existing toolkit commands while preserving user-created commands.

## Overview

The `reinstall` command performs a clean removal and fresh installation of toolkit slash commands from the repository HEAD. This operation is useful for getting the latest command updates, fixing corrupted installations, or resolving conflicts while preserving user-created commands.

## Basic Usage

```bash
# Reinstall all toolkit commands
./scripts/claude-slash.sh reinstall

# Reinstall with verbose output
./scripts/claude-slash.sh reinstall --verbose

# Preview reinstall without changes
./scripts/claude-slash.sh reinstall --dry-run

# Skip confirmation prompts
./scripts/claude-slash.sh reinstall --yes
```

## Command Syntax

```bash
./scripts/claude-slash.sh reinstall [options]
```

### Core Options

| Option | Description |
|--------|-------------|
| `--reinstall` | Perform reinstall operation |
| `--verbose` | Show detailed reinstall progress and diagnostic information |
| `--dry-run` | Preview reinstall operation without making system modifications |
| `--yes`, `-y`, `--force` | Skip confirmation prompts and auto-accept |

## Reinstall Process

### 1. Pre-Reinstall Assessment

The system analyzes the current installation:
- **Current Commands**: Identifies installed toolkit and user commands
- **Backup Planning**: Catalogs user commands for preservation
- **Conflict Detection**: Identifies potential naming conflicts
- **Repository Access**: Verifies connection to toolkit repository

### 2. User Command Preservation

Protects user-created commands during reinstall:
- **User Command Backup**: Creates temporary backups of user commands
- **Conflict Resolution**: Renames conflicting user commands if necessary
- **Metadata Preservation**: Maintains user command metadata and permissions

### 1. Toolkit Command Removal

Cleanly removes existing toolkit commands:
- **Selective Removal**: Removes only toolkit commands, preserving user commands
- **Complete Cleanup**: Ensures no orphaned or corrupted toolkit command files
- **Validation**: Verifies successful removal before proceeding

### 2. Fresh Installation

Downloads and installs latest toolkit commands:
- **Repository Sync**: Fetches latest command definitions from HEAD
- **Command Installation**: Installs all current toolkit commands
- **File Validation**: Verifies integrity of newly installed commands
- **Permission Setup**: Ensures proper file permissions and accessibility

### 5. User Command Restoration

Restores preserved user commands:
- **Conflict Resolution**: Handles any naming conflicts with new toolkit commands
- **Metadata Restoration**: Restores user command metadata
- **Integration Validation**: Ensures user commands work with new toolkit commands

### 6. Installation Verification

Validates successful reinstall:
- **Command Availability**: Verifies all commands are accessible to Claude Code
- **Syntax Validation**: Checks command file syntax and structure
- **Integration Testing**: Confirms commands integrate properly with Claude Code

## Use Cases

### Get Latest Updates

Update toolkit commands to the latest versions:
```bash
# Check current installation
./scripts/claude-slash.sh list toolkit-only
add-command.md
smart-commit.md
review-codebase.md

# Get latest updates
./scripts/claude-slash.sh reinstall --verbose
# [INFO] Downloading latest command definitions from repository HEAD
# [SUCCESS] Reinstalled 5 toolkit commands with latest updates
```

### Fix Corrupted Installation

Repair damaged or corrupted command installations:
```bash
# Identify corruption
claude
# /smart-commit
# Error: Command file corrupted or malformed

# Fix with reinstall
./scripts/claude-slash.sh reinstall
# [INFO] Removing corrupted toolkit commands
# [INFO] Installing fresh command definitions
# [SUCCESS] Toolkit commands reinstalled successfully
```

### Resolve Command Conflicts

Fix conflicts between toolkit and user commands:
```bash
# Conflict detected during updates
./scripts/claude-slash.sh list
smart-commit.md (user)    # User created conflicting command
smart-commit.md (toolkit) # Toolkit also has this command

# Resolve with reinstall
./scripts/claude-slash.sh reinstall
# [WARNING] User command conflicts with toolkit command: smart-commit.md
# [INFO] Renaming user command to: smart-commit-user.md
# [INFO] Installing toolkit command: smart-commit.md
```

### Development Environment Refresh

Reset command environment to known good state:
```bash
# Complete command environment refresh
./scripts/claude-slash.sh reinstall --verbose
# [VERBOSE] Backing up user commands: my-helper.md, project-setup.md
# [VERBOSE] Removing toolkit commands: 5 commands
# [VERBOSE] Installing fresh toolkit commands from HEAD
# [VERBOSE] Restoring user commands: my-helper.md, project-setup.md
# [SUCCESS] Command environment refreshed successfully
```

## Reinstall Behavior

### Mixed Environment (Toolkit + User Commands)

When both toolkit and user commands exist:
```bash
$ ./scripts/claude-slash.sh list
add-command.md (toolkit)
my-helper.md (user)
smart-commit.md (toolkit)
project-setup.md (user)

$ ./scripts/claude-slash.sh reinstall
[INFO] Found 2 user commands - preserving during reinstall
[INFO] Removing 2 toolkit commands for fresh installation
[INFO] Installing latest toolkit commands from repository
[SUCCESS] Reinstalled toolkit commands, preserved user commands

$ ./scripts/claude-slash.sh list
add-command.md (toolkit)      # Fresh from repository
my-helper.md (user)           # Preserved
smart-commit.md (toolkit)     # Fresh from repository
project-setup.md (user)       # Preserved
quick-commit.md (toolkit)     # New command added in repository
```

### Toolkit Only Environment

When only toolkit commands exist:
```bash
$ ./scripts/claude-slash.sh list toolkit-only
add-command.md
smart-commit.md
review-codebase.md

$ ./scripts/claude-slash.sh reinstall --verbose
[VERBOSE] No user commands found - simple toolkit reinstall
[VERBOSE] Removing 3 existing toolkit commands
[VERBOSE] Installing latest toolkit commands from HEAD
[SUCCESS] Reinstalled 5 toolkit commands (2 new commands added)
```

### First Time After Manual Installation

When commands were manually installed or corrupted:
```bash
$ ./scripts/claude-slash.sh reinstall
[INFO] Detecting existing command environment
[WARNING] Found commands without proper installation metadata
[INFO] Treating unidentified commands as user commands
[INFO] Proceeding with toolkit installation
```

## Conflict Resolution

### Automatic Conflict Handling

When user commands conflict with new toolkit commands:

**User Command Renaming**:
```bash
# Before reinstall
$ ./scripts/claude-slash.sh list
smart-commit.md (user)

# During reinstall
$ ./scripts/claude-slash.sh reinstall
[WARNING] User command 'smart-commit.md' conflicts with toolkit command
[INFO] Renaming user command to 'smart-commit-user.md'
[INFO] Installing toolkit command 'smart-commit.md'

# After reinstall
$ ./scripts/claude-slash.sh list
smart-commit.md (toolkit)      # New toolkit command
smart-commit-user.md (user)    # Renamed user command
```

**Interactive Conflict Resolution** (with --verbose):
```bash
$ ./scripts/claude-slash.sh reinstall --verbose
[VERBOSE] Conflict detected: smart-commit.md
[VERBOSE] User command created: 2024-01-10 14:22:10
[VERBOSE] Toolkit command available: 2024-01-15 10:30:25
[VERBOSE] Resolution: Renaming user command to preserve both versions
```

## Advanced Usage

### Forced Reinstall

Force reinstall even when no changes are detected:
```bash
# Force fresh installation regardless of state
./scripts/claude-slash.sh reinstall --force
```

### Verbose Operation

Get detailed information during reinstall:
```bash
./scripts/claude-slash.sh reinstall --verbose
# [VERBOSE] Analyzing current command installation
# [VERBOSE] Found 3 toolkit commands, 2 user commands
# [VERBOSE] Creating backup of user commands
# [VERBOSE] Removing toolkit command: add-command.md
# [VERBOSE] Removing toolkit command: smart-commit.md
# [VERBOSE] Removing toolkit command: review-codebase.md
# [VERBOSE] Downloading latest commands from repository
# [VERBOSE] Installing toolkit command: add-command.md
# [VERBOSE] Installing toolkit command: smart-commit.md
# [VERBOSE] Installing toolkit command: review-codebase.md
# [VERBOSE] Installing toolkit command: quick-commit.md (new)
# [VERBOSE] Installing toolkit command: solid-analysis.md (new)
# [VERBOSE] Restoring user commands
# [SUCCESS] Reinstall completed: 5 toolkit commands, 2 user commands
```

### Automated Reinstall

Skip confirmations for scripted environments:
```bash
# Non-interactive reinstall
./scripts/claude-slash.sh reinstall --yes --verbose
```

## Error Scenarios and Troubleshooting

### Repository Access Issues

**Network Connectivity**:
```bash
$ ./scripts/claude-slash.sh reinstall
[ERROR] Cannot access repository: network unreachable
[INFO] Reinstall requires network access to download latest commands
```
*Solutions*:
1. Check internet/VPN connectivity
2. Verify corporate firewall allows git access
3. Test repository access: `git ls-remote git@github.pie.apple.com:AI-for-Devs-Community/claude-code-toolkit.git`

**Authentication Failed**:
```bash
$ ./scripts/claude-slash.sh reinstall
[ERROR] Repository authentication failed
```
*Solutions*:
1. Configure SSH keys for Apple GitHub
2. Test authentication: `ssh -T git@github.pie.apple.com`
3. Verify VPN connection if required

### File System Issues

**Permission Denied**:
```bash
$ ./scripts/claude-slash.sh reinstall
[ERROR] Permission denied: Cannot write to ~/.claude/commands/
```
*Solutions*:
1. Check directory permissions: `ls -la ~/.claude/commands/`
2. Fix permissions: `chmod 755 ~/.claude/commands/`
3. Verify disk space availability

**Backup Failure**:
```bash
$ ./scripts/claude-slash.sh reinstall
[ERROR] Failed to backup user commands
[WARNING] Reinstall aborted to prevent data loss
```
*Solutions*:
1. Manually backup user commands: `cp ~/.claude/commands/*.md ~/backup/`
2. Check available disk space
3. Retry after resolving space issues

### Command Validation Issues

**Corrupted Download**:
```bash
$ ./scripts/claude-slash.sh reinstall
[ERROR] Downloaded command file failed validation: smart-commit.md
```
*Solutions*:
1. Check network stability during download
2. Verify repository integrity
3. Retry installation: `./scripts/claude-slash.sh reinstall --force`

**Integration Failure**:
```bash
$ ./scripts/claude-slash.sh reinstall
[WARNING] Command integration test failed for: new-command.md
[INFO] Command installed but may not function properly
```
*Solutions*:
1. Test command manually in Claude Code
2. Report issue to toolkit maintainers
3. Check Claude Code compatibility

## Command Lifecycle During Reinstall

1. **Assessment Phase**
   - Analyze current installation
   - Identify toolkit vs user commands
   - Check repository accessibility

2. **Backup Phase**
   - Create user command backups
   - Prepare conflict resolution plans
   - Validate backup integrity

3. **Removal Phase**
   - Remove existing toolkit commands
   - Clean up orphaned files
   - Prepare for fresh installation

4. **Download Phase**
   - Fetch latest repository state
   - Download command definitions
   - Validate downloaded files

5. **Installation Phase**
   - Install toolkit commands
   - Apply proper permissions
   - Generate command metadata

6. **Restoration Phase**
   - Restore user commands
   - Resolve any conflicts
   - Verify final installation

## Security Considerations

### Repository Integrity

Security measures during reinstall:
- **Source Verification**: Only downloads from official toolkit repository
- **Content Validation**: Validates command file integrity
- **Permission Management**: Sets appropriate file permissions

### User Command Protection

Safety measures for user commands:
- **Automatic Backup**: Creates backups before any modifications
- **Conflict Resolution**: Preserves user commands through naming conflicts
- **Rollback Capability**: Can restore previous state if reinstall fails

## Performance Notes

- **Network Dependent**: Requires network access for repository operations
- **Incremental Updates**: Only downloads changed files when possible
- **Parallel Operations**: Can download multiple commands concurrently
- **Local Caching**: Leverages git caching for improved performance

## Integration with Other Commands

Reinstall works with other slash command operations:

```bash
# Maintenance workflow
./scripts/claude-slash.sh list               # Check current state
./scripts/claude-slash.sh reinstall          # Get latest updates
./scripts/claude-slash.sh list --verbose     # Verify results

# Development workflow
./scripts/claude-slash.sh reinstall          # Update commands
./scripts/claude-slash.sh list toolkit-only  # Verify toolkit commands
# Test new commands in Claude Code
```

## Rollback Considerations

### Current Behavior

The current implementation provides basic safety:
- User commands are preserved and restored
- Failed installations leave system in previous state
- Error recovery maintains user command integrity

### Future Enhancements

Planned rollback capabilities:
- **Snapshot Creation**: Create full snapshots before reinstall
- **Selective Rollback**: Roll back individual commands if needed
- **Version History**: Maintain history of toolkit command versions

## Related Commands

- [`--install`](install.md) - Install slash commands from toolkit repository
- [`--list`](list.md) - View installed slash commands
- [`--uninstall`](uninstall.md) - Remove toolkit slash commands
- [`claude-code --reinstall`](../claude-code/reinstall.md) - Reinstall Claude Code runtime
