#!/bin/bash
# test-claude-toolkit-argument-parsing.sh - Tests argument parsing and validation functions
# 
# Purpose: Test the parse_arguments and validate_arguments functions in claude-toolkit.sh
# Dependencies: None (sources claude-toolkit.sh directly)
# Approach: Test parsing output format and validation rules in memory

source "$(dirname "$0")/../utils/test-harness.sh"

# Source the script to get access to functions under test
source "$(dirname "$0")/../../scripts/claude-toolkit.sh"

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
    # Test missing command should succeed with no_command marker
    local output
    output=$(assert_command_succeeds "Missing command should parse successfully with marker" -- parse_arguments)
    
    assert_contains "no_command	true" "$output" "Should output no_command marker"
}

test_parse_arguments_valid_command() {
    # Test valid command parsing
    local output
    output=$(assert_command_succeeds "Valid command should parse successfully" -- parse_arguments install)
    
    assert_contains "command	install" "$output" "Should parse command correctly"
}

test_parse_arguments_with_options() {
    # Test command with various options
    local output
    output=$(assert_command_succeeds "Command with options should parse successfully" -- parse_arguments install --shell bash --debug --dry-run --https)
    
    assert_contains "command	install" "$output" "Should parse command"
    assert_contains "shell	bash" "$output" "Should parse shell option"
    assert_contains "debug	true" "$output" "Should parse debug flag"
    assert_contains "dry_run	true" "$output" "Should parse dry-run flag"
    assert_contains "https	true" "$output" "Should parse https flag"
}

test_parse_arguments_equals_syntax() {
    # Test --option=value syntax
    local output
    output=$(assert_command_succeeds "Equals syntax should parse successfully" -- parse_arguments install --shell=zsh --remote-repository=https://example.com/repo.git)
    
    assert_contains "command	install" "$output" "Should parse command"
    assert_contains "shell	zsh" "$output" "Should parse shell with equals syntax"
    assert_contains "remote_repository	https://example.com/repo.git" "$output" "Should parse remote-repository with equals syntax"
}

test_parse_arguments_yes_flags() {
    # Test various yes flag formats
    local output
    output=$(assert_command_succeeds "Yes flags should parse successfully" -- parse_arguments uninstall --yes)
    assert_contains "yes	true" "$output" "Should parse --yes flag"
    
    output=$(assert_command_succeeds "-y flag should parse successfully" -- parse_arguments uninstall -y)
    assert_contains "yes	true" "$output" "Should parse -y flag"
    
    output=$(assert_command_succeeds "--force flag should parse successfully" -- parse_arguments uninstall --force)
    assert_contains "yes	true" "$output" "Should parse --force flag"
}

test_parse_arguments_remote_repository() {
    # Test remote repository parsing
    local output
    output=$(assert_command_succeeds "Remote repository should parse successfully" -- parse_arguments install --remote-repository git@github.com:user/repo.git)
    
    assert_contains "command	install" "$output" "Should parse command"
    assert_contains "remote_repository	git@github.com:user/repo.git" "$output" "Should parse remote repository URL"
}

test_parse_arguments_invalid_option() {
    # Test invalid option should succeed with unknown_option marker
    local output
    output=$(assert_command_succeeds "Invalid option should parse successfully with marker" -- parse_arguments install --invalid-option)
    
    assert_contains "command	install" "$output" "Should parse command correctly"
    assert_contains "unknown_option	--invalid-option" "$output" "Should output unknown_option marker"
}

test_parse_arguments_missing_values() {
    # Test missing values should succeed with special markers
    local output
    output=$(assert_command_succeeds "Missing values should parse successfully with markers" -- parse_arguments install --shell --remote-repository)
    
    assert_contains "command	install" "$output" "Should parse command correctly"
    assert_contains "shell_no_value	true" "$output" "Should output shell_no_value marker"
    assert_contains "remote_repository_no_value	true" "$output" "Should output remote_repository_no_value marker"
}

test_parse_arguments_help_after_command() {
    # Test help flag after command should succeed with marker
    local output
    output=$(assert_command_succeeds "Help after command should parse successfully with marker" -- parse_arguments install --help)
    
    assert_contains "command	install" "$output" "Should parse command correctly"
    assert_contains "help_after_command	true" "$output" "Should output help_after_command marker"
}

# =============================================================================
# Tests for validate_arguments function
# =============================================================================

test_validate_arguments_valid_commands() {
    # Test all valid commands pass validation
    local commands=("install" "reinstall" "uninstall" "update" "validate" "_reinstall")
    
    for cmd in "${commands[@]}"; do
        local input="command	$cmd"
        assert_command_succeeds "Command '$cmd' should be valid" -- validate_arguments_with_input "$input"
    done
}

test_validate_arguments_invalid_command() {
    # Test invalid command should fail with exit code 1 and specific error message
    local input="command	invalid_command"
    local output
    output=$(assert_command_fails 1 "Invalid command should fail validation with exit code 1" -- validate_arguments_with_input "$input" 2>&1)
    
    assert_contains "Unknown command: invalid_command" "$output" "Should output unknown command error"
    assert_contains "Valid commands: install, uninstall, update" "$output" "Should list valid commands"
}

test_validate_arguments_shell_validation() {
    # Test valid shells
    local valid_shells=("bash" "zsh" "fish")
    
    for shell in "${valid_shells[@]}"; do
        local input=$'command\tinstall\nshell\t'"$shell"
        assert_command_succeeds "Shell '$shell' should be valid" -- validate_arguments_with_input "$input"
    done
    
    # Test invalid shell
    local input_invalid=$'command\tinstall\nshell\tinvalid_shell'
    local output
    output=$(assert_command_fails 1 "Invalid shell should fail validation with exit code 1" -- validate_arguments_with_input "$input_invalid" 2>&1)
    
    assert_contains "Unsupported shell: invalid_shell (supported: bash, zsh, fish)" "$output" "Should output unsupported shell error with valid options"
}

test_validate_arguments_help_bypass() {
    # Test that help request bypasses other validation
    local input=$'help\ttrue'
    assert_command_succeeds "Help request should bypass validation" -- validate_arguments_with_input "$input"
    
    # Test help with invalid command still passes
    local input_with_invalid=$'help\ttrue\ncommand\tinvalid'
    assert_command_succeeds "Help request should bypass validation even with invalid command" -- validate_arguments_with_input "$input_with_invalid"
}

test_validate_arguments_no_command_default() {
    # Test that no_command marker gets converted to install command
    local input=$'no_command\ttrue'
    assert_command_succeeds "No command should default to install and pass validation" -- validate_arguments_with_input "$input"
}

test_validate_arguments_missing_values() {
    # Test that missing value markers fail validation
    local missing_value_tests=(
        "shell_no_value	true:--shell requires a value" 
        "remote_repository_no_value	true:--remote-repository requires a value"
    )
    
    for test_case in "${missing_value_tests[@]}"; do
        local input="${test_case%:*}"
        local expected_error="${test_case#*:}"
        local output
        output=$(assert_command_fails 1 "Missing value marker should fail validation: $input" -- validate_arguments_with_input "$input" 2>&1)
        
        assert_contains "$expected_error" "$output" "Should output correct missing value error for $input"
    done
}

test_validate_arguments_help_after_command() {
    # Test that help_after_command marker fails validation
    local input=$'help_after_command\ttrue'
    local output
    output=$(assert_command_fails 1 "Help after command should fail validation with exit code 1" -- validate_arguments_with_input "$input" 2>&1)
    
    assert_contains "Use --help before command for usage information" "$output" "Should output help placement error message"
}

test_validate_arguments_unknown_option() {
    # Test that unknown_option marker fails validation
    local input=$'unknown_option\t--invalid-flag'
    local output
    output=$(assert_command_fails 1 "Unknown option should fail validation with exit code 1" -- validate_arguments_with_input "$input" 2>&1)
    
    assert_contains "Unknown option --invalid-flag" "$output" "Should output unknown option error with the specific flag"
}

# =============================================================================
# Integration tests combining parsing and validation
# =============================================================================

test_parse_and_validate_integration() {
    # Test successful parsing and validation flow
    local parsed_output
    parsed_output=$(assert_command_succeeds "Valid arguments should parse successfully" -- parse_arguments install --shell bash --https)
    
    # Validate parsed output
    assert_command_succeeds "Valid parsed arguments should pass validation" -- validate_arguments_with_input "$parsed_output"
    
    # Test parsing with invalid option - should parse successfully but fail validation
    local invalid_parsed_output
    invalid_parsed_output=$(assert_command_succeeds "Invalid arguments should still parse successfully" -- parse_arguments install --invalid-option)
    
    # Should fail validation due to unknown option
    local validation_output
    validation_output=$(assert_command_fails 1 "Parsed arguments with unknown option should fail validation" -- validate_arguments_with_input "$invalid_parsed_output" 2>&1)
    
    assert_contains "Unknown option --invalid-option" "$validation_output" "Should output specific unknown option error message"
}

test_argument_parsing_edge_cases() {
    # Test empty shell value should succeed with marker
    local output
    output=$(assert_command_succeeds "Empty shell value should parse successfully with marker" -- parse_arguments install --shell)
    assert_contains "shell_no_value	true" "$output" "Should output shell_no_value marker"
    
    # Test help flag placement after command should succeed with marker
    local help_output
    help_output=$(assert_command_succeeds "Help flag after command should parse successfully with marker" -- parse_arguments install --help)
    assert_contains "help_after_command	true" "$help_output" "Should output help_after_command marker"
    
    # Test multiple flags should succeed
    local flags_output
    flags_output=$(assert_command_succeeds "Multiple flags should parse successfully" -- parse_arguments reinstall --debug --dry-run --https)
    assert_contains "debug	true" "$flags_output" "Should parse debug flag"
    assert_contains "dry_run	true" "$flags_output" "Should parse dry-run flag"  
    assert_contains "https	true" "$flags_output" "Should parse https flag"
}

test_complex_argument_combinations() {
    # Test complex real-world argument combinations
    local output
    output=$(assert_command_succeeds "Complex arguments should parse successfully" -- parse_arguments install --shell=zsh --remote-repository=git@github.com:user/repo.git --debug --https)
    
    assert_contains "command	install" "$output" "Should parse command"
    assert_contains "shell	zsh" "$output" "Should parse shell with equals syntax"
    assert_contains "remote_repository	git@github.com:user/repo.git" "$output" "Should parse remote repository"
    assert_contains "debug	true" "$output" "Should parse debug flag"
    assert_contains "https	true" "$output" "Should parse https flag"
    
    # Validate the complex combination
    assert_command_succeeds "Complex parsed arguments should pass validation" -- validate_arguments_with_input "$output"
}

# Register all test functions
register_tests \
    "test_parse_arguments_help_flag" \
    "test_parse_arguments_no_command" \
    "test_parse_arguments_valid_command" \
    "test_parse_arguments_with_options" \
    "test_parse_arguments_equals_syntax" \
    "test_parse_arguments_yes_flags" \
    "test_parse_arguments_remote_repository" \
    "test_parse_arguments_invalid_option" \
    "test_parse_arguments_missing_values" \
    "test_parse_arguments_help_after_command" \
    "test_validate_arguments_valid_commands" \
    "test_validate_arguments_invalid_command" \
    "test_validate_arguments_shell_validation" \
    "test_validate_arguments_help_bypass" \
    "test_validate_arguments_no_command_default" \
    "test_validate_arguments_missing_values" \
    "test_validate_arguments_help_after_command" \
    "test_validate_arguments_unknown_option" \
    "test_parse_and_validate_integration" \
    "test_argument_parsing_edge_cases" \
    "test_complex_argument_combinations"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "Claude Toolkit Argument Parsing and Validation Tests" "$@"
fi
