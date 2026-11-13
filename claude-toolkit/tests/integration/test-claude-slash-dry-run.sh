#!/bin/bash
# test-claude-slash-dry-run.sh - Tests scripts/claude-slash.sh --dry-run functionality
# 
# Purpose: Test scripts/claude-slash.sh dry-run mode to ensure functions print their names without executing
# Dependencies: None
# Approach: Use sandboxed environments to test dry-run mode without any system modifications
# Safety: Each test runs in complete isolation to prevent any accidental system changes

source "$(dirname "$0")/../utils/test-harness.sh"
source "$(dirname "$0")/../utils/file-utils.sh"

test_dry_run_install() {
    (
        create_sandbox

        local initial_checksum
        initial_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        
        local output
        output=$(assert_command_succeeds "Dry-run install should succeed" -- "./scripts/claude-slash.sh" install --dry-run 2>&1)

        assert_contains "dryrun:install_templates" "$output" "Should print dryrun:install_templates function name"
        
        local final_checksum
        final_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        assert_equals "$initial_checksum" "$final_checksum" "Dry-run install should make no filesystem changes"
    )
}

test_dry_run_reinstall() {
    (
        create_sandbox

        local initial_checksum
        initial_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        
        local output
        output=$(assert_command_succeeds "Dry-run reinstall should succeed" -- "./scripts/claude-slash.sh" reinstall --dry-run 2>&1)
        
        assert_contains "dryrun:reinstall_templates" "$output" "Should print dryrun:reinstall_templates function name"

        local final_checksum
        final_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        assert_equals "$initial_checksum" "$final_checksum" "Dry-run reinstall should make no filesystem changes"
    )
}

test_dry_run_uninstall() {
    (
        create_sandbox

        local initial_checksum
        initial_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        
        local output
        output=$(assert_command_succeeds "Dry-run uninstall should succeed" -- "./scripts/claude-slash.sh" uninstall --dry-run 2>&1)
        
        assert_contains "dryrun:uninstall_templates" "$output" "Should print dryrun:uninstall_templates function name"

        local final_checksum
        final_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        assert_equals "$initial_checksum" "$final_checksum" "Dry-run uninstall should make no filesystem changes"
    )
}

test_dry_run_list() {
    (
        create_sandbox

        local initial_checksum
        initial_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        
        local output
        output=$(assert_command_succeeds "Dry-run list should succeed" -- "./scripts/claude-slash.sh" list --dry-run 2>&1)

        assert_contains "dryrun:list_templates" "$output" "Should print dryrun:list_templates function name"

        local final_checksum
        final_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        assert_equals "$initial_checksum" "$final_checksum" "Dry-run list should make no filesystem changes"
    )
}

test_dry_run_list_with_source() {
    (
        create_sandbox

        local initial_checksum
        initial_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        
        local output
        output=$(assert_command_succeeds "Dry-run list with source should succeed" -- "./scripts/claude-slash.sh" list --dry-run --source claude-toolkit 2>&1)
        
        assert_contains "dryrun:list_templates" "$output" "Should print dryrun:list_templates function name"
        
        local final_checksum
        final_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        assert_equals "$initial_checksum" "$final_checksum" "Dry-run list with source should make no filesystem changes"
    )
}

test_dry_run_with_yes_flag() {
    (
        create_sandbox

        local initial_checksum
        initial_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        
        local output
        output=$(assert_command_succeeds "Dry-run with yes flag should succeed" -- "./scripts/claude-slash.sh" uninstall --dry-run --yes 2>&1)
        
        assert_contains "dryrun:uninstall_templates" "$output" "Should print function name with yes flag"
        
        local final_checksum
        final_checksum=$(calculate_directory_checksum "$sandbox_dir" "*")
        assert_equals "$initial_checksum" "$final_checksum" "Dry-run with yes flag should make no filesystem changes"
    )
}

# Register all test functions
register_tests \
    "test_dry_run_install" \
    "test_dry_run_reinstall" \
    "test_dry_run_uninstall" \
    "test_dry_run_list" \
    "test_dry_run_list_with_source" \
    "test_dry_run_with_yes_flag"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "Slash Commands Dry-Run Mode Tests" "$@"
fi
