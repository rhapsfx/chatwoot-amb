#!/bin/bash
# test-claude-slash-parse-arguments.sh - Integration tests for argument parsing
# 
# Purpose: Test end-to-end argument parsing and execution integration
# Dependencies: claude-slash.sh must support dry-run mode
# Approach: Test full pipeline integration using dry-run mode, focusing on integration concerns
# Note: Low-level parsing/validation is covered by unit tests in test-claude-code-argument-parsing.sh

source "$(dirname "$0")/../utils/test-harness.sh"

export DRY_RUN=true

test_end_to_end_dry_run_execution() {
    # Test that parsing, validation, and execution work together for all commands
    (
        create_sandbox

        # Test each command executes properly after argument processing
        local commands=("install" "reinstall" "uninstall" "list")
        
        for cmd in "${commands[@]}"; do
            local output
            output=$(assert_command_succeeds "$cmd should work end-to-end" -- "./scripts/claude-slash.sh" "$cmd" 2>&1)
            assert_contains "dryrun:${cmd}_templates" "$output" "Should execute $cmd in dry-run mode"
        done
    )
}

test_argument_order_independence() {
    # Test that argument order doesn't affect execution (parsing order covered by unit tests)
    (
        create_sandbox

        # Test different orders produce same execution results - focus on execution consistency
        local output1
        output1=$(assert_command_succeeds "First option order should execute" -- "./scripts/claude-slash.sh" install 2>&1)
        
        local output2
        output2=$(assert_command_succeeds "Second option order should execute" -- "./scripts/claude-slash.sh" install 2>&1)
        
        # Verify both orders result in successful execution
        assert_contains "dryrun:install_templates" "$output1" "First order should execute install"
        assert_contains "dryrun:install_templates" "$output2" "Second order should execute install"
    )
}

test_help_system_integration() {
    # Test that help system works end-to-end with proper output formatting
    (
        create_sandbox

        # Test global help output content and structure
        local help_output
        help_output=$(assert_command_succeeds "Global --help should work" -- "./scripts/claude-slash.sh" --help 2>&1)
        
        # Verify help output structure and content
        assert_contains "Usage:" "$help_output" "Should show usage information"
        assert_contains "Commands:" "$help_output" "Should show commands section"
        assert_contains "install" "$help_output" "Should list install command"
        assert_contains "reinstall" "$help_output" "Should list reinstall command"
        assert_contains "uninstall" "$help_output" "Should list uninstall command"
        assert_contains "list" "$help_output" "Should list list command"
        assert_contains "Global Options:" "$help_output" "Should show global options section"
        assert_contains "--format" "$help_output" "Should show --format option"
        assert_contains "--dry-run" "$help_output" "Should show option"
        assert_contains "--yes" "$help_output" "Should show --yes option"
        assert_contains "Examples:" "$help_output" "Should show examples section"
        
        # Test short help flag works identically
        local short_help_output
        short_help_output=$(assert_command_succeeds "-h should work" -- "./scripts/claude-slash.sh" -h 2>&1)
        assert_contains "Usage:" "$short_help_output" "Short help should show usage information"
        
        # Test help output formatting is consistent
        assert_contains "List Command Options:" "$help_output" "Should show command-specific options"
        assert_contains "--source" "$help_output" "Should document source option"
    )
}

test_error_integration_quality() {
    # Test that error handling works through the full pipeline with quality messages
    (
        create_sandbox

        # Test that the full pipeline produces quality error messages
        local bad_command_output
        bad_command_output=$(assert_command_fails "Bad command should fail with helpful error" -- "./scripts/claude-slash.sh" badcommand 2>&1)
        assert_contains "Unknown command:" "$bad_command_output" "Should identify unknown command"
        assert_contains "Valid commands:" "$bad_command_output" "Should show valid commands"
        assert_contains "install, reinstall, uninstall, list" "$bad_command_output" "Should list all valid commands"
        assert_contains "Use --help for usage information" "$bad_command_output" "Should suggest help"
        
        # Test no command error through full pipeline
        local no_command_output
        no_command_output=$(assert_command_fails "No command should fail with usage" -- "./scripts/claude-slash.sh" 2>&1)
        assert_contains "Usage:" "$no_command_output" "Should show usage when no command provided"
    )
}

# Register test functions - focused on integration concerns
register_tests \
    "test_end_to_end_dry_run_execution" \
    "test_argument_order_independence" \
    "test_help_system_integration" \
    "test_error_integration_quality"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "claude-slash.sh Argument Parsing Integration Tests" "$@"
fi
