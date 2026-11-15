#!/bin/bash
# test-claude-template-sources-argument-parsing.sh - Tests argument parsing and validation functions
# 
# Purpose: Test the parse_arguments and validate_arguments functions for claude-template-sources.sh
# Dependencies: None (sources claude-template-sources.sh directly)
# Approach: Test parsing output format and validation rules in memory

source "$(dirname "$0")/../utils/test-harness.sh"

# Source the setup script to get access to functions under test
source "$(dirname "$0")/../../scripts/claude-template-sources.sh"

# =============================================================================
# Helper functions for testing validation with proper command wrappers
# =============================================================================

# Wrapper to test validate_arguments with input
validate_arguments_with_input() {
    local input="$1"
    echo "$input" | validate_arguments
}

# Export the wrapper so it's available in subshells
export -f validate_arguments_with_input

export DEBUG=true

# =============================================================================
# Tests for parse_arguments function
# =============================================================================

test_parse_arguments_help_flag() {
    # Test --help flag parsing
    local output
    output=$(assert_command_succeeds "Help flag should parse successfully" -- parse_arguments --help)
    
    assert_contains "help" "$output" "Should output help key-value pair"
    assert_contains "help	true" "$output" "Should set help to true"
}

test_parse_arguments_no_command() {
    # Test missing command should now succeed with no_command marker
    local output
    output=$(assert_command_succeeds "Missing command should parse successfully with marker" -- parse_arguments)
    
    assert_contains "no_command	true" "$output" "Should output no_command marker"
}

test_parse_arguments_valid_commands() {
    # Test valid command parsing for all source management commands
    local commands=("add" "remove" "list")
    
    for cmd in "${commands[@]}"; do
        local output
        output=$(assert_command_succeeds "Valid command '$cmd' should parse successfully" -- parse_arguments "$cmd")
        
        assert_contains "command	$cmd" "$output" "Should parse command '$cmd' correctly"
    done
}

test_parse_arguments_add_command_with_args() {
    # Test add command with source name and git URL
    local output
    output=$(assert_command_succeeds "Add command with arguments should parse successfully" -- parse_arguments add team-alpha git@github.com:org/repo.git)
    
    assert_contains "command	add" "$output" "Should parse add command"
    assert_contains "source_name	team-alpha" "$output" "Should parse source name"
    assert_contains "git_url	git@github.com:org/repo.git" "$output" "Should parse git URL"
}

test_parse_arguments_remove_command_with_args() {
    # Test remove command with source name
    local output
    output=$(assert_command_succeeds "Remove command with argument should parse successfully" -- parse_arguments remove team-alpha)
    
    assert_contains "command	remove" "$output" "Should parse remove command"
    assert_contains "source_name	team-alpha" "$output" "Should parse source name"
}

test_parse_arguments_with_global_options() {
    # Test command with various global options
    local output
    output=$(assert_command_succeeds "Command with options should parse successfully" -- parse_arguments list --dry-run --yes --debug)
    
    assert_contains "command	list" "$output" "Should parse command"
    assert_contains "dry_run	true" "$output" "Should parse dry-run flag"
    assert_contains "debug	true" "$output" "Should parse debug flag"
}

test_parse_arguments_invalid_option() {
    # Test invalid option should now succeed with unknown_option marker
    local output
    output=$(assert_command_succeeds "Invalid option should parse successfully with marker" -- parse_arguments list --invalid-option)
    
    assert_contains "command	list" "$output" "Should parse command correctly"
    assert_contains "unknown_option	--invalid-option" "$output" "Should output unknown_option marker"
}

test_parse_arguments_help_after_command() {
    # Test help flag after command should now succeed with marker
    local output
    output=$(assert_command_succeeds "Help after command should parse successfully with marker" -- parse_arguments add --help)
    
    assert_contains "command	add" "$output" "Should parse command correctly"
    assert_contains "help_after_command	true" "$output" "Should output help_after_command marker"
}

# =============================================================================
# Tests for validate_arguments function
# =============================================================================

test_validate_arguments_valid_commands() {
    # Test valid commands pass validation (with required arguments for add/remove)
    local input_add=$'command	add\nsource_name	team-alpha\ngit_url	git@github.com:org/repo.git'
    assert_command_succeeds "Command 'add' with arguments should be valid" -- validate_arguments_with_input "$input_add"
    
    local input_remove=$'command	remove\nsource_name	team-alpha'
    assert_command_succeeds "Command 'remove' with argument should be valid" -- validate_arguments_with_input "$input_remove"
    
    local input_list="command	list"
    assert_command_succeeds "Command 'list' should be valid" -- validate_arguments_with_input "$input_list"
}

test_validate_arguments_invalid_command() {
    # Test invalid command should fail with exit code 1 and specific error message
    local input="command	invalid_command"
    local output
    output=$(assert_command_fails 1 "Invalid command should fail validation with exit code 1" -- validate_arguments_with_input "$input" 2>&1)
    
    assert_contains "Unknown command: invalid_command" "$output" "Should output unknown command error"
    assert_contains "Valid commands: add, remove, list" "$output" "Should list valid commands"
}

test_validate_arguments_no_command_error() {
    # Test missing command should fail with proper error message
    local input="no_command	true"
    local output
    output=$(assert_command_fails 1 "Missing command should fail validation with exit code 1" -- validate_arguments_with_input "$input" 2>&1)
    
    assert_contains "No command specified" "$output" "Should output no command error"
    assert_contains "Commands: add, remove, list" "$output" "Should list valid commands"
}

test_validate_arguments_add_command_args() {
    # Test add command requires both name and git URL
    local input_missing_url=$'command	add\nsource_name	team-alpha'
    local output_missing_url
    output_missing_url=$(assert_command_fails 1 "Add command with missing URL should fail" -- validate_arguments_with_input "$input_missing_url" 2>&1)
    
    assert_contains "add requires <name> and <git-url> arguments" "$output_missing_url" "Should output missing arguments error for add"
    
    # Test add command with both arguments passes
    local input_complete=$'command	add\nsource_name	team-alpha\ngit_url	git@github.com:org/repo.git'
    assert_command_succeeds "Add command with both arguments should pass" -- validate_arguments_with_input "$input_complete"
}

test_validate_arguments_remove_command_args() {
    # Test remove command requires source name
    local input_missing_name="command	remove"
    local output_missing_name
    output_missing_name=$(assert_command_fails 1 "Remove command with missing name should fail" -- validate_arguments_with_input "$input_missing_name" 2>&1)
    
    assert_contains "remove requires <name> argument" "$output_missing_name" "Should output missing argument error for remove"
    
    # Test remove command with name passes
    local input_complete=$'command	remove\nsource_name	team-alpha'
    assert_command_succeeds "Remove command with name should pass" -- validate_arguments_with_input "$input_complete"
}

test_validate_arguments_list_command() {
    # Test list command doesn't require any arguments
    local input="command	list"
    assert_command_succeeds "List command without arguments should pass" -- validate_arguments_with_input "$input"
}

test_validate_arguments_help_bypass() {
    # Test that help request bypasses other validation
    local input=$'help	true'
    assert_command_succeeds "Help request should bypass validation" -- validate_arguments_with_input "$input"
    
    # Test help with invalid command still passes
    local input_with_invalid=$'help	true\ncommand	invalid'
    assert_command_succeeds "Help request should bypass validation even with invalid command" -- validate_arguments_with_input "$input_with_invalid"
}

test_validate_arguments_help_after_command_error() {
    # Test help after command is caught as error
    local input="help_after_command	true"
    local output
    output=$(assert_command_fails 1 "Help after command should fail validation" -- validate_arguments_with_input "$input" 2>&1)
    
    assert_contains "Use --help before command for usage information" "$output" "Should output help placement error"
}

test_validate_arguments_unknown_option_error() {
    # Test unknown options are caught as errors
    local input="unknown_option	--invalid-flag"
    local output
    output=$(assert_command_fails 1 "Unknown option should fail validation" -- validate_arguments_with_input "$input" 2>&1)
    
    assert_contains "Unknown option --invalid-flag" "$output" "Should output unknown option error"
}

# =============================================================================
# Comprehensive parsing tests
# =============================================================================

test_parse_arguments_all_command_types() {
    # Test comprehensive parsing for all command types with various options
    local all_commands=("add" "remove" "list")
    
    for cmd in "${all_commands[@]}"; do
        # Test basic command parsing
        local basic_output
        basic_output=$(assert_command_succeeds "Command '$cmd' should parse successfully" -- parse_arguments "$cmd")
        assert_contains "command	$cmd" "$basic_output" "Should parse command '$cmd' correctly"
        
        # Test command with global options
        local global_output
        global_output=$(assert_command_succeeds "Command '$cmd' with global options should parse" -- parse_arguments "$cmd" --dry-run --yes)
        assert_contains "command	$cmd" "$global_output" "Should parse command '$cmd' with global options"
        assert_contains "dry_run	true" "$global_output" "Should parse --dry-run for '$cmd'"
    done
}

test_parse_arguments_comprehensive_combinations() {
    # Test all possible command and option combinations
    
    # Add with all options
    local add_output
    add_output=$(assert_command_succeeds "Add with all options should parse" -- parse_arguments add team-alpha git@github.com:org/repo.git --dry-run --yes --debug --porcelain)
    assert_contains "command	add" "$add_output" "Should parse add command"
    assert_contains "source_name	team-alpha" "$add_output" "Should parse source name"
    assert_contains "git_url	git@github.com:org/repo.git" "$add_output" "Should parse git URL"
    assert_contains "dry_run	true" "$add_output" "Should parse dry-run flag"
    assert_contains "debug	true" "$add_output" "Should parse debug flag"
    assert_contains "porcelain	true" "$add_output" "Should parse porcelain flag"
    
    # Remove with options
    local remove_output
    remove_output=$(assert_command_succeeds "Remove with options should parse" -- parse_arguments remove team-alpha --dry-run --porcelain)
    assert_contains "command	remove" "$remove_output" "Should parse remove command"
    assert_contains "source_name	team-alpha" "$remove_output" "Should parse source name for remove"
    assert_contains "dry_run	true" "$remove_output" "Should parse dry-run flag for remove"
    assert_contains "porcelain	true" "$remove_output" "Should parse porcelain flag for remove"
    
    # List with options
    local list_output
    list_output=$(assert_command_succeeds "List with options should parse" -- parse_arguments list --porcelain --debug)
    assert_contains "command	list" "$list_output" "Should parse list command"
    assert_contains "porcelain	true" "$list_output" "Should parse porcelain flag for list"
    assert_contains "debug	true" "$list_output" "Should parse debug flag for list"
}

# Register all test functions
register_tests \
    "test_parse_arguments_help_flag" \
    "test_parse_arguments_no_command" \
    "test_parse_arguments_valid_commands" \
    "test_parse_arguments_add_command_with_args" \
    "test_parse_arguments_remove_command_with_args" \
    "test_parse_arguments_with_global_options" \
    "test_parse_arguments_invalid_option" \
    "test_parse_arguments_help_after_command" \
    "test_parse_arguments_all_command_types" \
    "test_parse_arguments_comprehensive_combinations" \
    "test_validate_arguments_valid_commands" \
    "test_validate_arguments_invalid_command" \
    "test_validate_arguments_no_command_error" \
    "test_validate_arguments_add_command_args" \
    "test_validate_arguments_remove_command_args" \
    "test_validate_arguments_list_command" \
    "test_validate_arguments_help_bypass" \
    "test_validate_arguments_help_after_command_error" \
    "test_validate_arguments_unknown_option_error"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "claude-template-sources.sh Argument Parsing Unit Tests" "$@"
fi
