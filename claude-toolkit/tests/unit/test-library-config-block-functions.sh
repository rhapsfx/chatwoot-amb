#!/bin/bash
# test-library-config-block-functions.sh - Tests configuration block functions from claude-code.sh
# 
# Purpose: Unit tests for config block management utility functions
# Dependencies: None (sources claude-code.sh directly)
# Approach: Create temporary config files within sandbox, test function behavior

source "$(dirname "$0")/../utils/test-harness.sh"

source "$(dirname "$0")/../../scripts/library.sh"

# Helper function to create a test config file with content
create_test_config() {
    local config_file="$1"
    local content="${2:-}"
    mkdir -p "$(dirname "$config_file")"
    if [[ -n "$content" ]]; then
        echo "$content" > "$config_file"
    else
        touch "$config_file"
    fi
}

# Helper function to create a config file with existing blocks
create_config_with_blocks() {
    local config_file="$1"
    mkdir -p "$(dirname "$config_file")"
    cat > "$config_file" << 'EOF'
# User's existing configuration
export PATH="$HOME/bin:$PATH"

# >>> existing-block start >>>
# This is an existing configuration block
export EXISTING_VAR="value"
# <<< existing-block end <<<

# More user configuration
alias ll="ls -la"

# >>> another-block start >>>
# Another configuration block
export ANOTHER_VAR="another_value"
# Multiple lines in block
export BLOCK_VAR="block_value"
# <<< another-block end <<<

# Final user configuration
source ~/.extra_config
EOF
}

# =============================================================================
# Tests for ensure_config_file_exists
# =============================================================================

test_ensure_config_file_exists_creates_file() {
    (
        create_sandbox

        local config_file="$sandbox_dir/.testrc"
        
        # File should not exist initially
        assert_file_not_exists "$config_file" "Config file should not exist initially"
        
        # Call function to create file
        ensure_config_file_exists "$config_file"
        
        # File should now exist
        assert_file_exists "$config_file" "Config file should be created"
    )
}

test_ensure_config_file_exists_creates_parent_dirs() {
    (
        create_sandbox

        local config_file="$sandbox_dir/nested/deep/path/config.fish"
        
        # Directory should not exist initially
        assert_directory_not_exists "$(dirname "$config_file")" "Parent directory should not exist initially"
        
        # Call function to create file and parent directories
        ensure_config_file_exists "$config_file"
        
        # Directory and file should now exist
        assert_directory_exists "$(dirname "$config_file")" "Parent directory should be created"
        assert_file_exists "$config_file" "Config file should be created"
    )
}

test_ensure_config_file_exists_preserves_existing() {
    (
        create_sandbox

        local config_file="$sandbox_dir/.bashrc"
        local original_content="# Original configuration\nexport ORIGINAL=value"
        
        # Create file with existing content
        create_test_config "$config_file" "$original_content"
        
        # Call function on existing file
        ensure_config_file_exists "$config_file"
        
        # File should still exist with original content
        assert_file_exists "$config_file" "Config file should still exist"
        assert_file_contains "$config_file" "Original configuration" "Original content should be preserved"
        assert_file_contains "$config_file" "ORIGINAL=value" "Original content should be preserved"
    )
}

# =============================================================================
# Tests for config_block_exists
# =============================================================================

test_config_block_exists() {
    (
        create_sandbox

        local config_file="$sandbox_dir/.testrc"
        local missing_file="$sandbox_dir/nonexistent.conf"
        local empty_file="$sandbox_dir/.emptyrc"
        
        # Test with file containing blocks
        create_config_with_blocks "$config_file"
        
        # Should detect existing blocks
        assert_command_succeeds "Should detect existing-block" -- config_block_exists "$config_file" "existing-block"
        assert_command_succeeds "Should detect another-block" -- config_block_exists "$config_file" "another-block"
        
        # Should not detect non-existent blocks
        assert_command_fails "Should not detect missing-block" -- config_block_exists "$config_file" "missing-block"
        assert_command_fails "Should not detect nonexistent-block" -- config_block_exists "$config_file" "nonexistent-block"
        
        # Should handle missing file gracefully
        assert_command_fails "Should fail gracefully for missing file" -- config_block_exists "$missing_file" "any-block"
        
        # Should handle empty file
        create_test_config "$empty_file" ""
        assert_command_fails "Should not detect block in empty file" -- config_block_exists "$empty_file" "any-block"
    )
}

# =============================================================================
# Tests for add_config_block
# =============================================================================

test_add_config_block_creates_new_block() {
    (
        create_sandbox

        local config_file="$sandbox_dir/.testrc"
        local content="export NEW_VAR=\"test_value\""
        
        # Add block to non-existent file
        add_config_block "$config_file" "test-block" "$content"
        
        # File should be created with proper block structure
        assert_file_exists "$config_file" "Config file should be created"
        assert_file_contains "$config_file" "# >>> test-block start >>>" "Should contain start marker"
        assert_file_contains "$config_file" "export NEW_VAR=\"test_value\"" "Should contain block content"
        assert_file_contains "$config_file" "# <<< test-block end <<<" "Should contain end marker"
        
        # Block should be detectable
        assert_command_succeeds "Should detect newly added block" -- config_block_exists "$config_file" "test-block"
    )
}

test_add_config_block_appends_to_existing() {
    (
        create_sandbox

        local config_file="$sandbox_dir/.testrc"
        local original_content="# Original config\nexport ORIGINAL=value"
        local new_content="export NEW_VAR=\"new_value\""
        
        # Create file with existing content
        create_test_config "$config_file" "$original_content"
        
        # Add new block
        add_config_block "$config_file" "new-block" "$new_content"
        
        # Should preserve original content and add new block
        assert_file_contains "$config_file" "Original config" "Should preserve original content"
        assert_file_contains "$config_file" "ORIGINAL=value" "Should preserve original content"
        assert_file_contains "$config_file" "# >>> new-block start >>>" "Should contain new block start marker"
        assert_file_contains "$config_file" "export NEW_VAR=\"new_value\"" "Should contain new block content"
        assert_file_contains "$config_file" "# <<< new-block end <<<" "Should contain new block end marker"
    )
}

test_add_config_block_replaces_existing_block() {
    (
        create_sandbox

        local config_file="$sandbox_dir/.testrc"
        create_config_with_blocks "$config_file"
        
        local new_content="export REPLACED_VAR=\"replaced_value\""
        
        # Replace existing block
        add_config_block "$config_file" "existing-block" "$new_content"
        
        # Should replace old content with new content
        assert_file_contains "$config_file" "# >>> existing-block start >>>" "Should contain start marker"
        assert_file_contains "$config_file" "export REPLACED_VAR=\"replaced_value\"" "Should contain new content"
        assert_file_contains "$config_file" "# <<< existing-block end <<<" "Should contain end marker"
        
        # Old content should be gone
        assert_file_not_contains "$config_file" "export EXISTING_VAR=\"value\"" "Old content should be removed"
        
        # Other blocks should be preserved
        assert_file_contains "$config_file" "# >>> another-block start >>>" "Should preserve other blocks"
        assert_file_contains "$config_file" "export ANOTHER_VAR=\"another_value\"" "Should preserve other block content"
    )
}

test_add_config_block_handles_multiline_content() {
    (
        create_sandbox

        local config_file="$sandbox_dir/.testrc"
        local multiline_content="# Multi-line configuration\nexport VAR1=\"value1\"\nexport VAR2=\"value2\"\n# Comment in block"
        
        # Add multiline block
        add_config_block "$config_file" "multiline-block" "$multiline_content"
        
        # Should contain all lines
        assert_file_contains "$config_file" "# Multi-line configuration" "Should contain first line"
        assert_file_contains "$config_file" "export VAR1=\"value1\"" "Should contain second line"
        assert_file_contains "$config_file" "export VAR2=\"value2\"" "Should contain third line"
        assert_file_contains "$config_file" "# Comment in block" "Should contain fourth line"
        
        # Should have proper markers
        assert_file_contains "$config_file" "# >>> multiline-block start >>>" "Should have start marker"
        assert_file_contains "$config_file" "# <<< multiline-block end <<<" "Should have end marker"
    )
}

# =============================================================================
# Tests for remove_config_block
# =============================================================================

test_remove_config_block_removes_existing_block() {
    (
        create_sandbox

        local config_file="$sandbox_dir/.testrc"
        create_config_with_blocks "$config_file"
        
        # Remove existing block
        remove_config_block "$config_file" "existing-block"
        
        # Block should be gone
        assert_command_fails "Block should no longer exist" -- config_block_exists "$config_file" "existing-block"
        assert_file_not_contains "$config_file" "# >>> existing-block start >>>" "Start marker should be removed"
        assert_file_not_contains "$config_file" "export EXISTING_VAR=\"value\"" "Block content should be removed"
        assert_file_not_contains "$config_file" "# <<< existing-block end <<<" "End marker should be removed"
        
        # Other content should be preserved
        assert_file_contains "$config_file" "# User's existing configuration" "Should preserve other content"
        assert_file_contains "$config_file" "export PATH=" "Should preserve other content"
        assert_file_contains "$config_file" "# >>> another-block start >>>" "Should preserve other blocks"
        assert_file_contains "$config_file" "export ANOTHER_VAR=\"another_value\"" "Should preserve other block content"
    )
}

test_remove_config_block_handles_missing_file() {
    (
        create_sandbox

        local config_file="$sandbox_dir/nonexistent.conf"
        
        # Should handle missing file gracefully
        assert_command_succeeds "Should succeed on missing file" -- remove_config_block "$config_file" "any-block"
    )
}

test_remove_config_block_handles_nonexistent_block() {
    (
        create_sandbox

        local config_file="$sandbox_dir/.testrc"
        create_config_with_blocks "$config_file"
        
        # Should handle missing block gracefully
        assert_command_succeeds "Should succeed when block doesn't exist" -- remove_config_block "$config_file" "missing-block"
        
        # Original content should be unchanged
        assert_file_contains "$config_file" "# >>> existing-block start >>>" "Should preserve existing blocks"
        assert_file_contains "$config_file" "export EXISTING_VAR=\"value\"" "Should preserve existing content"
    )
}

test_remove_config_block_handles_multiple_blocks_same_prefix() {
    (
        create_sandbox

        local config_file="$sandbox_dir/.testrc"
        
        # Create file with multiple blocks of same prefix
        cat > "$config_file" << 'EOF'
# User config
export USER_VAR="value"

# >>> test-block start >>>
export VAR1="value1"
# <<< test-block end <<<

# More user config
alias test="echo test"

# >>> test-block start >>>
export VAR2="value2"
# <<< test-block end <<<

# Final config
export FINAL="value"
EOF
        
        # Remove all blocks with the prefix
        remove_config_block "$config_file" "test-block"
        
        # All blocks should be gone
        assert_command_fails "No test-block should remain" -- config_block_exists "$config_file" "test-block"
        assert_file_not_contains "$config_file" "export VAR1=\"value1\"" "First block content should be removed"
        assert_file_not_contains "$config_file" "export VAR2=\"value2\"" "Second block content should be removed"
        
        # User content should be preserved
        assert_file_contains "$config_file" "export USER_VAR=\"value\"" "Should preserve user content"
        assert_file_contains "$config_file" "alias test=" "Should preserve user content"
        assert_file_contains "$config_file" "export FINAL=\"value\"" "Should preserve user content"
    )
}

test_remove_config_block_handles_malformed_blocks() {
    (
        create_sandbox

        local config_file="$sandbox_dir/.testrc"
        
        # Create file with malformed block (missing end marker)
        cat > "$config_file" << 'EOF'
# User config
export USER_VAR="value"

# >>> malformed-block start >>>
export MALFORMED="value"
# Missing end marker here

# More user config
export MORE="value"
EOF
        
        # Should handle malformed block gracefully
        assert_command_succeeds "Should handle malformed block gracefully" -- remove_config_block "$config_file" "malformed-block"
        
        # Should preserve other content even if block is malformed
        assert_file_contains "$config_file" "export USER_VAR=\"value\"" "Should preserve user content"
        assert_file_contains "$config_file" "export MORE=\"value\"" "Should preserve user content"
    )
}

# =============================================================================
# Integration Tests
# =============================================================================

test_config_block_workflow_complete() {
    (
        create_sandbox

        local config_file="$sandbox_dir/.testrc"
        local initial_content="# User's initial config\nexport INITIAL=\"value\""
        
        # Start with existing file
        create_test_config "$config_file" "$initial_content"
        
        # Add first block
        add_config_block "$config_file" "block1" "export BLOCK1=\"value1\""
        assert_command_succeeds "Block1 should exist" -- config_block_exists "$config_file" "block1"
        assert_file_contains "$config_file" "export BLOCK1=\"value1\"" "Should contain block1 content"
        
        # Add second block  
        add_config_block "$config_file" "block2" "export BLOCK2=\"value2\""
        assert_command_succeeds "Block2 should exist" -- config_block_exists "$config_file" "block2"
        assert_file_contains "$config_file" "export BLOCK2=\"value2\"" "Should contain block2 content"
        
        # Both blocks should exist
        assert_command_succeeds "Block1 should still exist" -- config_block_exists "$config_file" "block1"
        assert_file_contains "$config_file" "export BLOCK1=\"value1\"" "Should still contain block1 content"
        
        # Update first block
        add_config_block "$config_file" "block1" "export BLOCK1_UPDATED=\"updated_value\""
        assert_command_succeeds "Block1 should still exist after update" -- config_block_exists "$config_file" "block1"
        assert_file_contains "$config_file" "export BLOCK1_UPDATED=\"updated_value\"" "Should contain updated content"
        assert_file_not_contains "$config_file" "export BLOCK1=\"value1\"" "Old content should be gone"
        
        # Original content should be preserved
        assert_file_contains "$config_file" "# User's initial config" "Should preserve original content"
        assert_file_contains "$config_file" "export INITIAL=\"value\"" "Should preserve original content"
        
        # Remove first block
        remove_config_block "$config_file" "block1"
        assert_command_fails "Block1 should be removed" -- config_block_exists "$config_file" "block1"
        assert_file_not_contains "$config_file" "export BLOCK1_UPDATED=\"updated_value\"" "Block1 content should be gone"
        
        # Second block should remain
        assert_command_succeeds "Block2 should remain" -- config_block_exists "$config_file" "block2"
        assert_file_contains "$config_file" "export BLOCK2=\"value2\"" "Block2 content should remain"
        
        # Remove second block
        remove_config_block "$config_file" "block2"
        assert_command_fails "Block2 should be removed" -- config_block_exists "$config_file" "block2"
        
        # Original content should still be preserved
        assert_file_contains "$config_file" "# User's initial config" "Should preserve original content"
        assert_file_contains "$config_file" "export INITIAL=\"value\"" "Should preserve original content"
    )
}

test_config_block_edge_cases() {
    (
        create_sandbox

        local config_file="$sandbox_dir/.testrc"
        
        # Test empty content
        add_config_block "$config_file" "empty-block" ""
        assert_command_succeeds "Empty block should exist" -- config_block_exists "$config_file" "empty-block"
        assert_file_contains "$config_file" "# >>> empty-block start >>>" "Should have start marker"
        assert_file_contains "$config_file" "# <<< empty-block end <<<" "Should have end marker"
        
        # Test content with special characters
        local special_content="export SPECIAL=\"value with spaces and 'quotes'\"\n# Comment with >>> markers <<< inside"
        add_config_block "$config_file" "special-block" "$special_content"
        assert_command_succeeds "Special block should exist" -- config_block_exists "$config_file" "special-block"
        assert_file_contains "$config_file" "value with spaces and 'quotes'" "Should handle special characters"
        assert_file_contains "$config_file" "# Comment with >>> markers <<< inside" "Should handle marker-like content"
        
        # Test prefix with special characters
        add_config_block "$config_file" "block-with-dashes" "export DASH_VAR=\"value\""
        assert_command_succeeds "Dashed block should exist" -- config_block_exists "$config_file" "block-with-dashes"
        
        # Remove blocks and verify they're gone
        remove_config_block "$config_file" "empty-block"
        remove_config_block "$config_file" "special-block" 
        remove_config_block "$config_file" "block-with-dashes"
        
        assert_command_fails "Empty block should be removed" -- config_block_exists "$config_file" "empty-block"
        assert_command_fails "Special block should be removed" -- config_block_exists "$config_file" "special-block"
        assert_command_fails "Dashed block should be removed" -- config_block_exists "$config_file" "block-with-dashes"
    )
}

# Register all test functions
register_tests \
    "test_ensure_config_file_exists_creates_file" \
    "test_ensure_config_file_exists_creates_parent_dirs" \
    "test_ensure_config_file_exists_preserves_existing" \
    "test_config_block_exists" \
    "test_add_config_block_creates_new_block" \
    "test_add_config_block_appends_to_existing" \
    "test_add_config_block_replaces_existing_block" \
    "test_add_config_block_handles_multiline_content" \
    "test_remove_config_block_removes_existing_block" \
    "test_remove_config_block_handles_missing_file" \
    "test_remove_config_block_handles_nonexistent_block" \
    "test_remove_config_block_handles_multiple_blocks_same_prefix" \
    "test_remove_config_block_handles_malformed_blocks" \
    "test_config_block_workflow_complete" \
    "test_config_block_edge_cases"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "Config Block Functions Tests" "$@"
fi
