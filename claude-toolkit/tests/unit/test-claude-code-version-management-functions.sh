#!/bin/bash
# test-claude-code-version-management-functions.sh - Tests version management functions from claude-code.sh
# 
# Purpose: Unit tests for version management utility functions
# Dependencies: None (sources claude-code.sh directly)
# Approach: Simulate directory structures within sandbox, test function behavior

source "$(dirname "$0")/../utils/test-harness.sh"

# Source the script to get access to functions under test
source "$(dirname "$0")/../../scripts/claude-code.sh"

# Helper function to create a version directory structure
create_version_directory() {
    local version="$1"
    mkdir -p "$XDG_DATA_HOME/claude/versions/$version/nodejs/bin"
    echo "fake claude binary" > "$XDG_DATA_HOME/claude/versions/$version/nodejs/bin/claude"
    chmod +x "$XDG_DATA_HOME/claude/versions/$version/nodejs/bin/claude"
}

# Helper function to create current symlink
create_current_symlink() {
    local version="$1"
    mkdir -p "$XDG_DATA_HOME/claude"
    ln -sf "versions/$version" "$XDG_DATA_HOME/claude/current"
}

# =============================================================================
# No Versions Installed (Empty State)
# =============================================================================

test_no_versions_installed() {
    (
        create_sandbox

        # Test get_installed_versions
        local versions
        versions="$(get_installed_versions)"
        assert_equals "" "$versions" "get_installed_versions should return empty string when no versions directory exists"
        
        # Test get_installed_versions_count
        local count
        count="$(get_installed_versions_count)"
        assert_equals "0" "$count" "get_installed_versions_count should return 0 when no versions exist"
        
        # Test get_latest_installed_version
        assert_command_fails "get_latest_installed_version should fail when no versions exist" -- get_latest_installed_version

        # Test version_is_installed
        assert_command_fails "version_is_installed should fail when no versions directory exists" -- version_is_installed "1.0.0"

        # Test get_current_version
        assert_command_fails "get_current_version should fail when no current symlink exists" -- get_current_version

        # Test is_current_version
        assert_command_fails "is_current_version should fail when no current version exists" -- is_current_version "1.0.0"
        
        # Test annotate_versions
        local annotated_output
        annotated_output="$(echo -e "1.0.0\n2.0.0" | annotate_versions)"
        assert_contains "1.0.0	" "$annotated_output" "annotate_versions should include version with tab separator"
        assert_contains "2.0.0	" "$annotated_output" "annotate_versions should include second version with tab separator"
        # All versions should have empty status (no versions installed)
        local line1 line2
        line1="$(echo "$annotated_output" | head -n1)"
        line2="$(echo "$annotated_output" | tail -n1)"
        assert_equals "1.0.0	" "$line1" "annotate_versions should show empty status for non-installed version"
        assert_equals "2.0.0	" "$line2" "annotate_versions should show empty status for second non-installed version"
    )
}

# =============================================================================
# Single Version Installed
# =============================================================================

test_single_version_installed() {
    (
        create_sandbox

        create_version_directory "1.0.0"
        create_current_symlink "1.0.0"

        # Test get_installed_versions
        local versions
        versions="$(get_installed_versions)"
        assert_equals "1.0.0" "$versions" "get_installed_versions should return single installed version"

        # Test get_installed_versions_count
        local count
        count="$(get_installed_versions_count)"
        assert_equals "1" "$count" "get_installed_versions_count should return 1 for single installed version"

        # Test get_latest_installed_version
        local latest
        latest="$(get_latest_installed_version)"
        assert_equals "1.0.0" "$latest" "get_latest_installed_version should return the single installed version as latest"

        # Test version_is_installed
        assert_command_succeeds "version_is_installed should succeed for installed version" -- version_is_installed "1.0.0"
        assert_command_fails "version_is_installed should fail for non-installed version" -- version_is_installed "2.0.0"

        # Test get_current_version
        local current
        current="$(get_current_version)"
        assert_equals "1.0.0" "$current" "get_current_version should return current version from symlink"

        # Test is_current_version
        assert_command_succeeds "is_current_version should succeed for current version" -- is_current_version "1.0.0"
        assert_command_fails "is_current_version should fail for non-current version" -- is_current_version "2.0.0"
        
        # Test annotate_versions
        local annotated_output
        annotated_output="$(echo -e "1.0.0\n2.0.0\n3.0.0" | annotate_versions)"
        assert_contains "1.0.0	installed,current" "$annotated_output" "annotate_versions should show installed,current status for current version"
        assert_contains "2.0.0	" "$annotated_output" "annotate_versions should show empty status for non-installed version"
        assert_contains "3.0.0	" "$annotated_output" "annotate_versions should show empty status for another non-installed version"
    )
}

# =============================================================================
# Multiple Versions Installed
# =============================================================================

test_multiple_versions_installed() {
    (
        create_sandbox

        create_version_directory "1.0.0"
        create_version_directory "1.1.0"
        create_version_directory "2.0.0"
        create_version_directory "1.9.5"
        create_current_symlink "1.1.0"

        # Test get_installed_versions
        local versions
        versions="$(get_installed_versions)"
        local version_count
        version_count="$(echo "$versions" | wc -l | tr -d ' ')"
        assert_equals "4" "$version_count" "get_installed_versions should return 4 installed versions"
        assert_contains "1.0.0" "$versions" "get_installed_versions should contain version 1.0.0"
        assert_contains "1.1.0" "$versions" "get_installed_versions should contain version 1.1.0"
        assert_contains "2.0.0" "$versions" "get_installed_versions should contain version 2.0.0"
        assert_contains "1.9.5" "$versions" "get_installed_versions should contain version 1.9.5"

        # Test get_installed_versions_count
        local count
        count="$(get_installed_versions_count)"
        assert_equals "4" "$count" "get_installed_versions_count should return 4 for multiple installed versions"

        # Test get_latest_installed_version
        local latest
        latest="$(get_latest_installed_version)"
        assert_equals "2.0.0" "$latest" "get_latest_installed_version should return highest semantic version as latest"

        # Test version_is_installed
        assert_command_succeeds "version_is_installed should succeed for first installed version" -- version_is_installed "1.0.0"
        assert_command_succeeds "version_is_installed should succeed for second installed version" -- version_is_installed "1.1.0"
        assert_command_succeeds "version_is_installed should succeed for third installed version" -- version_is_installed "2.0.0"
        assert_command_succeeds "version_is_installed should succeed for fourth installed version" -- version_is_installed "1.9.5"
        assert_command_fails "version_is_installed should fail for non-installed version" -- version_is_installed "3.0.0"

        # Test get_current_version
        local current
        current="$(get_current_version)"
        assert_equals "1.1.0" "$current" "get_current_version should return current version from symlink"

        # Test is_current_version
        assert_command_succeeds "is_current_version should succeed for current version" -- is_current_version "1.1.0"
        assert_command_fails "is_current_version should fail for non-current installed version" -- is_current_version "1.0.0"
        assert_command_fails "is_current_version should fail for other non-current installed version" -- is_current_version "2.0.0"
        
        # Test annotate_versions
        local annotated_output
        annotated_output="$(echo -e "1.0.0\n1.1.0\n2.0.0\n1.9.5\n3.0.0" | annotate_versions)"
        assert_contains "1.0.0	installed" "$annotated_output" "annotate_versions should show installed status for non-current installed version"
        assert_contains "1.1.0	installed,current" "$annotated_output" "annotate_versions should show installed,current status for current version"
        assert_contains "2.0.0	installed" "$annotated_output" "annotate_versions should show installed status for another non-current installed version"
        assert_contains "1.9.5	installed" "$annotated_output" "annotate_versions should show installed status for fourth installed version"
        assert_contains "3.0.0	" "$annotated_output" "annotate_versions should show empty status for non-installed version"
    )
}

# =============================================================================
# Edge Case: Broken Symlink
# =============================================================================

test_broken_symlink_edge_case() {
    (
        create_sandbox

        create_version_directory "1.0.0"
        mkdir -p "$XDG_DATA_HOME/claude"
        # Create symlink pointing to non-existent version
        ln -sf "versions/2.0.0" "$XDG_DATA_HOME/claude/current"

        # Test get_installed_versions
        local versions
        versions="$(get_installed_versions)"
        assert_equals "1.0.0" "$versions" "get_installed_versions should return installed version despite broken symlink"

        # Test get_installed_versions_count
        local count
        count="$(get_installed_versions_count)"
        assert_equals "1" "$count" "get_installed_versions_count should return correct count despite broken symlink"

        # Test get_latest_installed_version
        local latest
        latest="$(get_latest_installed_version)"
        assert_equals "1.0.0" "$latest" "get_latest_installed_version should work despite broken symlink"

        # Test version_is_installed
        assert_command_succeeds "version_is_installed should succeed for existing version despite broken symlink" -- version_is_installed "1.0.0"
        assert_command_fails "version_is_installed should fail for symlink target that doesn't exist" -- version_is_installed "2.0.0"

        # Test get_current_version (should fail due to broken symlink)
        assert_command_fails "get_current_version should fail for broken symlink" -- get_current_version

        # Test is_current_version (should fail due to broken symlink)
        assert_command_fails "is_current_version should fail when symlink is broken" -- is_current_version "1.0.0"
        
        # Test annotate_versions (should work despite broken symlink)
        local annotated_output
        annotated_output="$(echo -e "1.0.0\n2.0.0" | annotate_versions)"
        assert_contains "1.0.0	installed" "$annotated_output" "annotate_versions should show installed status for existing version despite broken symlink"
        assert_contains "2.0.0	" "$annotated_output" "annotate_versions should show empty status for non-installed version despite broken symlink"
    )
}

# =============================================================================
# Edge Case: Absolute Symlink Path
# =============================================================================

test_absolute_symlink_edge_case() {
    (
        create_sandbox

        create_version_directory "1.0.0"
        mkdir -p "$XDG_DATA_HOME/claude"
        # Create absolute symlink
        ln -sf "$XDG_DATA_HOME/claude/versions/1.0.0" "$XDG_DATA_HOME/claude/current"

        # Test get_current_version with absolute symlink
        local current
        current="$(get_current_version)"
        assert_equals "1.0.0" "$current" "get_current_version should handle absolute symlink paths correctly"

        # Test is_current_version with absolute symlink
        assert_command_succeeds "is_current_version should succeed with absolute symlink" -- is_current_version "1.0.0"

        # All other functions should work normally
        local versions
        versions="$(get_installed_versions)"
        assert_equals "1.0.0" "$versions" "get_installed_versions should work with absolute symlink"

        local count
        count="$(get_installed_versions_count)"
        assert_equals "1" "$count" "get_installed_versions_count should work with absolute symlink"
        
        # Test annotate_versions with absolute symlink
        local annotated_output
        annotated_output="$(echo -e "1.0.0\n2.0.0" | annotate_versions)"
        assert_contains "1.0.0	installed,current" "$annotated_output" "annotate_versions should show installed,current status with absolute symlink"
        assert_contains "2.0.0	" "$annotated_output" "annotate_versions should show empty status for non-installed version with absolute symlink"
    )
}

# =============================================================================
# Edge Case: File Instead of Symlink
# =============================================================================

test_file_instead_of_symlink_edge_case() {
    (
        create_sandbox

        create_version_directory "1.0.0"
        mkdir -p "$XDG_DATA_HOME/claude"
        # Create regular file instead of symlink
        echo "1.0.0" > "$XDG_DATA_HOME/claude/current"

        # Test get_current_version (should fail - not a symlink)
        assert_command_fails "get_current_version should fail when current is not a symlink" -- get_current_version
        
        # Test is_current_version (should fail - not a symlink)
        assert_command_fails "is_current_version should fail when current is not a symlink" -- is_current_version "1.0.0"
        
        # All other functions should work normally
        local versions
        versions="$(get_installed_versions)"
        assert_equals "1.0.0" "$versions" "get_installed_versions should work despite file instead of symlink"
        
        local count
        count="$(get_installed_versions_count)"
        assert_equals "1" "$count" "get_installed_versions_count should work despite file instead of symlink"
        
        # Test annotate_versions (should work despite file instead of symlink)
        local annotated_output
        annotated_output="$(echo -e "1.0.0\n2.0.0" | annotate_versions)"
        assert_contains "1.0.0	installed" "$annotated_output" "annotate_versions should show installed status despite file instead of symlink"
        assert_contains "2.0.0	" "$annotated_output" "annotate_versions should show empty status for non-installed version despite file instead of symlink"
    )
}

# =============================================================================
# Edge Case: Hidden Directories and Special Characters
# =============================================================================

test_hidden_directories_and_special_characters() {
    (
        create_sandbox

        create_version_directory "1.0.0"
        create_version_directory "1.0.0-beta.1"
        create_version_directory "1.0.0-rc.2"
        create_version_directory "2.0.0-alpha"
        # Create hidden directory that should be ignored
        mkdir -p "$XDG_DATA_HOME/claude/versions/.hidden"
        echo "fake" > "$XDG_DATA_HOME/claude/versions/.hidden/claude"
        create_current_symlink "1.0.0"
        
        # Test get_installed_versions (should ignore hidden directories)
        local versions
        versions="$(get_installed_versions)"
        local version_count
        version_count="$(echo "$versions" | wc -l | tr -d ' ')"
        assert_equals "4" "$version_count" "get_installed_versions should return 4 versions (ignoring hidden directory)"
        assert_contains "1.0.0" "$versions" "get_installed_versions should contain version 1.0.0"
        assert_contains "1.0.0-beta.1" "$versions" "get_installed_versions should handle version with beta suffix"
        assert_contains "1.0.0-rc.2" "$versions" "get_installed_versions should handle version with rc suffix"
        assert_contains "2.0.0-alpha" "$versions" "get_installed_versions should handle version with alpha suffix"
        assert_not_contains ".hidden" "$versions" "get_installed_versions should ignore hidden directories"
        
        # Test get_installed_versions_count (should ignore hidden directories)
        local count
        count="$(get_installed_versions_count)"
        assert_equals "4" "$count" "get_installed_versions_count should count 4 versions (ignoring hidden directory)"
        
        # Test version_is_installed with special characters
        assert_command_succeeds "version_is_installed should succeed with beta version" -- version_is_installed "1.0.0-beta.1"
        assert_command_succeeds "version_is_installed should succeed with rc version" -- version_is_installed "1.0.0-rc.2"
        assert_command_succeeds "version_is_installed should succeed with alpha version" -- version_is_installed "2.0.0-alpha"
        
        # Note: version_is_installed checks directory existence regardless of hidden status
        # This is different from get_installed_versions which filters out hidden directories
        assert_command_succeeds "version_is_installed should succeed for hidden directory that exists" -- version_is_installed ".hidden"
        
        # Test current version functions work normally
        local current
        current="$(get_current_version)"
        assert_equals "1.0.0" "$current" "get_current_version should work with special character versions present"
        
        assert_command_succeeds "is_current_version should succeed with special character versions present" -- is_current_version "1.0.0"
        
        # Test annotate_versions with special characters and hidden directories
        local annotated_output
        annotated_output="$(echo -e "1.0.0\n1.0.0-beta.1\n1.0.0-rc.2\n2.0.0-alpha\n.hidden\n3.0.0" | annotate_versions)"
        assert_contains "1.0.0	installed,current" "$annotated_output" "annotate_versions should show installed,current status for current version"
        assert_contains "1.0.0-beta.1	installed" "$annotated_output" "annotate_versions should show installed status for beta version"
        assert_contains "1.0.0-rc.2	installed" "$annotated_output" "annotate_versions should show installed status for rc version"
        assert_contains "2.0.0-alpha	installed" "$annotated_output" "annotate_versions should show installed status for alpha version"
        assert_contains ".hidden	installed" "$annotated_output" "annotate_versions should show installed status for hidden directory (version_is_installed returns true)"
        assert_contains "3.0.0	" "$annotated_output" "annotate_versions should show empty status for non-installed version"
    )
}

# =============================================================================
# Edge Case: Version Sorting
# =============================================================================

test_version_sorting() {
    (
        create_sandbox

        # Create versions in non-sorted order to test sorting
        create_version_directory "1.10.0"
        create_version_directory "1.2.0"
        create_version_directory "1.9.0"
        create_version_directory "2.0.0"
        create_version_directory "1.1.0"
        create_version_directory "10.0.0"
        create_version_directory "2.1.0"
        create_version_directory "2.0.1"
        create_current_symlink "1.1.0"
        
        # Test get_installed_versions (order may vary, but all should be present)
        local versions
        versions="$(get_installed_versions)"
        local version_count
        version_count="$(echo "$versions" | wc -l | tr -d ' ')"
        assert_equals "8" "$version_count" "get_installed_versions should return all 8 versions"
        
        # Test get_installed_versions_count
        local count
        count="$(get_installed_versions_count)"
        assert_equals "8" "$count" "get_installed_versions_count should return 8 for all versions"
        
        # Test get_latest_installed_version (should use semantic version sorting)
        local latest
        latest="$(get_latest_installed_version)"
        assert_equals "10.0.0" "$latest" "get_latest_installed_version should return highest semantic version"
        
        # Test version_is_installed for various versions
        assert_command_succeeds "version_is_installed should succeed for highest version" -- version_is_installed "10.0.0"
        assert_command_succeeds "version_is_installed should succeed for current version" -- version_is_installed "1.1.0"
        assert_command_succeeds "version_is_installed should succeed for patch version" -- version_is_installed "2.0.1"
        
        # Test current version functions
        local current
        current="$(get_current_version)"
        assert_equals "1.1.0" "$current" "get_current_version should return correct version despite many options"
        
        assert_command_succeeds "is_current_version should succeed for current version" -- is_current_version "1.1.0"
        assert_command_fails "is_current_version should fail for latest but non-current version" -- is_current_version "10.0.0"
        
        # Test annotate_versions with version sorting
        local annotated_output
        annotated_output="$(echo -e "1.10.0\n1.2.0\n1.9.0\n2.0.0\n1.1.0\n10.0.0\n2.1.0\n2.0.1\n0.9.0" | annotate_versions)"
        assert_contains "1.10.0	installed" "$annotated_output" "annotate_versions should show installed status for version 1.10.0"
        assert_contains "1.2.0	installed" "$annotated_output" "annotate_versions should show installed status for version 1.2.0"
        assert_contains "1.9.0	installed" "$annotated_output" "annotate_versions should show installed status for version 1.9.0"
        assert_contains "2.0.0	installed" "$annotated_output" "annotate_versions should show installed status for version 2.0.0"
        assert_contains "1.1.0	installed,current" "$annotated_output" "annotate_versions should show installed,current status for current version 1.1.0"
        assert_contains "10.0.0	installed" "$annotated_output" "annotate_versions should show installed status for highest version 10.0.0"
        assert_contains "2.1.0	installed" "$annotated_output" "annotate_versions should show installed status for version 2.1.0"
        assert_contains "2.0.1	installed" "$annotated_output" "annotate_versions should show installed status for patch version 2.0.1"
        assert_contains "0.9.0	" "$annotated_output" "annotate_versions should show empty status for non-installed version 0.9.0"
    )
}

# Register all test functions
register_tests \
    "test_no_versions_installed" \
    "test_single_version_installed" \
    "test_multiple_versions_installed" \
    "test_broken_symlink_edge_case" \
    "test_absolute_symlink_edge_case" \
    "test_file_instead_of_symlink_edge_case" \
    "test_hidden_directories_and_special_characters" \
    "test_version_sorting"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "Setup Claude Code Base Functions Tests" "$@"
fi
