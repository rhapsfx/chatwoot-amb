#!/bin/bash
# test-claude-code-parse-arguments.sh - Test argument parsing in claude-code.sh
# 
# Purpose: Test claude-code.sh command-first argument parsing functionality in dry-run mode
# Dependencies: claude-code.sh must support command-first syntax with mode
# Approach: Test end-to-end command execution and dry-run integration (minimal coverage, detailed testing in unit tests)

source "$(dirname "$0")/../utils/test-harness.sh"

export DRY_RUN=true

test_end_to_end_command_execution() {
    (
        create_sandbox

        # Test that basic commands execute successfully in dry-run mode
        assert_command_succeeds "install command should work in dry-run" -- "./scripts/claude-code.sh" install >/dev/null 2>&1
        assert_command_succeeds "uninstall command should work in dry-run" -- "./scripts/claude-code.sh" uninstall >/dev/null 2>&1
        assert_command_succeeds "list command should work in dry-run" -- "./scripts/claude-code.sh" list >/dev/null 2>&1
        
        # Test that dry-run mode produces expected output for verification
        local output
        output=$(assert_command_succeeds "install should show dry-run output" -- "./scripts/claude-code.sh" install --version 1.0.0 2>&1)
        assert_contains "dryrun:install_claude_code(1.0.0)" "$output" "Should show dry-run execution with version"
    )
}

test_error_propagation_through_pipeline() {
    (
        create_sandbox

        # Test that parsing errors properly propagate through the complete pipeline
        local error_output
        error_output=$(assert_command_fails "Missing command should fail" -- "./scripts/claude-code.sh" 2>&1)
        assert_contains "[ERROR] No command specified" "$error_output" "Should propagate validation error to user"
        
        # Test that validation errors propagate with proper exit codes
        error_output=$(assert_command_fails "Invalid option should fail" -- "./scripts/claude-code.sh" install --invalid-option 2>&1)
        assert_contains "[ERROR] Unknown option --invalid-option" "$error_output" "Should propagate validation error with formatted message"
    )
}

test_dry_run_environment_integration() {
    (
        create_sandbox

        # Test that DRY_RUN environment variable is properly respected
        local output
        output=$(assert_command_succeeds "DRY_RUN should be respected" -- "./scripts/claude-code.sh" reinstall 2>&1)
        assert_contains "dryrun:" "$output" "Should show dry-run prefix indicating environment integration works"
        
        # Test that complex option combinations work end-to-end
        output=$(assert_command_succeeds "Complex options should work" -- "./scripts/claude-code.sh" install --version 1.2.3 --shell bash --nodejs-version 22.18.0 2>&1)
        assert_contains "dryrun:install_claude_code(1.2.3)" "$output" "Should handle complex argument combinations"
    )
}

# Register all test functions
register_tests \
    "test_end_to_end_command_execution" \
    "test_error_propagation_through_pipeline" \
    "test_dry_run_environment_integration"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "claude-code.sh Argument Parsing Integration Tests" "$@"
fi
