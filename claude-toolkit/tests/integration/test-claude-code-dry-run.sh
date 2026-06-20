#!/bin/bash
# test-claude-code-dry-run.sh - Tests scripts/claude-code.sh --dry-run functionality
# 
# Purpose: Test scripts/claude-code.sh dry-run mode to ensure functions print their names without executing
# Dependencies: None
# Approach: Use sandboxed environments to test dry-run mode without any system modifications
# Safety: Each test runs in complete isolation to prevent any accidental system changes

source "$(dirname "$0")/../utils/test-harness.sh"

test_dry_run_install() {
    (
        create_sandbox

        local output
        output=$(assert_command_succeeds "Dry-run install should exit successfully" -- "./scripts/claude-code.sh" install --dry-run 2>&1)
        
        assert_contains "dryrun:install_claude_code()" "$output" "Should print dryrun:install_claude_code function name"
        assert_directory_not_exists "$XDG_DATA_HOME/claude" "Should not create Claude data directory in dry-run"
        assert_file_not_exists "$sandbox_dir/.local/bin/claude" "Should not create Claude wrapper script in dry-run"
    )
}

test_dry_run_install_with_version() {
    (
        create_sandbox

        local output
        output=$(assert_command_succeeds "Dry-run with version should exit successfully" -- "./scripts/claude-code.sh" install --version 1.0.0 --dry-run 2>&1)
        
        assert_contains "dryrun:install_claude_code(1.0.0)" "$output" "Should print dryrun:install_claude_code function name with version parameter"
        assert_directory_not_exists "$XDG_DATA_HOME/claude" "Should not create Claude data directory in dry-run"
    )
}

test_dry_run_install_with_nodejs_version() {
    (
        create_sandbox

        local output
        output=$(assert_command_succeeds "Dry-run with nodejs-version should exit successfully" -- "./scripts/claude-code.sh" install --nodejs-version 20.0.0 --dry-run 2>&1)
        
        assert_contains "dryrun:install_claude_code()" "$output" "Should print dryrun:install_claude_code function name"
        assert_directory_not_exists "$XDG_DATA_HOME/claude" "Should not create Claude data directory in dry-run"
    )
}

test_dry_run_reinstall() {
    (
        create_sandbox

        local output
        output=$(assert_command_succeeds "Dry-run reinstall should exit successfully" -- "./scripts/claude-code.sh" reinstall --dry-run 2>&1)
        
        assert_contains "dryrun:reinstall_claude_code" "$output" "Should print dryrun:reinstall_claude_code function name"
        assert_directory_not_exists "$XDG_DATA_HOME/claude" "Should not create Claude data directory in dry-run"
    )
}

test_dry_run_reinstall_with_version() {
    (
        create_sandbox

        local output
        output=$(assert_command_succeeds "Dry-run reinstall with version should exit successfully" -- "./scripts/claude-code.sh" reinstall --version 1.0.0 --dry-run 2>&1)
        
        assert_contains "dryrun:reinstall_claude_code" "$output" "Should print dryrun:reinstall_claude_code function name"
        assert_directory_not_exists "$XDG_DATA_HOME/claude" "Should not create Claude data directory in dry-run"
    )
}

test_dry_run_uninstall() {
    (
        create_sandbox

        local output
        output=$(assert_command_succeeds "Dry-run uninstall should exit successfully" -- "./scripts/claude-code.sh" uninstall --dry-run 2>&1)
        
        assert_contains "dryrun:uninstall_claude_code" "$output" "Should print dryrun:uninstall_claude_code function name"
        assert_directory_not_exists "$XDG_DATA_HOME/claude" "Should not have Claude data directory"
    )
}

test_dry_run_uninstall_with_version() {
    (
        create_sandbox

        local output
        output=$(assert_command_succeeds "Dry-run uninstall with version should exit successfully" -- "./scripts/claude-code.sh" uninstall --version 1.0.0 --dry-run 2>&1)
        
        assert_contains "dryrun:uninstall_claude_code" "$output" "Should print dryrun:uninstall_claude_code function name"
        assert_directory_not_exists "$XDG_DATA_HOME/claude" "Should not have Claude data directory"
    )
}

test_dry_run_uninstall_all() {
    (
        create_sandbox

        local output
        output=$(assert_command_succeeds "Dry-run uninstall --all should exit successfully" -- "./scripts/claude-code.sh" uninstall --all --dry-run 2>&1)
        
        assert_contains "dryrun:uninstall_claude_code" "$output" "Should print dryrun:uninstall_claude_code function name"
        assert_directory_not_exists "$XDG_DATA_HOME/claude" "Should not have Claude data directory"
    )
}

test_dry_run_list() {
    (
        create_sandbox

        local output
        output=$(assert_command_succeeds "Dry-run list should exit successfully" -- "./scripts/claude-code.sh" list --dry-run 2>&1)
        
        assert_contains "dryrun:list_claude_versions" "$output" "Should print dryrun:list_claude_versions function name"
        assert_directory_not_exists "$XDG_DATA_HOME/claude" "Should not create Claude data directory in dry-run"
    )
}

test_dry_run_list_available() {
    (
        create_sandbox

        local output
        output=$(assert_command_succeeds "Dry-run list available should exit successfully" -- "./scripts/claude-code.sh" list --mode available --dry-run 2>&1)
        
        assert_contains "dryrun:list_claude_versions" "$output" "Should print dryrun:list_claude_versions function name"
        assert_directory_not_exists "$XDG_DATA_HOME/claude" "Should not create Claude data directory in dry-run"
    )
}

test_dry_run_list_installed() {
    (
        create_sandbox

        local output
        output=$(assert_command_succeeds "Dry-run list installed should exit successfully" -- "./scripts/claude-code.sh" list --mode installed --dry-run 2>&1)
        
        assert_contains "dryrun:list_claude_versions" "$output" "Should print dryrun:list_claude_versions function name"
        assert_directory_not_exists "$XDG_DATA_HOME/claude" "Should not create Claude data directory in dry-run"
    )
}

test_dry_run_use_claude_version() {
    (
        create_sandbox

        local output
        output=$(assert_command_succeeds "Dry-run use should exit successfully" -- "./scripts/claude-code.sh" use --version 1.0.0 --dry-run 2>&1)
        
        assert_contains "dryrun:use_claude_version" "$output" "Should print dryrun:use_claude_version function name"
        assert_directory_not_exists "$XDG_DATA_HOME/claude" "Should not create Claude data directory in dry-run"
    )
}

test_dry_run_with_shell_parameter() {
    (
        create_sandbox

        local output
        output=$(assert_command_succeeds "Dry-run with shell should exit successfully" -- "./scripts/claude-code.sh" install --shell bash --dry-run 2>&1)
        
        assert_contains "dryrun:install_claude_code()" "$output" "Should print dryrun:install_claude_code function name"
        assert_directory_not_exists "$XDG_DATA_HOME/claude" "Should not create Claude data directory in dry-run"
    )
}

test_dry_run_no_side_effects() {
    (
        create_sandbox

        local initial_dirs_count initial_files_count
        initial_dirs_count=$(find "$sandbox_dir" -type d 2>/dev/null | wc -l)
        initial_files_count=$(find "$sandbox_dir" -type f 2>/dev/null | wc -l)
        
        assert_command_succeeds "Dry-run should exit successfully" -- "./scripts/claude-code.sh" install --dry-run >/dev/null 2>&1
        
        local final_dirs_count final_files_count
        final_dirs_count=$(find "$sandbox_dir" -type d 2>/dev/null | wc -l)
        final_files_count=$(find "$sandbox_dir" -type f 2>/dev/null | wc -l)
        
        assert_equals "$initial_dirs_count" "$final_dirs_count" "Directory count should not change in dry-run"
        assert_equals "$initial_files_count" "$final_files_count" "File count should not change in dry-run"
        assert_directory_not_exists "$XDG_DATA_HOME/claude" "Should not create Claude data directory"
        assert_file_not_exists "$sandbox_dir/.local/bin/claude" "Should not create Claude wrapper script"
        assert_directory_not_exists "$XDG_CACHE_HOME/claude" "Should not create Claude cache directory"
    )
}

# Register all test functions
register_tests \
    "test_dry_run_install" \
    "test_dry_run_install_with_version" \
    "test_dry_run_install_with_nodejs_version" \
    "test_dry_run_reinstall" \
    "test_dry_run_reinstall_with_version" \
    "test_dry_run_uninstall" \
    "test_dry_run_uninstall_with_version" \
    "test_dry_run_uninstall_all" \
    "test_dry_run_list" \
    "test_dry_run_list_available" \
    "test_dry_run_list_installed" \
    "test_dry_run_use_claude_version" \
    "test_dry_run_with_shell_parameter" \
    "test_dry_run_no_side_effects"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "Claude Code Dry-Run Mode Tests" "$@"
fi
