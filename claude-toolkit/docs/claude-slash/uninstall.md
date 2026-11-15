# Uninstall Command

Remove Claude Code slash commands from configured sources while preserving user-created commands and providing clean system cleanup.

## Overview

The `uninstall` command selectively removes slash commands from configured source repositories in the `~/.claude/commands/` directory. By default, it removes commands from all configured sources while intelligently preserving user-created commands, ensuring your custom workflows remain intact.

## Basic Usage

```bash
# Remove commands from all configured sources (preserves user commands)
./scripts/claude-slash.sh uninstall

# Remove commands from specific source only  
./scripts/claude-slash.sh uninstall --source claude-toolkit

# Remove with verbose output
./scripts/claude-slash.sh uninstall --debug

# Preview uninstall without changes
./scripts/claude-slash.sh uninstall --dry-run

# Skip confirmation prompts
./scripts/claude-slash.sh uninstall --yes
```

## Command Syntax

```bash
./scripts/claude-slash.sh uninstall [--source <source>] [options]
```

### Source Options

| Option | Description |
|--------|-------------|
| `--source all` | Remove commands from all configured sources (default) |
| `--source <name>` | Remove commands from specific source only |
| `--source <name1,name2>` | Remove commands from comma-separated list of sources |

**Note**: User commands are always preserved and cannot be uninstalled via this command.

### Core Options

| Option | Description |
|--------|-------------|
| `--verbose` | Show detailed uninstall progress and diagnostic information |
| `--dry-run` | Preview uninstall operation without making system modifications |
| `--yes`, `-y`, `--force` | Skip confirmation prompts and auto-accept |

## Uninstall Process

### 1. Command Classification

The system identifies which commands to remove:
- **Toolkit Command Detection**: Identifies commands installed from toolkit repository
- **User Command Protection**: Catalogues user-created commands for preservation
- **Metadata Analysis**: Uses installation metadata to determine command origins
- **Safety Validation**: Confirms no user commands will be affected

### 2. Pre-Uninstall Confirmation

Provides clear information about planned actions:
- **Removal Summary**: Lists toolkit commands that will be removed
- **Preservation Summary**: Lists user commands that will be preserved
- **Impact Assessment**: Explains functionality that will be lost
- **Confirmation Prompt**: Requests explicit user confirmation (unless `--yes` used)

### 3. Selective Removal

Removes only toolkit commands:
- **Toolkit Command Removal**: Deletes identified toolkit command files
- **User Command Preservation**: Leaves all user-created commands untouched
- **Directory Cleanup**: Removes empty directories if no commands remain
- **Permission Restoration**: Ensures proper directory permissions

### 4. Cleanup Verification

Validates successful uninstall:
- **Removal Confirmation**: Verifies toolkit commands are completely removed
- **User Command Validation**: Confirms user commands remain intact and functional
- **System State Check**: Ensures no orphaned files or broken references remain

## Command Identification Logic

### Toolkit Commands

Commands are identified as toolkit commands if they:
- Are listed in the official toolkit command registry
- Were installed via `./scripts/claude-slash.sh install`
- Contain toolkit-specific metadata headers
- Match known toolkit command signatures

**Current Toolkit Commands:**
- `add-command.md` - Create new slash commands with templates
- `smart-commit.md` - Generate intelligent commit messages
- `quick-commit.md` - Streamlined commit process
- `review-codebase.md` - Comprehensive codebase analysis
- `solid-analysis.md` - SOLID principles analysis

### User Commands

Commands are preserved as user commands if they:
- Are not in the toolkit command registry
- Were created using `/add-command` with user scope
- Were manually created by users
- Were installed from external sources
- Lack toolkit metadata headers

## Use Cases

### Remove Toolkit Commands

Clean removal of toolkit commands while preserving custom work:
```bash
# Check current installation
./scripts/claude-slash.sh list
add-command.md (toolkit)
my-helper.md (user)
smart-commit.md (toolkit)
project-setup.md (user)
review-codebase.md (toolkit)

# Remove toolkit commands
./scripts/claude-slash.sh uninstall
[INFO] Found 3 toolkit commands for removal
[INFO] Found 2 user commands - will be preserved
[WARNING] This will remove: add-command.md, smart-commit.md, review-codebase.md
Proceed with uninstall? [y/N]: y
[SUCCESS] Removed 3 toolkit commands, preserved 2 user commands

# Verify results
./scripts/claude-slash.sh list
my-helper.md (user)
project-setup.md (user)
```

### Development Environment Cleanup

Remove toolkit commands for testing or cleanup:
```bash
# Clean slate for testing
./scripts/claude-slash.sh uninstall --verbose
# [VERBOSE] Analyzing command installation...
# [VERBOSE] Found 5 toolkit commands for removal
# [VERBOSE] No user commands detected
# [VERBOSE] Removing toolkit command: add-command.md
# [VERBOSE] Removing toolkit command: smart-commit.md
# [VERBOSE] Removing toolkit command: quick-commit.md
# [VERBOSE] Removing toolkit command: review-codebase.md
# [VERBOSE] Removing toolkit command: solid-analysis.md
# [SUCCESS] All toolkit commands removed successfully
```

### Corporate Policy Compliance

Remove toolkit commands due to policy requirements:
```bash
# Corporate security requirement: remove external commands
./scripts/claude-slash.sh uninstall --yes --verbose
# [VERBOSE] Compliance mode: removing all toolkit commands
# [VERBOSE] User commands preserved for continuity
# [SUCCESS] Toolkit commands removed per compliance requirements
```

### Preparation for Manual Management

Switch from automated to manual command management:
```bash
# Remove toolkit commands before manual curation
./scripts/claude-slash.sh uninstall
# [INFO] Switching to manual command management
# [INFO] User commands preserved for continued use
# [SUCCESS] Ready for manual command management
```

## Uninstall Behavior

### Mixed Environment

When both toolkit and user commands exist:
```bash
$ ./scripts/claude-slash.sh list
add-command.md (toolkit)
auth-helper.md (user)
smart-commit.md (toolkit)
test-runner.md (user)
review-codebase.md (toolkit)

$ ./scripts/claude-slash.sh uninstall --verbose
[VERBOSE] Command analysis complete:
[VERBOSE]   Toolkit commands (will remove): 3
[VERBOSE]     - add-command.md
[VERBOSE]     - smart-commit.md  
[VERBOSE]     - review-codebase.md
[VERBOSE]   User commands (will preserve): 2
[VERBOSE]     - auth-helper.md
[VERBOSE]     - test-runner.md
[INFO] Proceed with selective removal?
[SUCCESS] Removed 3 toolkit commands, preserved 2 user commands

$ ./scripts/claude-slash.sh list
auth-helper.md (user)
test-runner.md (user)
```

### Toolkit Only Environment

When only toolkit commands exist:
```bash
$ ./scripts/claude-slash.sh list --filter toolkit-only
add-command.md
smart-commit.md
quick-commit.md
review-codebase.md
solid-analysis.md

$ ./scripts/claude-slash.sh uninstall
[INFO] Found 5 toolkit commands for removal
[INFO] No user commands detected
[WARNING] This will remove all slash commands from your system
Proceed with uninstall? [y/N]: y
[SUCCESS] All toolkit commands removed

$ ./scripts/claude-slash.sh list
No slash commands installed
```

### User Only Environment

When only user commands exist (no toolkit commands installed):
```bash
$ ./scripts/claude-slash.sh list --filter user-only
my-helper.md
project-setup.md

$ ./scripts/claude-slash.sh uninstall
[INFO] No toolkit commands found to remove
[INFO] All existing commands are user-created and will be preserved
[INFO] No action needed
```

## Directory Structure Impact

### Before Uninstall
```
~/.claude/commands/
├── add-command.md          # Toolkit (will be removed)
├── smart-commit.md         # Toolkit (will be removed)
├── quick-commit.md         # Toolkit (will be removed)
├── review-codebase.md      # Toolkit (will be removed)
├── solid-analysis.md       # Toolkit (will be removed)
├── my-helper.md           # User (preserved)
└── project-setup.md       # User (preserved)
```

### After Uninstall
```
~/.claude/commands/
├── my-helper.md           # User (preserved)
└── project-setup.md       # User (preserved)
```

### Complete Removal (Toolkit Only)
```
# If only toolkit commands existed:
~/.claude/commands/ (directory may be empty or removed if no user commands)
```

## Advanced Usage

### Forced Uninstall

Skip all confirmations for automated scripts:
```bash
# Non-interactive uninstall
./scripts/claude-slash.sh uninstall --force
```

### Verbose Operation

Get detailed information during uninstall:
```bash
./scripts/claude-slash.sh uninstall --verbose
# [VERBOSE] Scanning ~/.claude/commands/ for installed commands
# [VERBOSE] Identifying command origins using metadata
# [VERBOSE] Toolkit command detected: add-command.md
#   [VERBOSE]   Source: claude-code-toolkit repository
#   [VERBOSE]   Installed: 2024-01-15 10:30:25
# [VERBOSE] User command detected: my-helper.md
#   [VERBOSE]   Created: 2024-01-10 14:22:10
#   [VERBOSE]   Origin: User-created
# [VERBOSE] Removal plan: 3 toolkit commands, preserving 2 user commands
# [INFO] Executing selective removal...
# [SUCCESS] Uninstall completed successfully
```

### Batch Operations

Combine with other operations for complete workflow:
```bash
# Complete removal and reinstall workflow
./scripts/claude-slash.sh uninstall --yes    # Remove toolkit commands
./scripts/claude-slash.sh list               # Verify only user commands remain
./scripts/claude-slash.sh install            # Reinstall toolkit commands
```

## Error Scenarios and Troubleshooting

### Permission Issues

**Permission Denied**:
```bash
$ ./scripts/claude-slash.sh uninstall
[ERROR] Permission denied: Cannot remove ~/.claude/commands/add-command.md
```
*Solutions*:
1. Check file permissions: `ls -la ~/.claude/commands/`
2. Ensure no running processes are using the files
3. Fix permissions: `chmod 644 ~/.claude/commands/*.md`

**Directory Access Issues**:
```bash
$ ./scripts/claude-slash.sh uninstall
[ERROR] Cannot access commands directory: ~/.claude/commands/
```
*Solutions*:
1. Verify directory exists: `ls -la ~/.claude/`
2. Check directory permissions: `ls -ld ~/.claude/commands/`
3. Recreate if missing: `mkdir -p ~/.claude/commands/`

### Command Classification Issues

**Ambiguous Command Origins**:
```bash
$ ./scripts/claude-slash.sh uninstall --verbose
[WARNING] Cannot determine origin for: ambiguous-command.md
[INFO] Treating as user command (preserving for safety)
```
*Solutions*:
1. Manually verify command origin
2. Remove manually if confirmed toolkit command
3. Use `./scripts/claude-slash.sh reinstall` to refresh toolkit command metadata

**Metadata Corruption**:
```bash
$ ./scripts/claude-slash.sh uninstall
[WARNING] Command metadata corrupted: corrupted-command.md
[INFO] Manual review required for safe removal
```
*Solutions*:
1. Review command content to determine origin
2. Remove manually if confirmed toolkit command
3. Preserve if uncertain about origin

### No Commands to Remove

**No Toolkit Commands Found**:
```bash
$ ./scripts/claude-slash.sh uninstall
[INFO] No toolkit commands found to remove
[INFO] All existing commands appear to be user-created
```
*This is normal behavior when:*
- No toolkit commands were ever installed
- Previous uninstall already removed toolkit commands  
- Only user commands exist in the system

## Safety Features

### User Command Protection

Multiple safety measures protect user commands:
- **Origin Detection**: Multiple methods to identify command sources
- **Conservative Defaults**: When in doubt, preserve commands as user-created
- **Metadata Validation**: Cross-references multiple identification methods
- **Confirmation Prompts**: Requires explicit confirmation before removal

### Atomic Operations

Uninstall operations are designed to be atomic:
- **Pre-validation**: Confirms all operations can complete before starting
- **Error Recovery**: Stops removal if any errors are encountered
- **State Consistency**: Ensures system remains in consistent state

### Rollback Prevention

Safety measures to prevent accidental data loss:
- **No User Command Removal**: Never removes user-created commands
- **Clear Communication**: Always explains what will be removed
- **Confirmation Required**: Requires explicit user consent (unless `--yes`)

## Integration with Claude Code

### Command Availability After Uninstall

After uninstalling toolkit commands:
- **User Commands**: Remain fully functional in Claude Code
- **Toolkit Commands**: No longer available (expected behavior)
- **Claude Code Integration**: Continues to work with remaining user commands

### Testing After Uninstall

Verify Claude Code functionality:
```bash
# After uninstall
./scripts/claude-slash.sh uninstall

# Test Claude Code with remaining commands
claude
# User commands still available:
# /my-helper
# /project-setup
# Toolkit commands no longer available (expected)
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
# Automated toolkit cleanup script

# Check if toolkit commands exist
if ./scripts/claude-slash.sh list --filter toolkit-only | grep -q ".md"; then
    echo "Removing toolkit commands..."
    ./scripts/claude-slash.sh uninstall --yes
    echo "Toolkit commands removed"
else
    echo "No toolkit commands to remove"
fi

# Verify user commands are preserved
user_command_count=$(./scripts/claude-slash.sh list --filter user-only | wc -l)
echo "User commands preserved: $user_command_count"
```

### Conditional Operations

```bash
# Only uninstall if specific conditions are met
if [[ "$ENVIRONMENT" == "production" ]]; then
    echo "Production environment: removing toolkit commands"
    ./scripts/claude-slash.sh uninstall --force
fi
```

## Integration with Other Commands

Uninstall works with other slash command operations:

```bash
# Complete management workflow
./scripts/claude-slash.sh list               # Check current state
./scripts/claude-slash.sh uninstall          # Remove toolkit commands  
./scripts/claude-slash.sh list --filter user-only     # Verify user commands preserved
./scripts/claude-slash.sh install            # Reinstall toolkit if needed

# Migration workflow
./scripts/claude-slash.sh uninstall --yes    # Remove current toolkit
# ... manual command curation ...
./scripts/claude-slash.sh install            # Install fresh toolkit
```

## Recovery Procedures

### Accidental Uninstall Recovery

If toolkit commands were accidentally removed:
```bash
# Reinstall toolkit commands
./scripts/claude-slash.sh install
# [INFO] Installing toolkit commands from repository
# [SUCCESS] Toolkit commands restored

# Verify restoration
./scripts/claude-slash.sh list --filter toolkit-only
```

### User Command Verification

Verify user commands remain functional:
```bash
# Test user commands still work
./scripts/claude-slash.sh list --filter user-only --verbose
# Shows detailed info about preserved user commands

# Test in Claude Code
claude
# User commands should still be available
```

## Related Commands

- [`--install`](install.md) - Install slash commands from toolkit repository
- [`--list`](list.md) - View installed slash commands with origin indicators
- [`--reinstall`](reinstall.md) - Reinstall commands from latest repository
- [`/add-command`](../../slash-commands/add-command.md) - Create new user commands to replace toolkit functionality
