#!/bin/bash
# test-claude-slash-argument-parsing.sh - Tests argument parsing and validation functions
# 
# Purpose: Test the parse_arguments and validate_arguments functions
# Dependencies: None (sources claude-slash.sh directly)
# Approach: Test parsing output format and validation rules in memory

source "$(dirname "$0")/../utils/test-harness.sh"

# Source the setup script to get access to functions under test
source "$(dirname "$0")/../../scripts/claude-slash.sh"

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

test_parse_arguments_valid_command() {
    # Test valid command parsing
    local output
    output=$(assert_command_succeeds "Valid command should parse successfully" -- parse_arguments install)
    
    assert_contains "command	install" "$output" "Should parse command correctly"
}

test_parse_arguments_with_options() {
    # Test command with various options
    local output
    output=$(assert_command_succeeds "Command with options should parse successfully" -- parse_arguments install --dry-run --yes)
    
    assert_contains "command	install" "$output" "Should parse command"
    assert_contains "dry_run	true" "$output" "Should parse dry-run flag"
    assert_contains "auto_accept	true" "$output" "Should parse yes flag"
}

test_parse_arguments_source_option() {
    # Test source option parsing
    local output
    output=$(assert_command_succeeds "Source option should parse successfully" -- parse_arguments list --source claude-toolkit --format detailed)
    
    assert_contains "command	list" "$output" "Should parse command"
    assert_contains "source	claude-toolkit" "$output" "Should parse source option"
    assert_contains "format	detailed" "$output" "Should parse format option"
}

test_parse_arguments_equals_syntax() {
    # Test --option=value syntax
    local output
    output=$(assert_command_succeeds "Equals syntax should parse successfully" -- parse_arguments reinstall --source=claude-toolkit)
    
    assert_contains "command	reinstall" "$output" "Should parse command"
    assert_contains "source	claude-toolkit" "$output" "Should parse source with equals syntax"
}

test_parse_arguments_invalid_option() {
    # Test invalid option should now succeed with unknown_option marker
    local output
    output=$(assert_command_succeeds "Invalid option should parse successfully with marker" -- parse_arguments install --invalid-option)
    
    assert_contains "command	install" "$output" "Should parse command correctly"
    assert_contains "unknown_option	--invalid-option" "$output" "Should output unknown_option marker"
}

test_parse_arguments_missing_values() {
    # Test missing values should now succeed with special markers
    local output
    output=$(assert_command_succeeds "Missing values should parse successfully with markers" -- parse_arguments list --source)
    
    assert_contains "command	list" "$output" "Should parse command correctly"
    assert_contains "source_no_value	true" "$output" "Should output source_no_value marker"
}

test_parse_arguments_help_after_command() {
    # Test help flag after command should now succeed with marker
    local output
    output=$(assert_command_succeeds "Help after command should parse successfully with marker" -- parse_arguments install --help)
    
    assert_contains "command	install" "$output" "Should parse command correctly"
    assert_contains "help_after_command	true" "$output" "Should output help_after_command marker"
}

test_parse_arguments_all_commands() {
    # Test all valid commands parse correctly
    local commands=("install" "reinstall" "uninstall" "list")
    
    for cmd in "${commands[@]}"; do
        local output
        output=$(assert_command_succeeds "Command '$cmd' should parse successfully" -- parse_arguments "$cmd")
        assert_contains "command	$cmd" "$output" "Should parse command '$cmd' correctly"
    done
}

# =============================================================================
# Tests for validate_arguments function
# =============================================================================

test_validate_arguments_valid_commands() {
    # Test all valid commands pass validation
    local commands=("install" "reinstall" "uninstall" "list")
    
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
    assert_contains "Valid commands: install, reinstall, uninstall, list" "$output" "Should list valid commands"
}

test_validate_arguments_no_command_error() {
    # Test missing command should fail with proper error message
    local input="no_command	true"
    local output
    output=$(assert_command_fails 1 "Missing command should fail validation with exit code 1" -- validate_arguments_with_input "$input" 2>&1)
    
    assert_contains "No command specified" "$output" "Should output no command error"
    assert_contains "Commands: install, reinstall, uninstall, list" "$output" "Should list valid commands"
}

test_validate_arguments_source_validation() {
    # Test valid source values for list command
    local valid_sources=("all" "user" "claude-toolkit")
    
    for source in "${valid_sources[@]}"; do
        local input=$'command	list\nsource	'"$source"
        assert_command_succeeds "Source '$source' should be valid for list command" -- validate_arguments_with_input "$input"
    done
    
    # Note: For the new multiple sources spec, any source name should be valid
    # as it could be a configured source name
    local input_custom=$'command	list\nsource	team-alpha'
    assert_command_succeeds "Custom source names should be valid for list command" -- validate_arguments_with_input "$input_custom"
}

test_validate_arguments_source_restriction() {
    # Test --source flag valid only for install, reinstall, uninstall, and list commands  
    local valid_commands=("list" "install" "reinstall" "uninstall")
    
    for cmd in "${valid_commands[@]}"; do
        local input_valid=$'command	'"$cmd"$'\nsource	all'
        assert_command_succeeds "--source flag should be valid for '$cmd' command" -- validate_arguments_with_input "$input_valid"
    done
    
    # Note: Source management commands (add-source, remove-source, list-sources) 
    # have been moved to claude-template-sources.sh and are no longer part of claude-slash.sh
}

test_validate_arguments_help_bypass() {
    # Test that help request bypasses other validation
    local input=$'help	true'
    assert_command_succeeds "Help request should bypass validation" -- validate_arguments_with_input "$input"
    
    # Test help with invalid command still passes
    local input_with_invalid=$'help	true\ncommand	invalid'
    assert_command_succeeds "Help request should bypass validation even with invalid command" -- validate_arguments_with_input "$input_with_invalid"
}

test_validate_arguments_missing_value_errors() {
    # Test missing value errors are caught
    local marker="source_no_value"
    local input="$marker	true"
    local output
    output=$(assert_command_fails 1 "Missing value error '$marker' should fail validation" -- validate_arguments_with_input "$input" 2>&1)

    assert_contains "--source requires a value" "$output" "Should output correct missing value error for '$marker'"
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
# Additional comprehensive parsing tests (previously only covered in integration)
# =============================================================================

test_parse_arguments_all_command_types() {
    # Test comprehensive parsing for all command types with various options
    local all_commands=("install" "reinstall" "uninstall" "list")
    
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
        assert_contains "auto_accept	true" "$global_output" "Should parse --yes for '$cmd'"
    done
}

test_parse_arguments_comprehensive_option_combinations() {
    # Test all possible option combinations that should parse successfully
    
    # Install/reinstall with all valid options
    local install_output
    install_output=$(assert_command_succeeds "Install with all options should parse" -- parse_arguments install --dry-run --yes)
    assert_contains "command	install" "$install_output" "Should parse install command"
    assert_contains "dry_run	true" "$install_output" "Should parse dry-run flag"
    assert_contains "auto_accept	true" "$install_output" "Should parse yes flag"

    # List with all valid options
    local list_output
    list_output=$(assert_command_succeeds "List with all options should parse" -- parse_arguments list --source claude-toolkit --format detailed --dry-run)
    assert_contains "command	list" "$list_output" "Should parse list command"
    assert_contains "source	claude-toolkit" "$list_output" "Should parse source option"
    assert_contains "format	detailed" "$list_output" "Should parse format option"
    assert_contains "dry_run	true" "$list_output" "Should parse dry-run flag"
    
    # Uninstall with global options
    local uninstall_output
    uninstall_output=$(assert_command_succeeds "Uninstall with options should parse" -- parse_arguments uninstall --dry-run --yes)
    assert_contains "command	uninstall" "$uninstall_output" "Should parse uninstall command"
    assert_contains "dry_run	true" "$uninstall_output" "Should parse dry-run flag for uninstall"
    assert_contains "auto_accept	true" "$uninstall_output" "Should parse yes flag for uninstall"
}

test_parse_arguments_global_options_all_combinations() {
    # Test all global option combinations across different commands
    local global_options=("--dry-run" "--yes")
    
    # Test single global options
    for option in "${global_options[@]}"; do
        local output
        output=$(assert_command_succeeds "Global option $option should parse with install" -- parse_arguments install "$option")
        
        case "$option" in
            "--dry-run")
                assert_contains "dry_run	true" "$output" "Should parse $option flag"
                ;;
            "--yes")
                assert_contains "auto_accept	true" "$output" "Should parse $option flag"
                ;;
        esac
    done
    
    # Test all global options together
    local all_global_output
    all_global_output=$(assert_command_succeeds "All global options should parse together" -- parse_arguments reinstall --dry-run --yes)
    assert_contains "dry_run	true" "$all_global_output" "Should parse dry-run in combination"
    assert_contains "auto_accept	true" "$all_global_output" "Should parse yes in combination"
}

test_parse_arguments_mixed_syntax_combinations() {
    # Test combinations of space-separated and equals syntax (using --format for list command)
    local mixed_output
    mixed_output=$(assert_command_succeeds "Mixed syntax should parse correctly" -- parse_arguments list --source=claude-toolkit --format detailed --dry-run)
    
    assert_contains "command	list" "$mixed_output" "Should parse command with mixed syntax"
    assert_contains "source	claude-toolkit" "$mixed_output" "Should parse equals syntax source"
    assert_contains "format	detailed" "$mixed_output" "Should parse space syntax format"
    assert_contains "dry_run	true" "$mixed_output" "Should parse space syntax dry-run"
}

# Register all test functions
register_tests \
    "test_parse_arguments_help_flag" \
    "test_parse_arguments_no_command" \
    "test_parse_arguments_valid_command" \
    "test_parse_arguments_with_options" \
    "test_parse_arguments_source_option" \
    "test_parse_arguments_equals_syntax" \
    "test_parse_arguments_invalid_option" \
    "test_parse_arguments_missing_values" \
    "test_parse_arguments_help_after_command" \
    "test_parse_arguments_all_commands" \
    "test_parse_arguments_all_command_types" \
    "test_parse_arguments_comprehensive_option_combinations" \
    "test_parse_arguments_global_options_all_combinations" \
    "test_parse_arguments_mixed_syntax_combinations" \
    "test_validate_arguments_valid_commands" \
    "test_validate_arguments_invalid_command" \
    "test_validate_arguments_no_command_error" \
    "test_validate_arguments_source_validation" \
    "test_validate_arguments_source_restriction" \
    "test_validate_arguments_help_bypass" \
    "test_validate_arguments_missing_value_errors" \
    "test_validate_arguments_help_after_command_error" \
    "test_validate_arguments_unknown_option_error"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "claude-slash.sh Argument Parsing Unit Tests" "$@"
fi
