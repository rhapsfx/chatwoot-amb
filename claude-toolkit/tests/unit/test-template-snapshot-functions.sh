#!/bin/bash
# test-template-snapshot-functions.sh - Tests snapshot management functions from template-management.sh
# 
# Purpose: Unit tests for template installation snapshot management functions
# Dependencies: None (sources template-management.sh directly)
# Approach: Simulate snapshot operations within sandbox, test function behavior and effects

source "$(dirname "$0")/../utils/test-harness.sh"

# Source the script to get access to functions under test
source "$(dirname "$0")/../../scripts/template-management.sh"

# =============================================================================
# Helper functions for testing
# =============================================================================

# Helper function to create test template files
create_test_template_file() {
    local file_path="$1"
    local source_name="${2:-user}"
    local description="${3:-Test template}"
    
    mkdir -p "$(dirname "$file_path")"
    cat > "$file_path" <<EOF
---
description: $description
source: $source_name
---

# Test Template

This is a test template file.
EOF
}

# Helper function to validate snapshot file format
validate_snapshot_format() {
    local template_type="$1"
    local snapshot_file
    snapshot_file="$(get_template_snapshot_file "$template_type")"
    
    # Check if file exists
    [[ -f "$snapshot_file" ]] || return 1
    
    # Check if file contains the required header
    head -n 3 "$snapshot_file" | grep -q "# Claude Template Snapshot" || return 1
    head -n 3 "$snapshot_file" | grep -q "# Format: file_path<TAB>checksum" || return 1
    head -n 3 "$snapshot_file" | grep -q "# Lines starting with # are comments" || return 1
    
    return 0
}

# Helper function to create test snapshot with data
create_test_snapshot() {
    local template_type="$1"
    local snapshot_file
    snapshot_file="$(get_template_snapshot_file "$template_type")"
    local snapshot_dir
    snapshot_dir="$(dirname "$snapshot_file")"
    
    mkdir -p "$snapshot_dir"
    cat > "$snapshot_file" <<'EOF'
# Claude Template Snapshot
# Format: file_path<TAB>checksum
# Lines starting with # are comments

/home/user/.claude/commands/test1.md	abc123def456
/home/user/.claude/commands/test2.md	789ghi012jkl
/home/user/.claude/commands/test3.md	mno345pqr678
EOF
}

# =============================================================================
# Tests for get_template_snapshot_file function
# =============================================================================

test_get_snapshot_file_commands() {
    (
        create_sandbox
        
        local snapshot_file
        snapshot_file="$(get_template_snapshot_file "commands")"
        
        # Should return path ending with commands-snapshot.txt
        assert_matches ".*commands-snapshot.txt$" "$snapshot_file" "Should return path ending with commands-snapshot.txt"
        
        # Should be in cache directory
        local cache_dir
        cache_dir="$(get_templates_cache_dir)"
        assert_matches "^$cache_dir/.*" "$snapshot_file" "Should be in cache directory"
    )
}

test_get_snapshot_file_agents() {
    (
        create_sandbox
        
        local snapshot_file
        snapshot_file="$(get_template_snapshot_file "agents")"
        
        # Should return path ending with agents-snapshot.txt
        assert_matches ".*agents-snapshot.txt$" "$snapshot_file" "Should return path ending with agents-snapshot.txt"
        
        # Should be in cache directory
        local cache_dir
        cache_dir="$(get_templates_cache_dir)"
        assert_matches "^$cache_dir/.*" "$snapshot_file" "Should be in cache directory"
    )
}

# =============================================================================
# Tests for read_template_snapshot function
# =============================================================================

test_read_snapshot_no_file() {
    (
        create_sandbox
        
        # Test reading when no snapshot file exists
        local output
        output="$(read_template_snapshot "commands")"
        assert_equals "" "$output" "read_template_snapshot should return empty string when no snapshot file exists"
    )
}

test_read_snapshot_empty_file() {
    (
        create_sandbox
        
        local template_type="commands"
        local snapshot_file
        snapshot_file="$(get_template_snapshot_file "$template_type")"
        local snapshot_dir
        snapshot_dir="$(dirname "$snapshot_file")"
        
        mkdir -p "$snapshot_dir"
        cat > "$snapshot_file" <<'EOF'
# Claude Template Snapshot
# Format: file_path<TAB>checksum
# Lines starting with # are comments

EOF
        
        # Test reading empty snapshot (only comments)
        local output
        output="$(read_template_snapshot "$template_type")"
        assert_equals "" "$output" "read_template_snapshot should return empty string for snapshot with only comments"
    )
}

test_read_snapshot_with_data() {
    (
        create_sandbox
        
        local template_type="commands"
        create_test_snapshot "$template_type"
        
        # Test reading snapshot with data
        local output
        output="$(read_template_snapshot "$template_type")"
        
        # Should contain all three entries
        assert_contains "/home/user/.claude/commands/test1.md	abc123def456" "$output" "Should contain test1.md entry"
        assert_contains "/home/user/.claude/commands/test2.md	789ghi012jkl" "$output" "Should contain test2.md entry"
        assert_contains "/home/user/.claude/commands/test3.md	mno345pqr678" "$output" "Should contain test3.md entry"
        
        # Should not contain comments
        assert_not_contains "# Claude Template Snapshot" "$output" "Should not contain comment lines"
        assert_not_contains "# Format:" "$output" "Should not contain format comment"
        
        # Should have exactly 3 lines
        local line_count
        line_count="$(echo "$output" | wc -l | tr -d ' ')"
        assert_equals "3" "$line_count" "Should return exactly 3 lines of data"
    )
}

# =============================================================================
# Tests for write_template_snapshot function
# =============================================================================

test_write_snapshot_creates_file() {
    (
        create_sandbox
        
        local template_type="commands"
        
        # Write snapshot with data from stdin
        printf '%s\t%s\n' "/test/path.md" "checksum123" | write_template_snapshot "$template_type"
        
        # Verify file was created
        local snapshot_file
        snapshot_file="$(get_template_snapshot_file "$template_type")"
        assert_file_exists "$snapshot_file" "write_template_snapshot should create snapshot file"
        
        # Verify file format is correct
        assert_command_succeeds "Snapshot file should have proper format" -- validate_snapshot_format "$template_type"
        
        # Verify content was written correctly
        local content
        content="$(read_template_snapshot "$template_type")"
        assert_contains "/test/path.md	checksum123" "$content" "Should contain written entry"
    )
}

test_write_snapshot_overwrites_existing() {
    (
        create_sandbox
        
        local template_type="commands"
        create_test_snapshot "$template_type"
        
        # Verify initial content
        local initial_content
        initial_content="$(read_template_snapshot "$template_type")"
        assert_contains "test1.md" "$initial_content" "Should initially contain test1.md"
        
        # Write new content, overwriting existing
        printf '%s\t%s\n' "/new/path.md" "newchecksum" | write_template_snapshot "$template_type"
        
        # Verify content was replaced
        local new_content
        new_content="$(read_template_snapshot "$template_type")"
        assert_contains "/new/path.md	newchecksum" "$new_content" "Should contain new entry"
        assert_not_contains "test1.md" "$new_content" "Should not contain old entries"
        
        # Should have exactly 1 line now
        local line_count
        line_count="$(echo "$new_content" | wc -l | tr -d ' ')"
        assert_equals "1" "$line_count" "Should have exactly 1 line after overwrite"
    )
}

test_write_snapshot_sorts_input() {
    (
        create_sandbox
        
        local template_type="commands"
        
        # Write unsorted data
        {
            echo "/zzz/last.md	checksum3"
            echo "/aaa/first.md	checksum1"
            echo "/mmm/middle.md	checksum2"
        } | write_template_snapshot "$template_type"
        
        # Verify content is sorted by file path
        local content
        content="$(read_template_snapshot "$template_type")"
        
        local line1 line2 line3
        line1="$(echo "$content" | sed -n '1p')"
        line2="$(echo "$content" | sed -n '2p')"
        line3="$(echo "$content" | sed -n '3p')"
        
        assert_equals "/aaa/first.md	checksum1" "$line1" "First line should be /aaa/first.md (sorted)"
        assert_equals "/mmm/middle.md	checksum2" "$line2" "Second line should be /mmm/middle.md (sorted)"
        assert_equals "/zzz/last.md	checksum3" "$line3" "Third line should be /zzz/last.md (sorted)"
    )
}

# =============================================================================
# Tests for get_template_snapshot_checksum function
# =============================================================================

test_get_snapshot_checksum_no_file() {
    (
        create_sandbox
        
        # Test when no snapshot file exists
        local output
        output="$(get_template_snapshot_checksum "commands" "/any/path.md")"
        assert_equals "" "$output" "get_template_snapshot_checksum should return empty string when no snapshot exists"
    )
}

test_get_snapshot_checksum_empty_file() {
    (
        create_sandbox
        
        local template_type="commands"
        local snapshot_file
        snapshot_file="$(get_template_snapshot_file "$template_type")"
        local snapshot_dir
        snapshot_dir="$(dirname "$snapshot_file")"
        
        mkdir -p "$snapshot_dir"
        cat > "$snapshot_file" <<'EOF'
# Claude Template Snapshot
# Format: file_path<TAB>checksum
# Lines starting with # are comments

EOF
        
        # Test when snapshot is empty
        local output
        output="$(get_template_snapshot_checksum "$template_type" "/any/path.md")"
        assert_equals "" "$output" "get_template_snapshot_checksum should return empty string for empty snapshot"
    )
}

test_get_snapshot_checksum_with_data() {
    (
        create_sandbox
        
        local template_type="commands"
        create_test_snapshot "$template_type"
        
        # Test getting checksums for existing entries
        local checksum1 checksum2 checksum3
        checksum1="$(get_template_snapshot_checksum "$template_type" "/home/user/.claude/commands/test1.md")"
        checksum2="$(get_template_snapshot_checksum "$template_type" "/home/user/.claude/commands/test2.md")"
        checksum3="$(get_template_snapshot_checksum "$template_type" "/home/user/.claude/commands/test3.md")"
        
        assert_equals "abc123def456" "$checksum1" "Should return correct checksum for test1.md"
        assert_equals "789ghi012jkl" "$checksum2" "Should return correct checksum for test2.md"
        assert_equals "mno345pqr678" "$checksum3" "Should return correct checksum for test3.md"
        
        # Test non-existing entry
        local nonexistent_checksum
        nonexistent_checksum="$(get_template_snapshot_checksum "$template_type" "/nonexistent/path.md")"
        assert_equals "" "$nonexistent_checksum" "Should return empty string for nonexistent entry"
    )
}

test_get_snapshot_checksum_exact_match() {
    (
        create_sandbox
        
        local template_type="commands"
        create_test_snapshot "$template_type"
        
        # Test that matching is exact (not substring)
        local partial_checksum case_checksum
        partial_checksum="$(get_template_snapshot_checksum "$template_type" "/home/user/.claude/commands/test")"
        case_checksum="$(get_template_snapshot_checksum "$template_type" "/HOME/USER/.claude/commands/test1.md")"
        
        assert_equals "" "$partial_checksum" "Should return empty string for partial path match"
        assert_equals "" "$case_checksum" "Should return empty string for case mismatch"
        
        # But exact match should work
        local exact_checksum
        exact_checksum="$(get_template_snapshot_checksum "$template_type" "/home/user/.claude/commands/test1.md")"
        assert_equals "abc123def456" "$exact_checksum" "Should return checksum for exact path match"
    )
}

# =============================================================================
# Tests for update_template_snapshot_entry function
# =============================================================================

test_update_snapshot_entry_new_file() {
    (
        create_sandbox
        
        local template_type="commands"
        local test_path="/test/new.md"
        local test_checksum="newchecksum123"
        
        # Update entry in non-existent snapshot
        update_template_snapshot_entry "$template_type" "$test_path" "$test_checksum"
        
        # Verify snapshot was created
        local snapshot_file
        snapshot_file="$(get_template_snapshot_file "$template_type")"
        assert_file_exists "$snapshot_file" "Snapshot file should be created"
        assert_command_succeeds "Snapshot file should have proper format" -- validate_snapshot_format "$template_type"
        
        # Verify entry was added
        local content
        content="$(read_template_snapshot "$template_type")"
        assert_contains "$test_path	$test_checksum" "$content" "Should contain added entry"
        
        # Should have exactly 1 line
        local line_count
        line_count="$(echo "$content" | wc -l | tr -d ' ')"
        assert_equals "1" "$line_count" "Should have exactly 1 entry"
    )
}

test_update_snapshot_entry_add_to_existing() {
    (
        create_sandbox
        
        local template_type="commands"
        create_test_snapshot "$template_type"
        
        # Verify initial state (3 entries)
        local initial_content
        initial_content="$(read_template_snapshot "$template_type")"
        local initial_count
        initial_count="$(echo "$initial_content" | wc -l | tr -d ' ')"
        assert_equals "3" "$initial_count" "Should initially have 3 entries"
        
        # Add new entry
        local new_path="/test/new.md"
        local new_checksum="newchecksum123"
        update_template_snapshot_entry "$template_type" "$new_path" "$new_checksum"
        
        # Verify entry was added
        local updated_content
        updated_content="$(read_template_snapshot "$template_type")"
        assert_contains "$new_path	$new_checksum" "$updated_content" "Should contain newly added entry"
        
        # Verify old entries still exist
        assert_contains "/home/user/.claude/commands/test1.md	abc123def456" "$updated_content" "Should still contain test1.md"
        assert_contains "/home/user/.claude/commands/test2.md	789ghi012jkl" "$updated_content" "Should still contain test2.md"
        assert_contains "/home/user/.claude/commands/test3.md	mno345pqr678" "$updated_content" "Should still contain test3.md"
        
        # Should have 4 entries now
        local updated_count
        updated_count="$(echo "$updated_content" | wc -l | tr -d ' ')"
        assert_equals "4" "$updated_count" "Should have 4 entries after addition"
    )
}

test_update_snapshot_entry_replace_existing() {
    (
        create_sandbox
        
        local template_type="commands"
        create_test_snapshot "$template_type"
        
        # Update existing entry with new checksum
        local existing_path="/home/user/.claude/commands/test2.md"
        local new_checksum="updated_checksum"
        update_template_snapshot_entry "$template_type" "$existing_path" "$new_checksum"
        
        # Verify entry was updated
        local updated_content
        updated_content="$(read_template_snapshot "$template_type")"
        assert_contains "$existing_path	$new_checksum" "$updated_content" "Should contain updated entry with new checksum"
        assert_not_contains "$existing_path	789ghi012jkl" "$updated_content" "Should not contain old checksum"
        
        # Verify other entries still exist unchanged
        assert_contains "/home/user/.claude/commands/test1.md	abc123def456" "$updated_content" "Should still contain test1.md unchanged"
        assert_contains "/home/user/.claude/commands/test3.md	mno345pqr678" "$updated_content" "Should still contain test3.md unchanged"
        
        # Should still have 3 entries (replacement, not addition)
        local updated_count
        updated_count="$(echo "$updated_content" | wc -l | tr -d ' ')"
        assert_equals "3" "$updated_count" "Should still have 3 entries after replacement"
    )
}

# =============================================================================
# Tests for remove_template_snapshot_entry function
# =============================================================================

test_remove_snapshot_entry_no_file() {
    (
        create_sandbox
        
        local template_type="commands"
        
        # Remove from non-existent snapshot (should not fail)
        remove_template_snapshot_entry "$template_type" "/any/path.md"
        
        # Should create empty snapshot file
        local snapshot_file
        snapshot_file="$(get_template_snapshot_file "$template_type")"
        assert_file_exists "$snapshot_file" "Snapshot file should be created"
        assert_command_succeeds "Snapshot file should have proper format" -- validate_snapshot_format "$template_type"
        
        # Should have no entries
        local content
        content="$(read_template_snapshot "$template_type")"
        assert_equals "" "$content" "Should have no entries after removing from empty snapshot"
    )
}

test_remove_snapshot_entry_existing() {
    (
        create_sandbox
        
        local template_type="commands"
        create_test_snapshot "$template_type"
        
        # Verify initial state (3 entries)
        local initial_content
        initial_content="$(read_template_snapshot "$template_type")"
        local initial_count
        initial_count="$(echo "$initial_content" | wc -l | tr -d ' ')"
        assert_equals "3" "$initial_count" "Should initially have 3 entries"
        
        # Remove one entry
        local remove_path="/home/user/.claude/commands/test2.md"
        remove_template_snapshot_entry "$template_type" "$remove_path"
        
        # Verify entry was removed
        local updated_content
        updated_content="$(read_template_snapshot "$template_type")"
        assert_not_contains "$remove_path	789ghi012jkl" "$updated_content" "Should not contain removed entry"
        
        # Verify other entries still exist
        assert_contains "/home/user/.claude/commands/test1.md	abc123def456" "$updated_content" "Should still contain test1.md"
        assert_contains "/home/user/.claude/commands/test3.md	mno345pqr678" "$updated_content" "Should still contain test3.md"
        
        # Should have 2 entries now
        local updated_count
        updated_count="$(echo "$updated_content" | wc -l | tr -d ' ')"
        assert_equals "2" "$updated_count" "Should have 2 entries after removal"
    )
}

test_remove_snapshot_entry_nonexistent() {
    (
        create_sandbox
        
        local template_type="commands"
        create_test_snapshot "$template_type"
        
        # Remove non-existent entry
        remove_template_snapshot_entry "$template_type" "/nonexistent/path.md"
        
        # Verify all original entries still exist
        local content
        content="$(read_template_snapshot "$template_type")"
        assert_contains "/home/user/.claude/commands/test1.md	abc123def456" "$content" "Should still contain test1.md"
        assert_contains "/home/user/.claude/commands/test2.md	789ghi012jkl" "$content" "Should still contain test2.md"
        assert_contains "/home/user/.claude/commands/test3.md	mno345pqr678" "$content" "Should still contain test3.md"
        
        # Should still have 3 entries
        local line_count
        line_count="$(echo "$content" | wc -l | tr -d ' ')"
        assert_equals "3" "$line_count" "Should still have 3 entries after removing nonexistent"
    )
}

test_remove_snapshot_entry_last_entry() {
    (
        create_sandbox
        
        local template_type="commands"
        
        # Create snapshot with single entry
        printf '%s\t%s\n' "/only/path.md" "onlychecksum" | write_template_snapshot "$template_type"
        
        # Verify single entry exists
        local initial_content
        initial_content="$(read_template_snapshot "$template_type")"
        assert_contains "/only/path.md" "$initial_content" "Should initially contain only entry"
        
        # Remove the only entry
        remove_template_snapshot_entry "$template_type" "/only/path.md"
        
        # Verify snapshot is now empty but file still exists with proper format
        local snapshot_file
        snapshot_file="$(get_template_snapshot_file "$template_type")"
        assert_file_exists "$snapshot_file" "Snapshot file should still exist"
        assert_command_succeeds "Snapshot file should maintain proper format" -- validate_snapshot_format "$template_type"
        
        local final_content
        final_content="$(read_template_snapshot "$template_type")"
        assert_equals "" "$final_content" "Should have no entries after removing last one"
    )
}

# =============================================================================
# Tests for copy_file_with_snapshot function
# =============================================================================

test_copy_file_with_snapshot_success() {
    (
        create_sandbox
        
        local template_type="commands"
        local source_name="test-source"
        local source_file="$sandbox_dir/source.md"
        local dest_file="$sandbox_dir/dest.md"
        
        # Create source file
        create_test_template_file "$source_file" "$source_name"
        
        # Mock compute_file_checksum to return predictable value
        compute_file_checksum() {
            echo "mock_checksum_$(basename "$1")"
        }
        
        # Copy file with snapshot
        local result
        result="$(copy_file_with_snapshot "$template_type" "$source_name" "$source_file" "$dest_file")"
        
        # Should pass through copy_file result
        assert_contains "$source_name	$source_file	success" "$result" "Should pass through copy_file success result"
        
        # Should update snapshot
        local snapshot_checksum
        snapshot_checksum="$(get_template_snapshot_checksum "$template_type" "$dest_file")"
        assert_equals "mock_checksum_dest.md" "$snapshot_checksum" "Should update snapshot with file checksum"
        
        # Verify file was actually copied
        assert_file_exists "$dest_file" "Destination file should exist"
    )
}

test_copy_file_with_snapshot_failure() {
    (
        create_sandbox
        
        local template_type="commands"
        local source_name="test-source"
        local source_file="$sandbox_dir/source.md"
        local dest_file="$sandbox_dir/dest.md"
        
        # Create destination directory
        mkdir -p "$(dirname "$dest_file")"
        
        # Copy non-existent file (should fail)
        local result
        result="$(copy_file_with_snapshot "$template_type" "$source_name" "$source_file" "$dest_file" 2>/dev/null || true)"
        
        # Should pass through copy_file failure result
        assert_contains "$source_name	$source_file	failure" "$result" "Should pass through copy_file failure result"
        
        # Should not update snapshot on failure
        local snapshot_checksum
        snapshot_checksum="$(get_template_snapshot_checksum "$template_type" "$dest_file")"
        assert_equals "" "$snapshot_checksum" "Should not update snapshot on copy failure"
        
        # Verify file was not created
        assert_file_not_exists "$dest_file" "Destination file should not exist after failed copy"
    )
}

# =============================================================================
# Integration tests for snapshot functions
# =============================================================================

test_snapshot_add_update_remove_cycle() {
    (
        create_sandbox
        
        local template_type="commands"
        local test_path="/test/cycle.md"
        
        # Start with empty snapshot
        local empty_checksum
        empty_checksum="$(get_template_snapshot_checksum "$template_type" "$test_path")"
        assert_equals "" "$empty_checksum" "Should have no checksum initially"
        
        # Add entry
        update_template_snapshot_entry "$template_type" "$test_path" "checksum1"
        local checksum1
        checksum1="$(get_template_snapshot_checksum "$template_type" "$test_path")"
        assert_equals "checksum1" "$checksum1" "Should have checksum1 after add"
        
        # Update entry
        update_template_snapshot_entry "$template_type" "$test_path" "checksum2"
        local checksum2
        checksum2="$(get_template_snapshot_checksum "$template_type" "$test_path")"
        assert_equals "checksum2" "$checksum2" "Should have checksum2 after update"
        
        # Remove entry
        remove_template_snapshot_entry "$template_type" "$test_path"
        local final_checksum
        final_checksum="$(get_template_snapshot_checksum "$template_type" "$test_path")"
        assert_equals "" "$final_checksum" "Should have no checksum after removal"
        
        # Snapshot file should still exist with proper format
        local snapshot_file
        snapshot_file="$(get_template_snapshot_file "$template_type")"
        assert_file_exists "$snapshot_file" "Snapshot file should exist after cycle"
        assert_command_succeeds "Snapshot file should maintain proper format" -- validate_snapshot_format "$template_type"
    )
}

test_snapshot_multiple_template_types() {
    (
        create_sandbox
        
        local commands_path="/test/command.md"
        local agents_path="/test/agent.md"
        
        # Add entries to different template types
        update_template_snapshot_entry "commands" "$commands_path" "command_checksum"
        update_template_snapshot_entry "agents" "$agents_path" "agent_checksum"
        
        # Verify entries are in separate snapshots
        local command_checksum agent_checksum
        command_checksum="$(get_template_snapshot_checksum "commands" "$commands_path")"
        agent_checksum="$(get_template_snapshot_checksum "agents" "$agents_path")"
        
        assert_equals "command_checksum" "$command_checksum" "Should have command checksum in commands snapshot"
        assert_equals "agent_checksum" "$agent_checksum" "Should have agent checksum in agents snapshot"
        
        # Cross-type queries should return empty
        local cross_command cross_agent
        cross_command="$(get_template_snapshot_checksum "commands" "$agents_path")"
        cross_agent="$(get_template_snapshot_checksum "agents" "$commands_path")"
        
        assert_equals "" "$cross_command" "Commands snapshot should not contain agent path"
        assert_equals "" "$cross_agent" "Agents snapshot should not contain command path"
        
        # Verify separate files exist
        local commands_file agents_file
        commands_file="$(get_template_snapshot_file "commands")"
        agents_file="$(get_template_snapshot_file "agents")"
        
        assert_file_exists "$commands_file" "Commands snapshot file should exist"
        assert_file_exists "$agents_file" "Agents snapshot file should exist"
        assert_not_equals "$commands_file" "$agents_file" "Snapshot files should be different"
    )
}

# Register all test functions
register_tests \
    "test_get_snapshot_file_commands" \
    "test_get_snapshot_file_agents" \
    "test_read_snapshot_no_file" \
    "test_read_snapshot_empty_file" \
    "test_read_snapshot_with_data" \
    "test_write_snapshot_creates_file" \
    "test_write_snapshot_overwrites_existing" \
    "test_write_snapshot_sorts_input" \
    "test_get_snapshot_checksum_no_file" \
    "test_get_snapshot_checksum_empty_file" \
    "test_get_snapshot_checksum_with_data" \
    "test_get_snapshot_checksum_exact_match" \
    "test_update_snapshot_entry_new_file" \
    "test_update_snapshot_entry_add_to_existing" \
    "test_update_snapshot_entry_replace_existing" \
    "test_remove_snapshot_entry_no_file" \
    "test_remove_snapshot_entry_existing" \
    "test_remove_snapshot_entry_nonexistent" \
    "test_remove_snapshot_entry_last_entry" \
    "test_copy_file_with_snapshot_success" \
    "test_copy_file_with_snapshot_failure" \
    "test_snapshot_add_update_remove_cycle" \
    "test_snapshot_multiple_template_types"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "Template Snapshot Functions Unit Tests" "$@"
fi