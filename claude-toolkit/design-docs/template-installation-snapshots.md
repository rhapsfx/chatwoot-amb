# Template Installation Snapshots

## Problem Statement

The current template installation system in `template-management.sh` has an overly cautious approach to file updates. When upstream template files are updated, the system compares checksums between the upstream file and the currently installed file. If they don't match, it assumes the user made changes and refuses to install, generating an error:

```
Cannot install $file_name: destination file is not identical (probably contains user changes)
```

This prevents legitimate updates when users haven't actually made any changes to the installed files.

## Proposed Solution

Introduce a **snapshot system** that tracks the checksums of template files at the time they were last successfully installed. This allows the system to distinguish between:

1. **Legitimate updates**: Upstream changes when user hasn't modified the local file
2. **User modifications**: Local changes that should be preserved

### Snapshot Files

Create snapshot files in the cache directory to track installation state:

- `~/.cache/claude-templates/commands-snapshot.txt` - for slash commands
- `~/.cache/claude-templates/agents-snapshot.txt` - for subagents

**Format**: Each line contains `file_path<TAB>checksum`
```
# Claude Template Snapshot
# Format: file_path<TAB>checksum
# Lines starting with # are comments
/Users/user/.claude/commands/smart-commit.md	abc123def456...
/Users/user/.claude/commands/add-command.md	789ghi012jkl...
```

### Decision Logic

When installing a file where `upstream_checksum != installed_checksum`:

1. **Get snapshot checksum** for the installed file
2. **Compare checksums**:
   - If `installed_checksum == snapshot_checksum`: File unchanged by user → **Safe to update**
   - If `installed_checksum != snapshot_checksum`: File modified by user → **Report error**
   - If no snapshot entry exists: File not tracked → **Report error** (assume user-created)

### Migration Strategy

For existing installations without snapshots:
- Missing snapshot entries are treated as potential user modifications
- This maintains backward compatibility and errs on the side of caution
- Users can use `reinstall` command to force updates if needed
- Snapshots will be created going forward for new installations

## Implementation Plan

### New Functions

Add snapshot management functions to `template-management.sh`:

```bash
# Get path to snapshot file for template type
get_template_snapshot_file(template_type)

# Read entire snapshot (returns file_path<TAB>checksum lines)
read_template_snapshot(template_type)

# Write entire snapshot (accepts file_path<TAB>checksum lines from stdin)
write_template_snapshot(template_type)

# Get checksum for specific file from snapshot
get_template_snapshot_checksum(template_type, file_path)

# Add or update single snapshot entry
update_template_snapshot_entry(template_type, file_path, checksum)

# Remove single snapshot entry
remove_template_snapshot_entry(template_type, file_path)
```

### Modified Logic

#### Install Process

1. **Update `execute_install()`** to accept `template_type` parameter
2. **Modify checksum comparison logic** (around line 925):
   ```bash
   if [[ "$dest_checksum" != "$file_checksum" ]]; then
       local snapshot_checksum
       snapshot_checksum=$(get_template_snapshot_checksum "$template_type" "$dest_full_path")
       
       if [[ -n "$snapshot_checksum" && "$dest_checksum" == "$snapshot_checksum" ]]; then
           # File unchanged by user, safe to update
           log_debug "File $file_name will be updated (no user changes detected)"
       else
           # File modified by user or not tracked
           printf '%s\t%s\t%s\t%s\n' "$source_name" "$file_path" "failure" \
               "Cannot install $file_name: destination file contains user changes (use reinstall to force)"
           failures_met=true
           continue
       fi
   fi
   ```

3. **Create wrapper for copy operations** that updates snapshots:
   ```bash
   copy_file_with_snapshot() {
       local template_type="$1"
       local source_name="$2" 
       local file_path="$3"
       local dest_path="$4"
       
       local result
       result=$(copy_file "$source_name" "$file_path" "$dest_path")
       echo "$result"  # Pass through output
       
       # Update snapshot on success
       if echo "$result" | grep -q $'\tsuccess$'; then
           local new_checksum
           new_checksum=$(compute_file_checksum "$dest_path")
           update_template_snapshot_entry "$template_type" "$dest_path" "$new_checksum"
       fi
   }
   ```

#### Reinstall Process

- **Update `execute_reinstall()`** to accept `template_type` parameter
- **Update snapshots** after successful copy operations (same wrapper approach)
- Reinstall bypasses user modification checks and always updates snapshots

#### Uninstall Process

- **Update `execute_uninstall()`** to accept `template_type` parameter
- **Remove snapshot entries** after successful file removal:
   ```bash
   if rm_error=$(rm -- "$file_path" 2>&1); then
       printf '%s\t%s\n' "$file_name" "success"
       remove_template_snapshot_entry "$template_type" "$file_path"
   else
       printf '%s\t%s\t%s\n' "$file_name" "failure" "$rm_error"
   fi
   ```

### Function Signature Changes

Update callers to pass `template_type` to execution functions:

```bash
# Current
install_results=$(execute_install "$install_dir" "$install_info")

# New  
install_results=$(execute_install "$template_type" "$install_dir" "$install_info")
```

## Benefits

1. **Better User Experience**: Allows legitimate upstream updates without errors
2. **Preserved Safety**: Still protects against overwriting user modifications
3. **Clear Intent**: `install` for safe updates, `reinstall` to force overwrite
4. **Backward Compatible**: Existing installations continue to work (conservatively)
5. **Low Complexity**: Reuses existing configuration file patterns and pipeline architecture

## Edge Cases Handled

- **Missing snapshot file**: Treat as no tracking data (conservative approach)
- **Corrupted snapshot**: Graceful degradation through error handling
- **File not in snapshot**: Treat as user-created (conservative approach)  
- **Snapshot/file path inconsistency**: Use absolute paths consistently
- **Concurrent access**: Atomic file operations minimize race conditions

## Testing Strategy

1. **Unit tests** for snapshot management functions
2. **Integration tests** for install/reinstall/uninstall with snapshots
3. **Migration tests** for existing installations without snapshots
4. **User modification detection** tests with various scenarios

This design maintains the existing pipeline architecture while adding targeted improvements to the checksum comparison logic. The snapshot system provides the additional context needed to make better decisions about when files are safe to update.