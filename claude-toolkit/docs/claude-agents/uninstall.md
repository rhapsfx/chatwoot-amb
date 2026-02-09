# Uninstall Command

Remove Claude Code subagents from configured sources while preserving user-created subagents and providing clean system cleanup.

## Overview

The `uninstall` command selectively removes subagents from configured source repositories in the `~/.claude/agents/` directory. By default, it removes subagents from all configured sources while intelligently preserving user-created subagents, ensuring your custom workflows remain intact.

## Basic Usage

```bash
# Remove subagents from all configured sources (preserves user subagents)
claude-agents uninstall

# Remove subagents from specific source only  
claude-agents uninstall --source claude-toolkit

# Remove with debug output
claude-agents uninstall --debug

# Preview uninstall without changes
claude-agents uninstall --dry-run

# Skip confirmation prompts
claude-agents uninstall --yes
```

## Command Syntax

```bash
claude-agents uninstall [options]
```

### Source Options

| Option | Description |
|--------|-------------|
| `--source all` | Remove subagents from all configured sources (default) |
| `--source <name>` | Remove subagents from specific source only |
| `--source <name1,name2>` | Remove subagents from comma-separated list of sources |

**Note**: User subagents are always preserved and cannot be uninstalled via this command.

### Core Options

| Option | Description |
|--------|-------------|
| `--debug` | Enable debug output (verbose logging) |
| `--dry-run` | Preview uninstall operation without making system modifications |
| `--porcelain` | Machine-readable output format |
| `--yes`, `-y`, `--force` | Skip confirmation prompts and auto-accept |

## Uninstall Process

### 1. Subagent Classification

The system identifies which subagents to remove:
- **Source Subagent Detection**: Identifies subagents installed from configured sources
- **User Subagent Protection**: Catalogues user-created subagents for preservation
- **Metadata Analysis**: Uses installation metadata to determine subagent origins
- **Safety Validation**: Confirms no user subagents will be affected

### 2. Pre-Uninstall Confirmation

Provides clear information about planned actions:
- **Removal Summary**: Lists source subagents that will be removed
- **Preservation Summary**: Lists user subagents that will be preserved
- **Impact Assessment**: Explains functionality that will be lost
- **Confirmation Prompt**: Requests explicit user confirmation (unless `--yes` used)

### 3. Selective Removal

Removes only source subagents:
- **Source Subagent Removal**: Deletes identified source subagent files
- **User Subagent Preservation**: Leaves all user-created subagents untouched
- **Directory Cleanup**: Removes empty directories if no subagents remain
- **Permission Restoration**: Ensures proper directory permissions

### 4. Cleanup Verification

Validates successful uninstall:
- **Removal Confirmation**: Verifies source subagents are completely removed
- **User Subagent Validation**: Confirms user subagents remain intact and functional
- **System State Check**: Ensures no orphaned files or broken references remain

## Subagent Identification Logic

### Source Subagents

Subagents are identified as source subagents if they:
- Have `source: <source-name>` in YAML frontmatter
- Were installed via `claude-agents install`
- Contain source-specific metadata headers
- Match known source subagent signatures

**Current Toolkit Subagents:**
- `architect.md` - Expert software architect for comprehensive analysis
- `test-writer-debugger.md` - Expert test writer and debugger
- `statusline-setup.md` - Configure Claude Code status line settings
- `output-style-setup.md` - Create custom Claude Code output styles

### User Subagents

Subagents are preserved as user subagents if they:
- Lack `source:` field in YAML frontmatter
- Were created manually by users
- Were installed from external non-configured sources
- Lack source metadata headers

## Use Cases

### Remove Source Subagents

Clean removal of source subagents while preserving custom work:
```bash
# Check current installation
claude-agents list
architect.md (claude-toolkit)
my-reviewer.md (user)
test-writer-debugger.md (claude-toolkit)
workflow-helper.md (user)
statusline-setup.md (claude-toolkit)

# Remove toolkit subagents
claude-agents uninstall --source claude-toolkit
[INFO] Found 3 toolkit subagents for removal
[INFO] Found 2 user subagents - will be preserved
[WARNING] This will remove: architect.md, test-writer-debugger.md, statusline-setup.md
Proceed with uninstall? [y/N]: y
[SUCCESS] Removed 3 toolkit subagents, preserved 2 user subagents

# Verify results
claude-agents list
my-reviewer.md (user)
workflow-helper.md (user)
```

### Development Environment Cleanup

Remove source subagents for testing or cleanup:
```bash
# Clean slate for testing
claude-agents uninstall --debug
# [DEBUG] Analyzing subagent installation...
# [DEBUG] Found 4 toolkit subagents for removal
# [DEBUG] No user subagents detected
# [DEBUG] Removing toolkit subagent: architect.md
# [DEBUG] Removing toolkit subagent: test-writer-debugger.md
# [DEBUG] Removing toolkit subagent: statusline-setup.md
# [DEBUG] Removing toolkit subagent: output-style-setup.md
# [SUCCESS] All toolkit subagents removed successfully
```

### Corporate Policy Compliance

Remove source subagents due to policy requirements:
```bash
# Corporate security requirement: remove external subagents
claude-agents uninstall --yes --debug
# [DEBUG] Compliance mode: removing all source subagents
# [DEBUG] User subagents preserved for continuity
# [SUCCESS] Source subagents removed per compliance requirements
```

### Preparation for Manual Management

Switch from automated to manual subagent management:
```bash
# Remove source subagents before manual curation
claude-agents uninstall
# [INFO] Switching to manual subagent management
# [INFO] User subagents preserved for continued use
# [SUCCESS] Ready for manual subagent management
```

## Uninstall Behavior

### Mixed Environment

When both source and user subagents exist:
```bash
$ claude-agents list
architect.md (claude-toolkit)
custom-reviewer.md (user)
test-writer-debugger.md (claude-toolkit)
workflow-manager.md (user)
statusline-setup.md (claude-toolkit)

$ claude-agents uninstall --debug
[DEBUG] Subagent analysis complete:
[DEBUG]   Source subagents (will remove): 3
[DEBUG]     - architect.md
[DEBUG]     - test-writer-debugger.md  
[DEBUG]     - statusline-setup.md
[DEBUG]   User subagents (will preserve): 2
[DEBUG]     - custom-reviewer.md
[DEBUG]     - workflow-manager.md
[INFO] Proceed with selective removal?
[SUCCESS] Removed 3 source subagents, preserved 2 user subagents

$ claude-agents list
custom-reviewer.md (user)
workflow-manager.md (user)
```

### Source Only Environment

When only source subagents exist:
```bash
$ claude-agents list --source claude-toolkit
architect.md (claude-toolkit)
test-writer-debugger.md (claude-toolkit)
statusline-setup.md (claude-toolkit)
output-style-setup.md (claude-toolkit)

$ claude-agents uninstall
[INFO] Found 4 source subagents for removal
[INFO] No user subagents detected
[WARNING] This will remove all subagents from your system
Proceed with uninstall? [y/N]: y
[SUCCESS] All source subagents removed

$ claude-agents list
No subagents installed
```

### User Only Environment

When only user subagents exist (no source subagents installed):
```bash
$ claude-agents list --source user
my-reviewer.md (user)
workflow-helper.md (user)

$ claude-agents uninstall
[INFO] No source subagents found to remove
[INFO] All existing subagents are user-created and will be preserved
[INFO] No action needed
```

## Directory Structure Impact

### Before Uninstall
```
~/.claude/agents/
├── architect.md              # Source (will be removed)
├── test-writer-debugger.md   # Source (will be removed)
├── statusline-setup.md       # Source (will be removed)
├── output-style-setup.md     # Source (will be removed)
├── my-reviewer.md           # User (preserved)
└── workflow-helper.md       # User (preserved)
```

### After Uninstall
```
~/.claude/agents/
├── my-reviewer.md           # User (preserved)
└── workflow-helper.md       # User (preserved)
```

### Complete Removal (Source Only)
```
# If only source subagents existed:
~/.claude/agents/ (directory may be empty or removed if no user subagents)
```

## Advanced Usage

### Source-Specific Uninstall

Remove subagents from specific sources only:
```bash
# Remove from single source
claude-agents uninstall --source claude-toolkit

# Remove from multiple sources
claude-agents uninstall --source claude-toolkit,team-alpha
```

### Forced Uninstall

Skip all confirmations for automated scripts:
```bash
# Non-interactive uninstall
claude-agents uninstall --force
```

### Debug Operation

Get detailed information during uninstall:
```bash
claude-agents uninstall --debug
# [DEBUG] Scanning ~/.claude/agents/ for installed subagents
# [DEBUG] Identifying subagent origins using metadata
# [DEBUG] Source subagent detected: architect.md
#   [DEBUG]   Source: claude-toolkit
#   [DEBUG]   Installed: 2024-01-15 10:30:25
# [DEBUG] User subagent detected: my-reviewer.md
#   [DEBUG]   Created: 2024-01-10 14:22:10
#   [DEBUG]   Origin: User-created
# [DEBUG] Removal plan: 3 source subagents, preserving 2 user subagents
# [INFO] Executing selective removal...
# [SUCCESS] Uninstall completed successfully
```

### Porcelain Mode

Get machine-readable output:
```bash
claude-agents uninstall --porcelain
# architect.md	success
# test-writer-debugger.md	success
# statusline-setup.md	success
```

### Batch Operations

Combine with other operations for complete workflow:
```bash
# Complete removal and reinstall workflow
claude-agents uninstall --yes    # Remove source subagents
claude-agents list               # Verify only user subagents remain
claude-agents install            # Reinstall source subagents
```

## Error Scenarios and Troubleshooting

### Permission Issues

**Permission Denied**:
```bash
$ claude-agents uninstall
[ERROR] Permission denied: Cannot remove ~/.claude/agents/architect.md
```
*Solutions*:
1. Check file permissions: `ls -la ~/.claude/agents/`
2. Ensure no running processes are using the files
3. Fix permissions: `chmod 644 ~/.claude/agents/*.md`

**Directory Access Issues**:
```bash
$ claude-agents uninstall
[ERROR] Cannot access agents directory: ~/.claude/agents/
```
*Solutions*:
1. Verify directory exists: `ls -la ~/.claude/`
2. Check directory permissions: `ls -ld ~/.claude/agents/`
3. Recreate if missing: `mkdir -p ~/.claude/agents/`

### Subagent Classification Issues

**Ambiguous Subagent Origins**:
```bash
$ claude-agents uninstall --debug
[WARNING] Cannot determine origin for: ambiguous-agent.md
[INFO] Treating as user subagent (preserving for safety)
```
*Solutions*:
1. Manually verify subagent origin
2. Remove manually if confirmed source subagent
3. Use `claude-agents reinstall` to refresh source subagent metadata

**Metadata Corruption**:
```bash
$ claude-agents uninstall
[WARNING] Subagent metadata corrupted: corrupted-agent.md
[INFO] Manual review required for safe removal
```
*Solutions*:
1. Review subagent content to determine origin
2. Remove manually if confirmed source subagent
3. Preserve if uncertain about origin

### No Subagents to Remove

**No Source Subagents Found**:
```bash
$ claude-agents uninstall
[INFO] No source subagents found to remove
[INFO] All existing subagents appear to be user-created
```
*This is normal behavior when:*
- No source subagents were ever installed
- Previous uninstall already removed source subagents  
- Only user subagents exist in the system

## Safety Features

### User Subagent Protection

Multiple safety measures protect user subagents:
- **Origin Detection**: Multiple methods to identify subagent sources
- **Conservative Defaults**: When in doubt, preserve subagents as user-created
- **Metadata Validation**: Cross-references multiple identification methods
- **Confirmation Prompts**: Requires explicit confirmation before removal

### Atomic Operations

Uninstall operations are designed to be atomic:
- **Pre-validation**: Confirms all operations can complete before starting
- **Error Recovery**: Stops removal if any errors are encountered
- **State Consistency**: Ensures system remains in consistent state

### Rollback Prevention

Safety measures to prevent accidental data loss:
- **No User Subagent Removal**: Never removes user-created subagents
- **Clear Communication**: Always explains what will be removed
- **Confirmation Required**: Requires explicit user consent (unless `--yes`)

## Integration with Claude Code

### Subagent Availability After Uninstall

After uninstalling source subagents:
- **User Subagents**: Remain fully functional through Task tool
- **Source Subagents**: No longer available (expected behavior)
- **Claude Code Integration**: Continues to work with remaining user subagents

### Testing After Uninstall

Verify Claude Code functionality:
```bash
# After uninstall
claude-agents uninstall

# Test Claude Code with remaining subagents
claude
# User subagents still available through Task tool:
# Task: "Review my code" subagent_type: my-reviewer
# Task: "Manage workflow" subagent_type: workflow-helper
# Source subagents no longer available (expected)
```

## Performance Notes

- **Fast Operation**: Simple file deletion operations
- **No Network Access**: Works entirely offline
- **Minimal Resource Usage**: Lightweight file system operations  
- **Safe Concurrency**: Can run while Claude Code is active (affects next Claude restart)

## Automation and Scripting

### Scripted Uninstall

```bash
#!/bin/bash
# Automated source cleanup script

# Check if source subagents exist
if claude-agents list --source claude-toolkit | grep -q ".md"; then
    echo "Removing source subagents..."
    claude-agents uninstall --yes
    echo "Source subagents removed"
else
    echo "No source subagents to remove"
fi

# Verify user subagents are preserved
user_subagent_count=$(claude-agents list --source user | wc -l)
echo "User subagents preserved: $user_subagent_count"
```

### Conditional Operations

```bash
# Only uninstall if specific conditions are met
if [[ "$ENVIRONMENT" == "production" ]]; then
    echo "Production environment: removing source subagents"
    claude-agents uninstall --force
fi
```

## Integration with Other Commands

Uninstall works with other subagent operations:

```bash
# Complete management workflow
claude-agents list               # Check current state
claude-agents uninstall          # Remove source subagents  
claude-agents list --source user  # Verify user subagents preserved
claude-agents install            # Reinstall source if needed

# Migration workflow
claude-agents uninstall --yes    # Remove current source subagents
# ... manual subagent curation ...
claude-agents install            # Install fresh source subagents
```

## Recovery Procedures

### Accidental Uninstall Recovery

If source subagents were accidentally removed:
```bash
# Reinstall source subagents
claude-agents install
# [INFO] Installing source subagents from repository
# [SUCCESS] Source subagents restored

# Verify restoration
claude-agents list --source claude-toolkit
```

### User Subagent Verification

Verify user subagents remain functional:
```bash
# Test user subagents still work
claude-agents list --source user --format detailed
# Shows detailed info about preserved user subagents

# Test through Task tool
claude
# User subagents should still be available
```

## Related Commands

- [`install`](install.md) - Install subagents from sources
- [`list`](list.md) - View installed subagents with origin indicators
- [`reinstall`](reinstall.md) - Reinstall subagents from latest repository
- **claude-template-sources commands:**
  - [`claude-template-sources add`](../claude-template-sources/add.md) - Add template source repositories
  - [`claude-template-sources list`](../claude-template-sources/list.md) - List configured sources
  - [`claude-template-sources remove`](../claude-template-sources/remove.md) - Remove source configuration