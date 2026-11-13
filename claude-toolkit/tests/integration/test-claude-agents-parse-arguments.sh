#!/bin/bash
# test-claude-agents-parse-arguments.sh - Tests claude-agents.sh argument parsing integration
# 
# Purpose: Test scripts/claude-agents.sh argument parsing integration behavior
# Dependencies: None

source "$(dirname "$0")/../utils/test-harness.sh"

export DEBUG=true

test_parse_arguments_integration() {
    (
        create_sandbox

        # Test help command integration
        local help_output
        help_output=$(assert_command_succeeds "Help should work" -- ./scripts/claude-agents.sh --help)
        
        assert_contains "Claude Code Subagents Installation Script" "$help_output" "Should show subagents help"
        assert_contains "install" "$help_output" "Should show install command"
        assert_contains "subagents" "$help_output" "Should mention subagents"

        # Test invalid command
        local invalid_output
        invalid_output=$(assert_command_fails "Invalid command should fail" -- ./scripts/claude-agents.sh invalid-command 2>&1)
        
        assert_contains "Unknown command: invalid-command" "$invalid_output" "Should report unknown command"

        # Test missing command
        local missing_output
        missing_output=$(assert_command_fails "Missing command should fail" -- ./scripts/claude-agents.sh 2>&1)
        
        assert_contains "No command specified" "$missing_output" "Should report missing command"
    )
}

test_source_option_integration() {
    (
        create_sandbox

        # Test valid source options
        local sources=("all" "user" "claude-toolkit" "team-alpha")
        
        for source in "${sources[@]}"; do
            local output
            output=$(assert_command_succeeds "Source $source should be valid" -- ./scripts/claude-agents.sh list --source "$source" --dry-run 2>&1)
            assert_contains "dryrun:" "$output" "Should execute with source $source"
        done

        # Test multiple sources
        local multi_output
        multi_output=$(assert_command_succeeds "Multiple sources should work" -- ./scripts/claude-agents.sh list --source claude-toolkit,team-alpha --dry-run 2>&1)
        assert_contains "dryrun:" "$multi_output" "Should execute with multiple sources"
    )
}

test_format_option_integration() {
    (
        create_sandbox

        # Test valid format options for list command
        local formats=("compact" "detailed")
        
        for format in "${formats[@]}"; do
            local output
            output=$(assert_command_succeeds "Format $format should be valid for list" -- ./scripts/claude-agents.sh list --format "$format" --dry-run 2>&1)
            assert_contains "dryrun:" "$output" "Should execute with format $format"
        done

        # Test format with non-list command should fail
        local invalid_format_output
        invalid_format_output=$(assert_command_fails "Format should not work with install" -- ./scripts/claude-agents.sh install --format detailed 2>&1)
        assert_contains "--format option only valid for 'list' command" "$invalid_format_output" "Should reject format for non-list commands"
    )
}

test_global_options_integration() {
    (
        create_sandbox

        # Test dry-run option
        local dry_run_output
        dry_run_output=$(assert_command_succeeds "Dry run option should work" -- ./scripts/claude-agents.sh install --dry-run 2>&1)
        assert_contains "dryrun:" "$dry_run_output" "Should enable dry run mode"

        # Test debug option
        local debug_output
        debug_output=$(assert_command_succeeds "Debug option should work" -- ./scripts/claude-agents.sh list --debug --dry-run 2>&1)
        assert_contains "dryrun:" "$debug_output" "Should enable debug mode"

        # Test yes option
        local yes_output
        yes_output=$(assert_command_succeeds "Yes option should work" -- ./scripts/claude-agents.sh install --yes --dry-run 2>&1)
        assert_contains "dryrun:" "$yes_output" "Should enable auto-accept mode"
    )
}

register_tests \
    "test_parse_arguments_integration" \
    "test_source_option_integration" \
    "test_format_option_integration" \
    "test_global_options_integration"

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "claude-agents.sh argument parsing integration" "$@"
fi