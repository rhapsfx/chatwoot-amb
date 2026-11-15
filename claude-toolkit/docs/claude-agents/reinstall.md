# Reinstall Command

Reinstall Claude Code subagents with fresh download from the repository HEAD, replacing existing toolkit subagents while preserving user-created subagents.

## Overview

The `reinstall` command performs a clean removal and fresh installation of toolkit subagents from the repository HEAD. This operation is useful for getting the latest subagent updates, fixing corrupted installations, or resolving conflicts while preserving user-created subagents.

## Basic Usage

```bash
# Reinstall subagents from all configured sources
claude-agents reinstall

# Reinstall from specific source
claude-agents reinstall --source claude-toolkit

# Reinstall with debug output
claude-agents reinstall --debug

# Preview reinstall without changes
claude-agents reinstall --dry-run

# Skip confirmation prompts
claude-agents reinstall --yes
```

## Command Syntax

```bash
claude-agents reinstall [options]
```

### Core Options

| Option | Description |
|--------|-------------|
| `--source <sources>` | Reinstall from specific source(s). Can be source name, comma-separated list, or "all" (default: all) |
| `--debug` | Enable debug output (verbose logging) |
| `--dry-run` | Preview reinstall operation without making system modifications |
| `--porcelain` | Machine-readable output format |
| `--yes`, `-y`, `--force` | Skip confirmation prompts and auto-accept |

## Reinstall Process

### 1. Pre-Reinstall Assessment

The system analyzes the current installation:
- **Current Subagents**: Identifies installed toolkit and user subagents
- **Backup Planning**: Catalogs user subagents for preservation
- **Conflict Detection**: Identifies potential naming conflicts
- **Repository Access**: Verifies connection to toolkit repository

### 2. User Subagent Preservation

Protects user-created subagents during reinstall:
- **User Subagent Backup**: Creates temporary backups of user subagents
- **Conflict Resolution**: Renames conflicting user subagents if necessary
- **Metadata Preservation**: Maintains user subagent metadata and permissions

### 3. Toolkit Subagent Removal

Cleanly removes existing toolkit subagents:
- **Selective Removal**: Removes only toolkit subagents, preserving user subagents
- **Complete Cleanup**: Ensures no orphaned or corrupted toolkit subagent files
- **Validation**: Verifies successful removal before proceeding

### 4. Fresh Installation

Downloads and installs latest toolkit subagents:
- **Repository Sync**: Fetches latest subagent definitions from HEAD
- **Subagent Installation**: Installs all current toolkit subagents
- **File Validation**: Verifies integrity of newly installed subagents
- **Permission Setup**: Ensures proper file permissions and accessibility

### 5. User Subagent Restoration

Restores preserved user subagents:
- **Conflict Resolution**: Handles any naming conflicts with new toolkit subagents
- **Metadata Restoration**: Restores user subagent metadata
- **Integration Validation**: Ensures user subagents work with new toolkit subagents

### 6. Installation Verification

Validates successful reinstall:
- **Subagent Availability**: Verifies all subagents are accessible to Claude Code
- **Syntax Validation**: Checks subagent file syntax and structure
- **Integration Testing**: Confirms subagents integrate properly with Claude Code

## Use Cases

### Get Latest Updates

Update toolkit subagents to the latest versions:
```bash
# Check current installation
claude-agents list --source claude-toolkit
architect.md (claude-toolkit)
test-writer-debugger.md (claude-toolkit)
statusline-setup.md (claude-toolkit)

# Get latest updates
claude-agents reinstall --debug
# [INFO] Downloading latest subagent definitions from repository HEAD
# [SUCCESS] Reinstalled 4 toolkit subagents with latest updates
```

### Fix Corrupted Installation

Repair damaged or corrupted subagent installations:
```bash
# Identify corruption through Task tool errors
# Error: Subagent file corrupted or malformed

# Fix with reinstall
claude-agents reinstall
# [INFO] Removing corrupted toolkit subagents
# [INFO] Installing fresh subagent definitions
# [SUCCESS] Toolkit subagents reinstalled successfully
```

### Resolve Subagent Conflicts

Fix conflicts between toolkit and user subagents:
```bash
# Conflict detected during updates
claude-agents list
architect.md (user)    # User created conflicting subagent
architect.md (toolkit) # Toolkit also has this subagent

# Resolve with reinstall
claude-agents reinstall
# [WARNING] User subagent conflicts with toolkit subagent: architect.md
# [INFO] Renaming user subagent to: architect-user.md
# [INFO] Installing toolkit subagent: architect.md
```

### Development Environment Refresh

Reset subagent environment to known good state:
```bash
# Complete subagent environment refresh
claude-agents reinstall --debug
# [DEBUG] Backing up user subagents: my-reviewer.md, workflow-helper.md
# [DEBUG] Removing toolkit subagents: 4 subagents
# [DEBUG] Installing fresh toolkit subagents from HEAD
# [DEBUG] Restoring user subagents: my-reviewer.md, workflow-helper.md
# [SUCCESS] Subagent environment refreshed successfully
```

## Reinstall Behavior

### Mixed Environment (Toolkit + User Subagents)

When both toolkit and user subagents exist:
```bash
$ claude-agents list
architect.md (claude-toolkit)
my-reviewer.md (user)
test-writer-debugger.md (claude-toolkit)
workflow-helper.md (user)

$ claude-agents reinstall
[INFO] Found 2 user subagents - preserving during reinstall
[INFO] Removing 2 toolkit subagents for fresh installation
[INFO] Installing latest toolkit subagents from repository
[SUCCESS] Reinstalled toolkit subagents, preserved user subagents

$ claude-agents list
architect.md (claude-toolkit)      # Fresh from repository
my-reviewer.md (user)              # Preserved
test-writer-debugger.md (claude-toolkit)  # Fresh from repository
workflow-helper.md (user)          # Preserved
output-style-setup.md (claude-toolkit)    # New subagent added in repository
```

### Toolkit Only Environment

When only toolkit subagents exist:
```bash
$ claude-agents list --source claude-toolkit
architect.md (claude-toolkit)
test-writer-debugger.md (claude-toolkit)
statusline-setup.md (claude-toolkit)

$ claude-agents reinstall --debug
[DEBUG] No user subagents found - simple toolkit reinstall
[DEBUG] Removing 3 existing toolkit subagents
[DEBUG] Installing latest toolkit subagents from HEAD
[SUCCESS] Reinstalled 4 toolkit subagents (1 new subagent added)
```

### First Time After Manual Installation

When subagents were manually installed or corrupted:
```bash
$ claude-agents reinstall
[INFO] Detecting existing subagent environment
[WARNING] Found subagents without proper installation metadata
[INFO] Treating unidentified subagents as user subagents
[INFO] Proceeding with toolkit installation
```

## Conflict Resolution

### Automatic Conflict Handling

When user subagents conflict with new toolkit subagents:

**User Subagent Renaming**:
```bash
# Before reinstall
$ claude-agents list
architect.md (user)

# During reinstall
$ claude-agents reinstall
[WARNING] User subagent 'architect.md' conflicts with toolkit subagent
[INFO] Renaming user subagent to 'architect-user.md'
[INFO] Installing toolkit subagent 'architect.md'

# After reinstall
$ claude-agents list
architect.md (claude-toolkit)      # New toolkit subagent
architect-user.md (user)           # Renamed user subagent
```

**Interactive Conflict Resolution** (with --debug):
```bash
$ claude-agents reinstall --debug
[DEBUG] Conflict detected: architect.md
[DEBUG] User subagent created: 2024-01-10 14:22:10
[DEBUG] Toolkit subagent available: 2024-01-15 10:30:25
[DEBUG] Resolution: Renaming user subagent to preserve both versions
```

## Advanced Usage

### Forced Reinstall

Force reinstall even when no changes are detected:
```bash
# Force fresh installation regardless of state
claude-agents reinstall --force
```

### Debug Operation

Get detailed information during reinstall:
```bash
claude-agents reinstall --debug
# [DEBUG] Analyzing current subagent installation
# [DEBUG] Found 3 toolkit subagents, 2 user subagents
# [DEBUG] Creating backup of user subagents
# [DEBUG] Removing toolkit subagent: architect.md
# [DEBUG] Removing toolkit subagent: test-writer-debugger.md
# [DEBUG] Removing toolkit subagent: statusline-setup.md
# [DEBUG] Downloading latest subagents from repository
# [DEBUG] Installing toolkit subagent: architect.md
# [DEBUG] Installing toolkit subagent: test-writer-debugger.md
# [DEBUG] Installing toolkit subagent: statusline-setup.md
# [DEBUG] Installing toolkit subagent: output-style-setup.md (new)
# [DEBUG] Restoring user subagents
# [SUCCESS] Reinstall completed: 4 toolkit subagents, 2 user subagents
```

### Automated Reinstall

Skip confirmations for scripted environments:
```bash
# Non-interactive reinstall
claude-agents reinstall --yes --debug
```

### Porcelain Mode

Get machine-readable output:
```bash
claude-agents reinstall --porcelain
# claude-toolkit	/path/to/architect.md	success	
# claude-toolkit	/path/to/test-writer.md	success
# user	/path/to/my-agent.md	skip	user subagent preserved
```

## Error Scenarios and Troubleshooting

### Repository Access Issues

**Network Connectivity**:
```bash
$ claude-agents reinstall
[ERROR] Cannot access repository: network unreachable
[INFO] Reinstall requires network access to download latest subagents
```
*Solutions*:
1. Check internet/VPN connectivity
2. Verify corporate firewall allows git access
3. Test repository access: `git ls-remote <repository-url>`

**Authentication Failed**:
```bash
$ claude-agents reinstall
[ERROR] Repository authentication failed
```
*Solutions*:
1. Configure SSH keys for repository access
2. Test authentication: `ssh -T git@github.com`
3. Verify VPN connection if required

### File System Issues

**Permission Denied**:
```bash
$ claude-agents reinstall
[ERROR] Permission denied: Cannot write to ~/.claude/agents/
```
*Solutions*:
1. Check directory permissions: `ls -la ~/.claude/agents/`
2. Fix permissions: `chmod 755 ~/.claude/agents/`
3. Verify disk space availability

**Backup Failure**:
```bash
$ claude-agents reinstall
[ERROR] Failed to backup user subagents
[WARNING] Reinstall aborted to prevent data loss
```
*Solutions*:
1. Manually backup user subagents: `cp ~/.claude/agents/*.md ~/backup/`
2. Check available disk space
3. Retry after resolving space issues

### Subagent Validation Issues

**Corrupted Download**:
```bash
$ claude-agents reinstall
[ERROR] Downloaded subagent file failed validation: architect.md
```
*Solutions*:
1. Check network stability during download
2. Verify repository integrity
3. Retry installation: `claude-agents reinstall --force`

**Integration Failure**:
```bash
$ claude-agents reinstall
[WARNING] Subagent integration test failed for: new-agent.md
[INFO] Subagent installed but may not function properly
```
*Solutions*:
1. Test subagent manually through Task tool
2. Report issue to toolkit maintainers
3. Check Claude Code compatibility

## Subagent Lifecycle During Reinstall

1. **Assessment Phase**
   - Analyze current installation
   - Identify toolkit vs user subagents
   - Check repository accessibility

2. **Backup Phase**
   - Create user subagent backups
   - Prepare conflict resolution plans
   - Validate backup integrity

3. **Removal Phase**
   - Remove existing toolkit subagents
   - Clean up orphaned files
   - Prepare for fresh installation

4. **Download Phase**
   - Fetch latest repository state
   - Download subagent definitions
   - Validate downloaded files

5. **Installation Phase**
   - Install toolkit subagents
   - Apply proper permissions
   - Generate subagent metadata

6. **Restoration Phase**
   - Restore user subagents
   - Resolve any conflicts
   - Verify final installation

## Security Considerations

### Repository Integrity

Security measures during reinstall:
- **Source Verification**: Only downloads from official toolkit repository
- **Content Validation**: Validates subagent file integrity
- **Permission Management**: Sets appropriate file permissions

### User Subagent Protection

Safety measures for user subagents:
- **Automatic Backup**: Creates backups before any modifications
- **Conflict Resolution**: Preserves user subagents through naming conflicts
- **Rollback Capability**: Can restore previous state if reinstall fails

## Performance Notes

- **Network Dependent**: Requires network access for repository operations
- **Incremental Updates**: Only downloads changed files when possible
- **Parallel Operations**: Can download multiple subagents concurrently
- **Local Caching**: Leverages git caching for improved performance

## Integration with Other Commands

Reinstall works with other subagent operations:

```bash
# Maintenance workflow
claude-agents list               # Check current state
claude-agents reinstall          # Get latest updates
claude-agents list --format detailed  # Verify results

# Development workflow
claude-agents reinstall          # Update subagents
claude-agents list --source claude-toolkit  # Verify toolkit subagents
# Test new subagents through Task tool
```

## Rollback Considerations

### Current Behavior

The current implementation provides basic safety:
- User subagents are preserved and restored
- Failed installations leave system in previous state
- Error recovery maintains user subagent integrity

### Future Enhancements

Planned rollback capabilities:
- **Snapshot Creation**: Create full snapshots before reinstall
- **Selective Rollback**: Roll back individual subagents if needed
- **Version History**: Maintain history of toolkit subagent versions

## Related Commands

- [`install`](install.md) - Install subagents from sources
- [`list`](list.md) - View installed subagents
- [`uninstall`](uninstall.md) - Remove toolkit subagents
- **claude-template-sources commands:**
  - [`claude-template-sources add`](../claude-template-sources/add.md) - Add template source repositories
  - [`claude-template-sources list`](../claude-template-sources/list.md) - List configured sources
  - [`claude-template-sources remove`](../claude-template-sources/remove.md) - Remove source configuration