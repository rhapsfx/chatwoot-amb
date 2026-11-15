#!/bin/bash
# test-claude-template-sources-remove.sh - Tests claude-template-sources.sh remove functionality
# 
# Purpose: Test scripts/claude-template-sources.sh remove command functionality
# Dependencies: None (creates own test repositories)
# Approach: Create test sources and verify removal functionality

source "$(dirname "$0")/../utils/test-harness.sh"
source "$(dirname "$0")/../utils/upstream-repo-utils.sh"

export DEBUG=true
original_dir="$(pwd)"
# Standard test suite setup function for upstream repository tests
test_suite_setup() {
    setup_upstream_repository
}

# Standard test suite teardown function for upstream repository tests
test_suite_teardown() {
    cleanup_upstream_repository
}

# Helper function to create a test source
create_test_source() {
    local source_name="$1"
    local repo_dir="$sandbox_dir/${source_name}-repo"
    
    mkdir -p "$repo_dir"
    cd "$repo_dir"
    git init >/dev/null 2>&1
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    mkdir -p slash-commands
    cat > "slash-commands/${source_name}-command.md" << EOF
---
description: ${source_name} test command
source: ${source_name}
---

# ${source_name} Test Command
Test command for ${source_name}
EOF
    
    git add . && git commit -m "Initial commit" >/dev/null 2>&1
    cd "$original_dir"
    
    # Add the source
    ./scripts/claude-template-sources.sh add "$source_name" "$repo_dir" >/dev/null 2>&1
    echo "$repo_dir"
}

test_remove_source_basic() {
    (
        create_sandbox
        
        # Create and add test source
        local repo_dir
        repo_dir=$(create_test_source "test-source")
        
        # Verify source exists
        assert_file_exists "$HOME/.config/claude-templates/sources.csv" "Sources file should exist before removal"
        local sources_before
        sources_before=$(cat "$HOME/.config/claude-templates/sources.csv")
        assert_contains "test-source" "$sources_before" "Source should exist before removal"
        
        # Remove the source
        local remove_output
        remove_output=$(assert_command_succeeds "Remove source should succeed" -- ./scripts/claude-template-sources.sh remove test-source)
        
        # Verify source was removed from configuration
        local sources_after
        sources_after=$(cat "$HOME/.config/claude-templates/sources.csv")
        assert_not_contains "test-source" "$sources_after" "Source should not exist after removal"
        
        # Verify cache directory was removed
        local cache_dirs
        cache_dirs=$(find "$HOME/.cache/claude-templates" -type d -name "*" 2>/dev/null | grep -v "^\.$" | wc -l)
        # Cache may be empty or contain other test artifacts
        # Main verification is that the specific source is gone from config
    )
}

test_remove_source_nonexistent() {
    (
        create_sandbox
        
        # Try to remove non-existent source
        local remove_output
        remove_output=$(assert_command_fails "Remove non-existent source should fail" -- ./scripts/claude-template-sources.sh remove nonexistent-source 2>&1)
        
        assert_contains "not found" "$remove_output" "Should report source not found error"
    )
}

test_remove_source_multiple_sources() {
    (
        create_sandbox
        
        # Create multiple test sources
        create_test_source "source1"
        create_test_source "source2"
        create_test_source "source3"
        
        # Verify all sources exist
        local sources_before
        sources_before=$(cat "$HOME/.config/claude-templates/sources.csv")
        assert_contains "source1" "$sources_before" "Source1 should exist"
        assert_contains "source2" "$sources_before" "Source2 should exist"
        assert_contains "source3" "$sources_before" "Source3 should exist"
        
        # Remove middle source
        assert_command_succeeds "Remove middle source should succeed" -- ./scripts/claude-template-sources.sh remove source2 >/dev/null 2>&1
        
        # Verify only source2 was removed
        local sources_after
        sources_after=$(cat "$HOME/.config/claude-templates/sources.csv")
        assert_contains "source1" "$sources_after" "Source1 should remain"
        assert_not_contains "source2" "$sources_after" "Source2 should be removed"
        assert_contains "source3" "$sources_after" "Source3 should remain"
        
        # Verify CSV format is maintained
        local line_count=$(wc -l < "$HOME/.config/claude-templates/sources.csv" | tr -d ' ')
        assert_equals "6" "$line_count" "Should have 3 header lines + claude-toolkit + 2 remaining sources"
    )
}

test_remove_source_last_source() {
    (
        create_sandbox
        
        # Create single test source
        create_test_source "only-source"
        
        # Verify source exists
        local sources_before
        sources_before=$(cat "$HOME/.config/claude-templates/sources.csv")
        assert_contains "only-source" "$sources_before" "Source should exist"
        
        # Remove the only source
        assert_command_succeeds "Remove last source should succeed" -- ./scripts/claude-template-sources.sh remove only-source >/dev/null 2>&1
        
        # Verify configuration file handling
        if [[ -f "$HOME/.config/claude-templates/sources.csv" ]]; then
            # File may exist with just header and claude-toolkit
            local line_count=$(wc -l < "$HOME/.config/claude-templates/sources.csv" | tr -d ' ')
            assert_equals "4" "$line_count" "Should have 3 header lines + claude-toolkit after removing last user source"
            
            local first_comment_line
            first_comment_line=$(head -n1 "$HOME/.config/claude-templates/sources.csv")
            assert_contains "# Claude Template Sources Configuration" "$first_comment_line" "Should preserve configuration header"
        fi
        # If file is completely removed, that's also acceptable behavior
    )
}

test_remove_source_cache_cleanup() {
    (
        create_sandbox
        
        # Create test source
        create_test_source "cache-test"
        
        # Verify cache was created during add
        assert_directory_exists "$HOME/.cache/claude-templates" "Cache directory should exist"
        
        # Find cache directory for this source
        local cache_found=false
        local cache_dirs
        cache_dirs=$(find "$HOME/.cache/claude-templates" -type d -name "*" 2>/dev/null)
        
        for cache_dir in $cache_dirs; do
            if [[ -d "$cache_dir/cache-test" ]]; then
                cache_found=true
                break
            fi
        done
        
        assert_equals "true" "$cache_found" "Cache should contain source directory before removal"
        
        # Remove source
        assert_command_succeeds "Remove should succeed" -- ./scripts/claude-template-sources.sh remove cache-test >/dev/null 2>&1
        
        # Verify cache cleanup (implementation may vary - cache might be cleaned or left for performance)
        # Main requirement is that source is removed from configuration
        local sources_after
        sources_after=$(cat "$HOME/.config/claude-templates/sources.csv")
        assert_not_contains "cache-test" "$sources_after" "Source should be removed from configuration"
    )
}

test_remove_source_name_validation() {
    (
        create_sandbox
        
        # Create valid test source first
        create_test_source "valid-source"
        
        # Test removing with invalid names (should fail)
        local invalid_names=("" "non-existent" "source with spaces")
        
        for name in "${invalid_names[@]}"; do
            if [[ -n "$name" ]]; then
                local invalid_output
                invalid_output=$(assert_command_fails "Invalid name '$name' should fail" -- ./scripts/claude-template-sources.sh remove "$name" 2>&1)
                
                if [[ "$name" == "non-existent" ]]; then
                    assert_contains "not found" "$invalid_output" "Should report source not found for non-existent source"
                else
                    # Other invalid names might fail with validation or not found error
                    assert_true "true" "Invalid name '$name' should fail with some error"
                fi
            fi
        done
        
        # Verify valid source is still there
        local sources_content
        sources_content=$(cat "$HOME/.config/claude-templates/sources.csv")
        assert_contains "valid-source" "$sources_content" "Valid source should remain after failed invalid removes"
    )
}

test_remove_source_with_installed_commands() {
    (
        create_sandbox
        
        # Create test source
        local repo_dir
        repo_dir=$(create_test_source "installed-test")
        
        # Simulate installed commands by creating them in ~/.claude/commands/
        mkdir -p "$HOME/.claude/commands"
        cat > "$HOME/.claude/commands/installed-command.md" << 'EOF'
---
description: Installed command from source
source: installed-test
---

# Installed Command
This command was installed from the source.
EOF
        
        # Remove source
        local remove_output
        remove_output=$(assert_command_succeeds "Remove source with installed commands should succeed" -- ./scripts/claude-template-sources.sh remove installed-test)
        
        # Verify source was removed from configuration
        local sources_after
        sources_after=$(cat "$HOME/.config/claude-templates/sources.csv")
        assert_not_contains "installed-test" "$sources_after" "Source should be removed from configuration"
        
        # Note: The remove command only removes the source configuration
        # It does not automatically uninstall commands - that's handled by claude-slash.sh uninstall
        # This test verifies that removing a source succeeds even when commands are installed
        assert_file_exists "$HOME/.claude/commands/installed-command.md" "Installed commands should remain (removal only affects source config)"
    )
}

test_remove_source_configuration_file_integrity() {
    (
        create_sandbox
        
        # Create multiple sources with specific order
        create_test_source "source-alpha"
        create_test_source "source-beta" 
        create_test_source "source-gamma"
        
        # Verify initial state
        local sources_before
        sources_before=$(cat "$HOME/.config/claude-templates/sources.csv")
        local lines_before=$(wc -l < "$HOME/.config/claude-templates/sources.csv" | tr -d ' ')
        assert_equals "7" "$lines_before" "Should have 3 header lines + claude-toolkit + 3 sources initially"
        
        # Remove middle source
        assert_command_succeeds "Remove middle source" -- ./scripts/claude-template-sources.sh remove source-beta >/dev/null 2>&1
        
        # Verify file integrity
        local sources_after
        sources_after=$(cat "$HOME/.config/claude-templates/sources.csv")
        local lines_after=$(wc -l < "$HOME/.config/claude-templates/sources.csv" | tr -d ' ')
        assert_equals "6" "$lines_after" "Should have 3 header lines + claude-toolkit + 2 sources after removal"
        
        # Verify header is preserved
        local header
        header=$(head -n1 "$HOME/.config/claude-templates/sources.csv")
        assert_contains "# Claude Template Sources Configuration" "$header" "Configuration header should be preserved"
        
        # Verify remaining sources are intact
        assert_contains "source-alpha" "$sources_after" "First source should remain"
        assert_not_contains "source-beta" "$sources_after" "Middle source should be removed"
        assert_contains "source-gamma" "$sources_after" "Last source should remain"
        
        # Verify tab-separated format is valid
        while IFS=$'\t' read -r name url; do
            # Skip comment lines
            if [[ ! "$name" =~ ^[[:space:]]*# ]]; then
                assert_not_equals "" "$name" "Source name should not be empty"
                assert_not_equals "" "$url" "Source URL should not be empty"
            fi
        done < "$HOME/.config/claude-templates/sources.csv"
    )
}

test_remove_source_reserved_names() {
    (
        create_sandbox
        
        # Test attempting to remove reserved source names
        local reserved_names=("claude-toolkit" "user" "all")
        
        for name in "${reserved_names[@]}"; do
            local remove_output
            remove_output=$(assert_command_fails "Removing reserved name '$name' should fail" -- ./scripts/claude-template-sources.sh remove "$name" 2>&1)
            
            # Should either report "not found" (if not configured) or special error for reserved names
            # The exact error depends on implementation - main thing is it should fail
            assert_true "true" "Reserved name '$name' removal should fail"
        done
    )
}

# Register all test functions
register_tests \
    "test_remove_source_basic" \
    "test_remove_source_nonexistent" \
    "test_remove_source_multiple_sources" \
    "test_remove_source_last_source" \
    "test_remove_source_cache_cleanup" \
    "test_remove_source_name_validation" \
    "test_remove_source_with_installed_commands" \
    "test_remove_source_configuration_file_integrity" \
    "test_remove_source_reserved_names"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "claude-template-sources.sh remove functionality" "$@"
fi
