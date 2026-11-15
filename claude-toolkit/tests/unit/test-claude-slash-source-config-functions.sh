#!/bin/bash
# test-claude-slash-source-config-functions.sh - Tests source configuration functions from claude-slash.sh
# 
# Purpose: Unit tests for source configuration management functions
# Dependencies: None (sources claude-slash.sh directly)
# Approach: Simulate source configurations within sandbox, test function behavior and effects

source "$(dirname "$0")/../utils/test-harness.sh"

# Source the script to get access to functions under test
source "$(dirname "$0")/../../scripts/template-management.sh"

# =============================================================================
# Helper functions for testing
# =============================================================================

# Helper function to create a sources config file with test data
create_test_sources_config() {
    local config_file
    config_file="$(get_template_sources_config_file)"
    local config_dir
    config_dir="$(dirname "$config_file")"
    
    mkdir -p "$config_dir"
    cat > "$config_file" <<'EOF'
# Claude Template Sources Configuration
# Format: source_name<TAB>git_url
# Lines starting with # are comments

claude-toolkit	https://github.com/user/claude-toolkit.git
team-alpha	https://github.com/team/alpha-commands.git
personal-utils	https://github.com/user/personal-utils.git
EOF
}

# Helper function to validate config file format
validate_config_format() {
    local config_file
    config_file="$(get_template_sources_config_file)"
    
    # Check if file exists
    [[ -f "$config_file" ]] || return 1
    
    # Check if file contains the required header (3 lines now)
    head -n 4 "$config_file" | grep -q "# Claude Template Sources Configuration" || return 1
    head -n 4 "$config_file" | grep -q "# Format: source_name<TAB>git_url" || return 1
    head -n 4 "$config_file" | grep -q "# Lines starting with # are comments" || return 1
    
    return 0
}

# Helper function to create an empty sources config with just header
create_empty_sources_config() {
    local config_file
    config_file="$(get_template_sources_config_file)"
    local config_dir
    config_dir="$(dirname "$config_file")"
    
    mkdir -p "$config_dir"
    cat > "$config_file" <<'EOF'
# Claude Template Sources Configuration
# Format: source_name<TAB>git_url
# Lines starting with # are comments

EOF
}

# =============================================================================
# Tests for read_template_sources_config function
# =============================================================================

test_read_template_sources_config_no_file() {
    (
        create_sandbox
        
        # Test reading when no config file exists
        local output
        output="$(read_template_sources_config)"
        assert_equals "" "$output" "read_template_sources_config should return empty string when no config file exists"
    )
}

test_read_template_sources_config_empty_file() {
    (
        create_sandbox
        
        create_empty_sources_config
        
        # Test reading empty config (only comments)
        local output
        output="$(read_template_sources_config)"
        assert_equals "" "$output" "read_template_sources_config should return empty string for config with only comments"
    )
}

test_read_template_sources_config_with_data() {
    (
        create_sandbox
        
        create_test_sources_config
        
        # Test reading config with data
        local output
        output="$(read_template_sources_config)"
        
        # Should contain all three sources
        assert_contains "claude-toolkit	https://github.com/user/claude-toolkit.git" "$output" "Should contain claude-toolkit source"
        assert_contains "team-alpha	https://github.com/team/alpha-commands.git" "$output" "Should contain team-alpha source"
        assert_contains "personal-utils	https://github.com/user/personal-utils.git" "$output" "Should contain personal-utils source"
        
        # Should not contain comments
        assert_not_contains "# Claude Template Sources" "$output" "Should not contain comment lines"
        assert_not_contains "# Format:" "$output" "Should not contain format comment"
        
        # Should have exactly 3 lines
        local line_count
        line_count="$(echo "$output" | wc -l | tr -d ' ')"
        assert_equals "3" "$line_count" "Should return exactly 3 lines of data"
    )
}

# =============================================================================
# Tests for write_template_sources_config function
# =============================================================================

test_write_template_sources_config_creates_file() {
    (
        create_sandbox
        
        # Write config with data from stdin
        printf '%s\t%s\n' "test-source" "https://github.com/test/repo.git" | write_template_sources_config
        
        # Verify file was created
        local config_file
        config_file="$(get_template_sources_config_file)"
        assert_file_exists "$config_file" "write_template_sources_config should create config file"
        
        # Verify file format is correct
        assert_command_succeeds "Config file should have proper format" -- validate_config_format
        
        # Verify content was written correctly
        local content
        content="$(read_template_sources_config)"
        assert_contains "test-source	https://github.com/test/repo.git" "$content" "Should contain written source"
    )
}

test_write_template_sources_config_overwrites_existing() {
    (
        create_sandbox
        
        create_test_sources_config
        
        # Verify initial content
        local initial_content
        initial_content="$(read_template_sources_config)"
        assert_contains "claude-toolkit" "$initial_content" "Should initially contain claude-toolkit"
        
        # Write new content, overwriting existing
        printf '%s\t%s\n' "new-source" "https://github.com/new/repo.git" | write_template_sources_config
        
        # Verify content was replaced
        local new_content
        new_content="$(read_template_sources_config)"
        assert_contains "new-source	https://github.com/new/repo.git" "$new_content" "Should contain new source"
        assert_not_contains "claude-toolkit" "$new_content" "Should not contain old sources"
        
        # Should have exactly 1 line now
        local line_count
        line_count="$(echo "$new_content" | wc -l | tr -d ' ')"
        assert_equals "1" "$line_count" "Should have exactly 1 line after overwrite"
    )
}

test_write_template_sources_config_empty_input() {
    (
        create_sandbox
        
        create_test_sources_config
        
        # Write empty input (should clear all sources but keep header)
        echo "" | write_template_sources_config
        
        # Verify file still exists with proper format
        local config_file
        config_file="$(get_template_sources_config_file)"
        assert_file_exists "$config_file" "Config file should still exist"
        assert_command_succeeds "Config file should maintain proper format" -- validate_config_format
        
        # Verify content is empty
        local content
        content="$(read_template_sources_config)"
        assert_equals "" "$content" "Should have no source data after empty write"
    )
}

# =============================================================================
# Tests for template_source_exists function
# =============================================================================

test_source_exists_no_config() {
    (
        create_sandbox
        
        # Test when no config file exists
        assert_command_fails "template_source_exists should fail when no config exists" -- template_source_exists "any-source"
    )
}

test_source_exists_empty_config() {
    (
        create_sandbox
        
        create_empty_sources_config
        
        # Test when config is empty
        assert_command_fails "template_source_exists should fail for empty config" -- template_source_exists "any-source"
    )
}

test_source_exists_with_data() {
    (
        create_sandbox
        
        create_test_sources_config
        
        # Test existing sources
        assert_command_succeeds "template_source_exists should succeed for claude-toolkit" -- template_source_exists "claude-toolkit"
        assert_command_succeeds "template_source_exists should succeed for team-alpha" -- template_source_exists "team-alpha"
        assert_command_succeeds "template_source_exists should succeed for personal-utils" -- template_source_exists "personal-utils"
        
        # Test non-existing sources
        assert_command_fails "template_source_exists should fail for nonexistent-source" -- template_source_exists "nonexistent-source"
        assert_command_fails "template_source_exists should fail for empty string" -- template_source_exists ""
    )
}

test_source_exists_exact_match() {
    (
        create_sandbox
        
        create_test_sources_config
        
        # Test that matching is exact (not substring)
        assert_command_fails "template_source_exists should fail for partial match 'claude'" -- template_source_exists "claude"
        assert_command_fails "template_source_exists should fail for partial match 'toolkit'" -- template_source_exists "toolkit"
        assert_command_fails "template_source_exists should fail for case mismatch 'CLAUDE-TOOLKIT'" -- template_source_exists "CLAUDE-TOOLKIT"
        
        # But exact match should work
        assert_command_succeeds "template_source_exists should succeed for exact match 'claude-toolkit'" -- template_source_exists "claude-toolkit"
    )
}

# =============================================================================
# Tests for get_template_source_url function
# =============================================================================

test_get_source_url_no_config() {
    (
        create_sandbox
        
        # Test when no config file exists
        local output
        output="$(get_template_source_url "any-source")"
        assert_equals "" "$output" "get_template_source_url should return empty string when no config exists"
    )
}

test_get_source_url_empty_config() {
    (
        create_sandbox
        
        create_empty_sources_config
        
        # Test when config is empty
        local output
        output="$(get_template_source_url "any-source")"
        assert_equals "" "$output" "get_template_source_url should return empty string for empty config"
    )
}

test_get_source_url_with_data() {
    (
        create_sandbox
        
        create_test_sources_config
        
        # Test getting URLs for existing sources
        local url1 url2 url3
        url1="$(get_template_source_url "claude-toolkit")"
        url2="$(get_template_source_url "team-alpha")"
        url3="$(get_template_source_url "personal-utils")"
        
        assert_equals "https://github.com/user/claude-toolkit.git" "$url1" "Should return correct URL for claude-toolkit"
        assert_equals "https://github.com/team/alpha-commands.git" "$url2" "Should return correct URL for team-alpha"
        assert_equals "https://github.com/user/personal-utils.git" "$url3" "Should return correct URL for personal-utils"
        
        # Test non-existing source
        local nonexistent_url
        nonexistent_url="$(get_template_source_url "nonexistent-source")"
        assert_equals "" "$nonexistent_url" "Should return empty string for nonexistent source"
    )
}

test_get_source_url_exact_match() {
    (
        create_sandbox
        
        create_test_sources_config
        
        # Test that matching is exact (not substring)
        local partial_url case_url
        partial_url="$(get_template_source_url "claude")"
        case_url="$(get_template_source_url "CLAUDE-TOOLKIT")"
        
        assert_equals "" "$partial_url" "Should return empty string for partial match 'claude'"
        assert_equals "" "$case_url" "Should return empty string for case mismatch 'CLAUDE-TOOLKIT'"
        
        # But exact match should work
        local exact_url
        exact_url="$(get_template_source_url "claude-toolkit")"
        assert_equals "https://github.com/user/claude-toolkit.git" "$exact_url" "Should return URL for exact match 'claude-toolkit'"
    )
}

test_get_source_url_handles_tabs() {
    (
        create_sandbox
        
        local config_file
        config_file="$(get_template_sources_config_file)"
        local config_dir
        config_dir="$(dirname "$config_file")"
        
        mkdir -p "$config_dir"
        # Create config with various tab scenarios
        cat > "$config_file" <<'EOF'
# Claude Template Sources Configuration
# Format: source_name<TAB>git_url
# Lines starting with # are comments

normal-source	https://github.com/user/normal.git
source-with-spaces	https://github.com/user/repo with spaces.git
source-with-query	https://github.com/user/repo.git?ref=main&depth=1
EOF
        
        # Test that URLs with various characters are handled correctly
        local normal_url spaces_url query_url
        normal_url="$(get_template_source_url "normal-source")"
        spaces_url="$(get_template_source_url "source-with-spaces")"
        query_url="$(get_template_source_url "source-with-query")"
        
        assert_equals "https://github.com/user/normal.git" "$normal_url" "Should handle normal URL"
        assert_equals "https://github.com/user/repo with spaces.git" "$spaces_url" "Should handle URL with spaces"
        assert_equals "https://github.com/user/repo.git?ref=main&depth=1" "$query_url" "Should handle URL with query parameters"
    )
}

# =============================================================================
# Tests for add_template_source_to_config function
# =============================================================================

test_add_source_to_config_to_empty() {
    (
        create_sandbox
        
        # Test adding to non-existent config
        add_template_source_to_config "new-source" "https://github.com/user/new.git"
        
        # Verify config was created
        local config_file
        config_file="$(get_template_sources_config_file)"
        assert_file_exists "$config_file" "Config file should be created"
        assert_command_succeeds "Config file should have proper format" -- validate_config_format
        
        # Verify source was added
        local content
        content="$(read_template_sources_config)"
        assert_contains "new-source	https://github.com/user/new.git" "$content" "Should contain added source"
        
        # Should have exactly 1 line
        local line_count
        line_count="$(echo "$content" | wc -l | tr -d ' ')"
        assert_equals "1" "$line_count" "Should have exactly 1 source"
    )
}

test_add_source_to_config_to_existing() {
    (
        create_sandbox
        
        create_test_sources_config
        
        # Verify initial state (3 sources)
        local initial_content
        initial_content="$(read_template_sources_config)"
        local initial_count
        initial_count="$(echo "$initial_content" | wc -l | tr -d ' ')"
        assert_equals "3" "$initial_count" "Should initially have 3 sources"
        
        # Add new source
        add_template_source_to_config "new-source" "https://github.com/user/new.git"
        
        # Verify source was added
        local updated_content
        updated_content="$(read_template_sources_config)"
        assert_contains "new-source	https://github.com/user/new.git" "$updated_content" "Should contain newly added source"
        
        # Verify old sources still exist
        assert_contains "claude-toolkit	https://github.com/user/claude-toolkit.git" "$updated_content" "Should still contain claude-toolkit"
        assert_contains "team-alpha	https://github.com/team/alpha-commands.git" "$updated_content" "Should still contain team-alpha"
        assert_contains "personal-utils	https://github.com/user/personal-utils.git" "$updated_content" "Should still contain personal-utils"
        
        # Should have 4 sources now
        local updated_count
        updated_count="$(echo "$updated_content" | wc -l | tr -d ' ')"
        assert_equals "4" "$updated_count" "Should have 4 sources after addition"
    )
}

test_add_source_to_config_duplicate_name() {
    (
        create_sandbox
        
        create_test_sources_config
        
        # Attempt to add source with duplicate name (should fail)
        assert_command_fails "add_template_source_to_config should fail for duplicate source name" -- add_template_source_to_config "claude-toolkit" "https://github.com/different/repo.git"
        
        # Verify original entry still exists and no duplicate was added
        local content
        content="$(read_template_sources_config)"
        assert_contains "claude-toolkit	https://github.com/user/claude-toolkit.git" "$content" "Should contain original claude-toolkit source"
        assert_not_contains "https://github.com/different/repo.git" "$content" "Should not contain new duplicate source"
        
        # Should still have 3 sources (no addition)
        local line_count
        line_count="$(echo "$content" | wc -l | tr -d ' ')"
        assert_equals "3" "$line_count" "Should still have 3 sources after failed duplicate addition"
    )
}

test_add_source_to_config_special_characters() {
    (
        create_sandbox
        
        # Test adding sources with special characters
        add_template_source_to_config "source-with-dashes" "https://github.com/user/repo-with-dashes.git"
        add_template_source_to_config "source_with_underscores" "https://github.com/user/repo_with_underscores.git"
        add_template_source_to_config "source.with.dots" "https://github.com/user/repo.with.dots.git"
        
        # Verify all sources were added correctly
        local content
        content="$(read_template_sources_config)"
        assert_contains "source-with-dashes	https://github.com/user/repo-with-dashes.git" "$content" "Should handle dashes in name and URL"
        assert_contains "source_with_underscores	https://github.com/user/repo_with_underscores.git" "$content" "Should handle underscores in name and URL"
        assert_contains "source.with.dots	https://github.com/user/repo.with.dots.git" "$content" "Should handle dots in name and URL"
        
        # Should have 3 sources
        local line_count
        line_count="$(echo "$content" | wc -l | tr -d ' ')"
        assert_equals "3" "$line_count" "Should have 3 sources with special characters"
    )
}

# =============================================================================
# Tests for remove_template_source_from_config function
# =============================================================================

test_remove_source_from_config_no_config() {
    (
        create_sandbox
        
        # Test removing from non-existent config (should not fail)
        remove_template_source_from_config "any-source"
        
        # Should create empty config file
        local config_file
        config_file="$(get_template_sources_config_file)"
        assert_file_exists "$config_file" "Config file should be created"
        assert_command_succeeds "Config file should have proper format" -- validate_config_format
        
        # Should have no sources
        local content
        content="$(read_template_sources_config)"
        assert_equals "" "$content" "Should have no sources after removing from empty config"
    )
}

test_remove_source_from_config_existing() {
    (
        create_sandbox
        
        create_test_sources_config
        
        # Verify initial state (3 sources)
        local initial_content
        initial_content="$(read_template_sources_config)"
        local initial_count
        initial_count="$(echo "$initial_content" | wc -l | tr -d ' ')"
        assert_equals "3" "$initial_count" "Should initially have 3 sources"
        
        # Remove one source
        remove_template_source_from_config "team-alpha"
        
        # Verify source was removed
        local updated_content
        updated_content="$(read_template_sources_config)"
        assert_not_contains "team-alpha	https://github.com/team/alpha-commands.git" "$updated_content" "Should not contain removed source"
        
        # Verify other sources still exist
        assert_contains "claude-toolkit	https://github.com/user/claude-toolkit.git" "$updated_content" "Should still contain claude-toolkit"
        assert_contains "personal-utils	https://github.com/user/personal-utils.git" "$updated_content" "Should still contain personal-utils"
        
        # Should have 2 sources now
        local updated_count
        updated_count="$(echo "$updated_content" | wc -l | tr -d ' ')"
        assert_equals "2" "$updated_count" "Should have 2 sources after removal"
    )
}

test_remove_source_from_config_nonexistent() {
    (
        create_sandbox
        
        create_test_sources_config
        
        # Remove non-existent source
        remove_template_source_from_config "nonexistent-source"
        
        # Verify all original sources still exist
        local content
        content="$(read_template_sources_config)"
        assert_contains "claude-toolkit	https://github.com/user/claude-toolkit.git" "$content" "Should still contain claude-toolkit"
        assert_contains "team-alpha	https://github.com/team/alpha-commands.git" "$content" "Should still contain team-alpha"
        assert_contains "personal-utils	https://github.com/user/personal-utils.git" "$content" "Should still contain personal-utils"
        
        # Should still have 3 sources
        local line_count
        line_count="$(echo "$content" | wc -l | tr -d ' ')"
        assert_equals "3" "$line_count" "Should still have 3 sources after removing nonexistent"
    )
}

test_remove_source_from_config_duplicate_names() {
    # This test is no longer applicable since add_template_source_to_config now prevents duplicates
    # Keeping as a placeholder to document the changed behavior
    (
        create_sandbox
        
        create_test_sources_config
        
        # Verify we cannot create duplicates in the first place
        assert_command_fails "Should not be able to add duplicate source" -- add_template_source_to_config "claude-toolkit" "https://github.com/different/repo.git"
        
        # Verify original still exists and count is unchanged
        local content
        content="$(read_template_sources_config)"
        local claude_count
        claude_count="$(echo "$content" | grep -c "claude-toolkit")"
        assert_equals "1" "$claude_count" "Should have only 1 claude-toolkit entry (no duplicates possible)"
        
        # Should still have 3 sources total
        local total_count
        total_count="$(echo "$content" | wc -l | tr -d ' ')"
        assert_equals "3" "$total_count" "Should still have 3 sources total"
    )
}

test_remove_source_from_config_last_source() {
    (
        create_sandbox
        
        # Create config with single source
        printf '%s\t%s\n' "only-source" "https://github.com/user/only.git" | write_template_sources_config
        
        # Verify single source exists
        local initial_content
        initial_content="$(read_template_sources_config)"
        assert_contains "only-source" "$initial_content" "Should initially contain only-source"
        
        # Remove the only source
        remove_template_source_from_config "only-source"
        
        # Verify config is now empty but file still exists with proper format
        local config_file
        config_file="$(get_template_sources_config_file)"
        assert_file_exists "$config_file" "Config file should still exist"
        assert_command_succeeds "Config file should maintain proper format" -- validate_config_format
        
        local final_content
        final_content="$(read_template_sources_config)"
        assert_equals "" "$final_content" "Should have no sources after removing last one"
    )
}

# =============================================================================
# Tests for expand_template_source_list function
# =============================================================================

test_expand_source_list_all_no_config() {
    (
        create_sandbox
        
        # Test expanding "all" when no config file exists
        local output
        output="$(expand_template_source_list "all")"
        assert_equals "" "$output" "expand_template_source_list should return empty string for 'all' when no config exists"
    )
}

test_expand_source_list_all_empty_config() {
    (
        create_sandbox
        
        create_empty_sources_config
        
        # Test expanding "all" with empty config (only comments)
        local output
        output="$(expand_template_source_list "all")"
        assert_equals "" "$output" "expand_template_source_list should return empty string for 'all' with empty config"
    )
}

test_expand_source_list_all_with_data() {
    (
        create_sandbox
        
        create_test_sources_config
        
        # Test expanding "all" with data - should return full CSV format
        local output
        output="$(expand_template_source_list "all")"
        
        # Should contain all three sources in full format
        assert_contains "claude-toolkit	https://github.com/user/claude-toolkit.git" "$output" "Should contain claude-toolkit with URL"
        assert_contains "team-alpha	https://github.com/team/alpha-commands.git" "$output" "Should contain team-alpha with URL"
        assert_contains "personal-utils	https://github.com/user/personal-utils.git" "$output" "Should contain personal-utils with URL"
        
        # Should have exactly 3 lines
        local line_count
        line_count="$(echo "$output" | wc -l | tr -d ' ')"
        assert_equals "3" "$line_count" "Should return exactly 3 lines of data"
        
        # Each line should be in tab-separated format
        local line1 line2 line3
        line1="$(echo "$output" | sed -n '1p')"
        line2="$(echo "$output" | sed -n '2p')"
        line3="$(echo "$output" | sed -n '3p')"
        
        # Verify tab-separated format (should contain tabs and URLs)
        assert_matches ".*	.*" "$line1" "First line should be tab-separated"
        assert_matches ".*	.*" "$line2" "Second line should be tab-separated"
        assert_matches ".*	.*" "$line3" "Third line should be tab-separated"
    )
}

test_expand_source_list_user_virtual_source() {
    (
        create_sandbox
        
        create_test_sources_config
        
        # Test expanding "user" virtual source
        local output
        output="$(expand_template_source_list "user")"
        
        # Should return "user" with tab but empty URL
        assert_equals "user	" "$output" "Should return 'user' with tab for virtual source"
    )
}

test_expand_source_list_single_source_exists() {
    (
        create_sandbox
        
        create_test_sources_config
        
        # Test expanding single existing source
        local output1 output2 output3
        output1="$(expand_template_source_list "claude-toolkit")"
        output2="$(expand_template_source_list "team-alpha")"
        output3="$(expand_template_source_list "personal-utils")"
        
        assert_equals "claude-toolkit	https://github.com/user/claude-toolkit.git" "$output1" "Should return full record for claude-toolkit"
        assert_equals "team-alpha	https://github.com/team/alpha-commands.git" "$output2" "Should return full record for team-alpha"
        assert_equals "personal-utils	https://github.com/user/personal-utils.git" "$output3" "Should return full record for personal-utils"
    )
}

test_expand_source_list_single_source_not_exists() {
    (
        create_sandbox
        
        create_test_sources_config
        
        # Test expanding non-existent source (should fail with error)
        local output
        if output="$(expand_template_source_list "nonexistent-source" 2>/dev/null)"; then
            fail "expand_template_source_list should fail for non-existent source"
        else
            local exit_code=$?
            assert_equals "1" "$exit_code" "Should return exit code 1 for non-existent source"
        fi
    )
}

test_expand_source_list_single_user_source() {
    (
        create_sandbox
        
        create_test_sources_config
        
        # Test expanding single "user" source (should work even in single mode)
        local output
        output="$(expand_template_source_list "user")"
        assert_equals "user	" "$output" "Should return 'user' with tab when specified as single source"
    )
}

test_expand_source_list_comma_separated_all_exist() {
    (
        create_sandbox
        
        create_test_sources_config
        
        # Test expanding comma-separated list where all sources exist
        local output
        output="$(expand_template_source_list "claude-toolkit,team-alpha")"
        
        # Should contain both sources in full format
        assert_contains "claude-toolkit	https://github.com/user/claude-toolkit.git" "$output" "Should contain claude-toolkit with URL"
        assert_contains "team-alpha	https://github.com/team/alpha-commands.git" "$output" "Should contain team-alpha with URL"
        
        # Should have exactly 2 lines
        local line_count
        line_count="$(echo "$output" | wc -l | tr -d ' ')"
        assert_equals "2" "$line_count" "Should return exactly 2 lines for comma-separated list"
    )
}

test_expand_source_list_comma_separated_with_user() {
    (
        create_sandbox
        
        create_test_sources_config
        
        # Test expanding comma-separated list including virtual "user" source
        local output
        output="$(expand_template_source_list "user,claude-toolkit")"
        
        # Should contain both sources
        assert_contains "user	" "$output" "Should contain user with tab"
        assert_contains "claude-toolkit	https://github.com/user/claude-toolkit.git" "$output" "Should contain claude-toolkit with URL"
        
        # Should have exactly 2 lines
        local line_count
        line_count="$(echo "$output" | wc -l | tr -d ' ')"
        assert_equals "2" "$line_count" "Should return exactly 2 lines including virtual user source"
    )
}

test_expand_source_list_comma_separated_some_missing() {
    (
        create_sandbox
        
        create_test_sources_config
        
        # Test expanding comma-separated list where some sources don't exist (should fail)
        local output
        if output="$(expand_template_source_list "claude-toolkit,nonexistent-source" 2>/dev/null)"; then
            fail "expand_template_source_list should fail when some sources in comma-separated list don't exist"
        else
            local exit_code=$?
            assert_equals "1" "$exit_code" "Should return exit code 1 when some sources don't exist"
        fi
    )
}

test_expand_source_list_comma_separated_all_missing() {
    (
        create_sandbox
        
        create_test_sources_config
        
        # Test expanding comma-separated list where all sources don't exist (should fail on first)
        local output
        if output="$(expand_template_source_list "nonexistent1,nonexistent2" 2>/dev/null)"; then
            fail "expand_template_source_list should fail when all sources in comma-separated list don't exist"
        else
            local exit_code=$?
            assert_equals "1" "$exit_code" "Should return exit code 1 when all sources don't exist"
        fi
    )
}

test_expand_source_list_empty_source_spec() {
    (
        create_sandbox
        
        create_test_sources_config
        
        # Test with empty source specification (should be handled as single source case)
        local output
        if output="$(expand_template_source_list "" 2>/dev/null)"; then
            fail "expand_template_source_list should fail for empty source spec"
        else
            local exit_code=$?
            assert_equals "1" "$exit_code" "Should return exit code 1 for empty source spec"
        fi
    )
}

test_expand_source_list_format_consistency() {
    (
        create_sandbox
        
        create_test_sources_config
        
        # Test that format is consistent with read_template_sources_config output
        local sources_config_output expand_all_output
        sources_config_output="$(read_template_sources_config)"
        expand_all_output="$(expand_template_source_list "all")"
        
        assert_equals "$sources_config_output" "$expand_all_output" "expand_template_source_list 'all' should return same format as read_template_sources_config"
    )
}

test_expand_source_list_preserves_order() {
    (
        create_sandbox
        
        # Create config in specific order to test ordering
        {
            echo "zebra-source	https://github.com/user/zebra.git"
            echo "alpha-source	https://github.com/user/alpha.git"
            echo "beta-source	https://github.com/user/beta.git"
        } | write_template_sources_config
        
        # Test that expand_template_source_list preserves alphabetical order (sorted by write_template_sources_config)
        local output
        output="$(expand_template_source_list "all")"
        
        local line1 line2 line3
        line1="$(echo "$output" | sed -n '1p')"
        line2="$(echo "$output" | sed -n '2p')"
        line3="$(echo "$output" | sed -n '3p')"
        
        assert_equals "alpha-source	https://github.com/user/alpha.git" "$line1" "First line should be alpha-source (alphabetically sorted)"
        assert_equals "beta-source	https://github.com/user/beta.git" "$line2" "Second line should be beta-source (alphabetically sorted)"
        assert_equals "zebra-source	https://github.com/user/zebra.git" "$line3" "Third line should be zebra-source (alphabetically sorted)"
    )
}

test_expand_source_list_handles_special_characters_in_urls() {
    (
        create_sandbox
        
        # Create config with URLs containing special characters
        local config_file
        config_file="$(get_template_sources_config_file)"
        local config_dir
        config_dir="$(dirname "$config_file")"
        
        mkdir -p "$config_dir"
        cat > "$config_file" <<'EOF'
# Claude Template Sources Configuration
# Format: source_name<TAB>git_url
# Lines starting with # are comments

source-with-query	https://github.com/user/repo.git?ref=main&depth=1
source-with-spaces	https://github.com/user/repo with spaces.git
EOF
        
        # Test that URLs with special characters are preserved correctly
        local output1 output2
        output1="$(expand_template_source_list "source-with-query")"
        output2="$(expand_template_source_list "source-with-spaces")"
        
        assert_equals "source-with-query	https://github.com/user/repo.git?ref=main&depth=1" "$output1" "Should preserve URL with query parameters"
        assert_equals "source-with-spaces	https://github.com/user/repo with spaces.git" "$output2" "Should preserve URL with spaces"
    )
}

# Tests for listing configured sources function
# =============================================================================

test_list_configured_sources_no_config() {
    (
        create_sandbox
        
        # Test reading when no config file exists
        local output
        output="$(read_template_sources_config | cut -f1)"
        assert_equals "" "$output" "list configured sources should return empty string when no config exists"
    )
}

test_list_configured_sources_empty_config() {
    (
        create_sandbox
        
        create_empty_sources_config
        
        # Test reading empty config (only comments)
        local output
        output="$(read_template_sources_config | cut -f1)"
        assert_equals "" "$output" "list configured sources should return empty string for empty config"
    )
}

test_list_configured_sources_with_data() {
    (
        create_sandbox
        
        create_test_sources_config
        
        # Test listing sources
        local output
        output="$(read_template_sources_config | cut -f1)"
        
        # Should contain all source names
        assert_contains "claude-toolkit" "$output" "Should contain claude-toolkit"
        assert_contains "team-alpha" "$output" "Should contain team-alpha"
        assert_contains "personal-utils" "$output" "Should contain personal-utils"
        
        # Should not contain URLs
        assert_not_contains "https://github.com/" "$output" "Should not contain URLs"
        
        # Should have exactly 3 lines
        local line_count
        line_count="$(echo "$output" | wc -l | tr -d ' ')"
        assert_equals "3" "$line_count" "Should return exactly 3 source names"
        
        # Each line should be just the source name (no tabs or URLs)
        local line1 line2 line3
        line1="$(echo "$output" | sed -n '1p')"
        line2="$(echo "$output" | sed -n '2p')"
        line3="$(echo "$output" | sed -n '3p')"
        
        # Note: The order may vary depending on how the sources are read
        # We just check that each line contains only source name characters
        assert_matches "^[a-zA-Z0-9_.-]+$" "$line1" "First line should contain only source name characters"
        assert_matches "^[a-zA-Z0-9_.-]+$" "$line2" "Second line should contain only source name characters"
        assert_matches "^[a-zA-Z0-9_.-]+$" "$line3" "Third line should contain only source name characters"
    )
}

test_list_configured_sources_preserves_order() {
    (
        create_sandbox
        
        # Create config in specific order
        {
            echo "zebra-source	https://github.com/user/zebra.git"
            echo "alpha-source	https://github.com/user/alpha.git"
            echo "beta-source	https://github.com/user/beta.git"
        } | write_template_sources_config
        
        # Test that sources are returned in alphabetical order (sorted by write_template_sources_config)
        local output
        output="$(read_template_sources_config | cut -f1)"
        
        local line1 line2 line3
        line1="$(echo "$output" | sed -n '1p')"
        line2="$(echo "$output" | sed -n '2p')"
        line3="$(echo "$output" | sed -n '3p')"
        
        assert_equals "alpha-source" "$line1" "First source should be alpha-source (alphabetically sorted)"
        assert_equals "beta-source" "$line2" "Second source should be beta-source (alphabetically sorted)"
        assert_equals "zebra-source" "$line3" "Third source should be zebra-source (alphabetically sorted)"
    )
}

# =============================================================================
# Integration tests for function interactions
# =============================================================================

test_add_and_remove_source_integration() {
    (
        create_sandbox
        
        # Start with empty config, add sources, then remove them
        
        # Add first source
        add_template_source_to_config "source1" "https://github.com/user/repo1.git"
        assert_command_succeeds "source1 should exist after adding" -- template_source_exists "source1"
        
        local url1
        url1="$(get_template_source_url "source1")"
        assert_equals "https://github.com/user/repo1.git" "$url1" "source1 URL should be correct"
        
        local sources
        sources="$(read_template_sources_config | cut -f1)"
        assert_contains "source1" "$sources" "source1 should appear in list"
        
        # Add second source
        add_template_source_to_config "source2" "https://github.com/user/repo2.git"
        assert_command_succeeds "source2 should exist after adding" -- template_source_exists "source2"
        assert_command_succeeds "source1 should still exist" -- template_source_exists "source1"
        
        sources="$(read_template_sources_config | cut -f1)"
        assert_contains "source1" "$sources" "source1 should still appear in list"
        assert_contains "source2" "$sources" "source2 should appear in list"
        
        # Remove first source
        remove_template_source_from_config "source1"
        assert_command_fails "source1 should not exist after removal" -- template_source_exists "source1"
        assert_command_succeeds "source2 should still exist" -- template_source_exists "source2"
        
        local url1_after_removal
        url1_after_removal="$(get_template_source_url "source1")"
        assert_equals "" "$url1_after_removal" "source1 URL should be empty after removal"
        
        sources="$(read_template_sources_config | cut -f1)"
        assert_not_contains "source1" "$sources" "source1 should not appear in list after removal"
        assert_contains "source2" "$sources" "source2 should still appear in list"
    )
}

test_write_config_and_read_integration() {
    (
        create_sandbox
        
        # Create data and write it using write_template_sources_config
        local test_data
        test_data="source3	https://github.com/user/repo3.git
source1	https://github.com/user/repo1.git
source2	https://github.com/user/repo2.git"
        
        echo "$test_data" | write_template_sources_config
        
        # Test that all functions work with the written data
        assert_command_succeeds "source1 should exist" -- template_source_exists "source1"
        assert_command_succeeds "source2 should exist" -- template_source_exists "source2"
        assert_command_succeeds "source3 should exist" -- template_source_exists "source3"
        assert_command_fails "nonexistent should not exist" -- template_source_exists "nonexistent"
        
        local url1 url2 url3
        url1="$(get_template_source_url "source1")"
        url2="$(get_template_source_url "source2")"
        url3="$(get_template_source_url "source3")"
        
        assert_equals "https://github.com/user/repo1.git" "$url1" "source1 URL should be correct"
        assert_equals "https://github.com/user/repo2.git" "$url2" "source2 URL should be correct"
        assert_equals "https://github.com/user/repo3.git" "$url3" "source3 URL should be correct"
        
        local sources
        sources="$(read_template_sources_config | cut -f1)"
        assert_contains "source1" "$sources" "source1 should appear in list"
        assert_contains "source2" "$sources" "source2 should appear in list"
        assert_contains "source3" "$sources" "source3 should appear in list"
        
        local line_count
        line_count="$(echo "$sources" | wc -l | tr -d ' ')"
        assert_equals "3" "$line_count" "Should list exactly 3 sources"
        
        # Test read_template_sources_config returns data in alphabetical order (not original order)
        local read_data expected_sorted_data
        read_data="$(read_template_sources_config)"
        expected_sorted_data="source1	https://github.com/user/repo1.git
source2	https://github.com/user/repo2.git
source3	https://github.com/user/repo3.git"
        assert_equals "$expected_sorted_data" "$read_data" "read_template_sources_config should return data in alphabetical order"
    )
}

test_duplicate_source_handling_integration() {
    (
        create_sandbox
        
        # Add source first time (should succeed)
        assert_command_succeeds "First add should succeed" -- add_template_source_to_config "duplicate-source" "https://github.com/first/repo.git"
        
        # template_source_exists should return true
        assert_command_succeeds "duplicate-source should exist after first add" -- template_source_exists "duplicate-source"
        
        # get_template_source_url should return the URL
        local url
        url="$(get_template_source_url "duplicate-source")"
        assert_equals "https://github.com/first/repo.git" "$url" "Should return URL of the source"
        
        # Attempt to add same source name again (should fail)
        assert_command_fails "Second add with same name should fail" -- add_template_source_to_config "duplicate-source" "https://github.com/second/repo.git"
        
        # template_source_exists should still return true (original still exists)
        assert_command_succeeds "duplicate-source should still exist after failed add" -- template_source_exists "duplicate-source"
        
        # get_template_source_url should still return original URL
        url="$(get_template_source_url "duplicate-source")"
        assert_equals "https://github.com/first/repo.git" "$url" "Should still return original URL after failed duplicate add"
        
        # list_configured_sources should show only one entry
        local sources
        sources="$(read_template_sources_config | cut -f1)"
        local duplicate_count
        duplicate_count="$(echo "$sources" | grep -c "duplicate-source")"
        assert_equals "1" "$duplicate_count" "Should list only one entry for the source"
        
        # Removing should work normally
        remove_template_source_from_config "duplicate-source"
        assert_command_fails "duplicate-source should not exist after removal" -- template_source_exists "duplicate-source"
    )
}

test_empty_to_populated_to_empty_cycle() {
    (
        create_sandbox
        
        # Start with empty (no config file)
        assert_command_fails "No sources should exist initially" -- template_source_exists "any-source"
        
        local empty_list
        empty_list="$(read_template_sources_config | cut -f1)"
        assert_equals "" "$empty_list" "Should have empty source list initially"
        
        # Add sources
        add_template_source_to_config "source1" "https://github.com/user/repo1.git"
        add_template_source_to_config "source2" "https://github.com/user/repo2.git"
        
        # Verify populated state
        assert_command_succeeds "source1 should exist" -- template_source_exists "source1"
        assert_command_succeeds "source2 should exist" -- template_source_exists "source2"
        
        local populated_list
        populated_list="$(read_template_sources_config | cut -f1)"
        local populated_count
        populated_count="$(echo "$populated_list" | wc -l | tr -d ' ')"
        assert_equals "2" "$populated_count" "Should have 2 sources when populated"
        
        # Remove all sources
        remove_template_source_from_config "source1"
        remove_template_source_from_config "source2"
        
        # Verify empty state again
        assert_command_fails "source1 should not exist after removal" -- template_source_exists "source1"
        assert_command_fails "source2 should not exist after removal" -- template_source_exists "source2"
        
        local final_list
        final_list="$(read_template_sources_config | cut -f1)"
        assert_equals "" "$final_list" "Should have empty source list after removing all"
        
        # Config file should still exist with proper format
        local config_file
        config_file="$(get_template_sources_config_file)"
        assert_file_exists "$config_file" "Config file should exist after cycle"
        assert_command_succeeds "Config file should maintain proper format" -- validate_config_format
    )
}

# Register all test functions
register_tests \
    "test_read_template_sources_config_no_file" \
    "test_read_template_sources_config_empty_file" \
    "test_read_template_sources_config_with_data" \
    "test_write_template_sources_config_creates_file" \
    "test_write_template_sources_config_overwrites_existing" \
    "test_write_template_sources_config_empty_input" \
    "test_source_exists_no_config" \
    "test_source_exists_empty_config" \
    "test_source_exists_with_data" \
    "test_source_exists_exact_match" \
    "test_get_source_url_no_config" \
    "test_get_source_url_empty_config" \
    "test_get_source_url_with_data" \
    "test_get_source_url_exact_match" \
    "test_get_source_url_handles_tabs" \
    "test_add_source_to_config_to_empty" \
    "test_add_source_to_config_to_existing" \
    "test_add_source_to_config_duplicate_name" \
    "test_add_source_to_config_special_characters" \
    "test_remove_source_from_config_no_config" \
    "test_remove_source_from_config_existing" \
    "test_remove_source_from_config_nonexistent" \
    "test_remove_source_from_config_duplicate_names" \
    "test_remove_source_from_config_last_source" \
    "test_expand_source_list_all_no_config" \
    "test_expand_source_list_all_empty_config" \
    "test_expand_source_list_all_with_data" \
    "test_expand_source_list_user_virtual_source" \
    "test_expand_source_list_single_source_exists" \
    "test_expand_source_list_single_source_not_exists" \
    "test_expand_source_list_single_user_source" \
    "test_expand_source_list_comma_separated_all_exist" \
    "test_expand_source_list_comma_separated_with_user" \
    "test_expand_source_list_comma_separated_some_missing" \
    "test_expand_source_list_comma_separated_all_missing" \
    "test_expand_source_list_empty_source_spec" \
    "test_expand_source_list_format_consistency" \
    "test_expand_source_list_preserves_order" \
    "test_expand_source_list_handles_special_characters_in_urls" \
    "test_list_configured_sources_no_config" \
    "test_list_configured_sources_empty_config" \
    "test_list_configured_sources_with_data" \
    "test_list_configured_sources_preserves_order" \
    "test_add_and_remove_source_integration" \
    "test_write_config_and_read_integration" \
    "test_duplicate_source_handling_integration" \
    "test_empty_to_populated_to_empty_cycle"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "claude-slash.sh Source Configuration Functions Unit Tests" "$@"
fi
