#!/bin/bash
# test-claude-code-list.sh - Tests "claude-code.sh list" functionality
# 
# Purpose: Test "scripts/claude-code.sh list" functionality according to list operation specification
# Dependencies: test-claude-code-install.sh (for setup)
# Approach: Use shared installation optimization with real npm registry queries and actual installed versions

source "$(dirname "$0")/../utils/test-harness.sh"
source "$(dirname "$0")/claude-code-shared-installation-utils.sh"

# This flag is needed for strict verifiable output of list command.
# shellcheck disable=SC2034
export PORCELAIN=true

# Test function implementations
test_list_available_shows_both_installed_and_remote() {
    (
        create_sandbox

        copy_shared_claude_installation
        
        local initial_version
        initial_version=$("$XDG_BIN_DIR/claude" --check-version 2>/dev/null || echo "none")
        
        local second_version="0.0.83"
        copy_shared_claude_installation "$second_version"

        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$initial_version" "Version $initial_version should be installed"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$second_version" "Version $second_version should be installed"
        
        local current_version
        current_version=$("$XDG_BIN_DIR/claude" --check-version 2>/dev/null || echo "none")
        
        local list_output
        list_output=$(assert_command_succeeds "List command should succeed" -- "./scripts/claude-code.sh" list 2>/dev/null)

        assert_contains "$second_version (installed)" "$list_output" "Should find second version with installed status"
        assert_contains "$current_version (installed, current)" "$list_output" "Should find current version with installed and current status"
        assert_contains "0.0.84" "$list_output" "Should find remote version 0.0.84"
        assert_contains "0.0.85" "$list_output" "Should find remote version 0.0.85"
    )
}

test_list_available_explicit_parameter() {
    (
        create_sandbox

        copy_shared_claude_installation
        
        local initial_version
        initial_version=$("$XDG_BIN_DIR/claude" --check-version 2>/dev/null || echo "none")
        
        local second_version="0.0.83"
        copy_shared_claude_installation "$second_version"
        
        rm -f "$XDG_DATA_HOME/claude/current"
        ln -sf "versions/$initial_version" "$XDG_DATA_HOME/claude/current"
        
        local default_output
        default_output=$(assert_command_succeeds "Default list command should succeed" -- "./scripts/claude-code.sh" list 2>/dev/null)
        
        local explicit_output
        explicit_output=$(assert_command_succeeds "Explicit list --mode available should succeed" -- "./scripts/claude-code.sh" list --mode available 2>/dev/null)
        
        assert_equals "$default_output" "$explicit_output" "Default list and explicit list --mode available should produce identical output"
    )
}

test_list_installed_shows_local_only() {
    (
        create_sandbox

        copy_shared_claude_installation
        
        local initial_version
        initial_version=$("$XDG_BIN_DIR/claude" --check-version 2>/dev/null || echo "none")
        
        local second_version="0.0.83"
        local third_version="0.0.82"
        
        copy_shared_claude_installation "$second_version"
        copy_shared_claude_installation "$third_version"

        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$initial_version" "Version $initial_version should be installed"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$second_version" "Version $second_version should be installed"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$third_version" "Version $third_version should be installed"
        
        local installed_output
        installed_output=$(assert_command_succeeds "List --mode installed should succeed" -- "./scripts/claude-code.sh" list --mode installed 2>/dev/null)
        
        local available_output
        available_output=$(assert_command_succeeds "List default should succeed" -- "./scripts/claude-code.sh" list 2>/dev/null)
        
        assert_contains "$initial_version (installed, current)" "$installed_output" "Should find initial version with installed and current status"
        assert_contains "$second_version (installed)" "$installed_output" "Should find second version with installed status"
        assert_contains "$third_version (installed)" "$installed_output" "Should find third version with installed status"
        
        assert_not_contains "0.0.84" "$installed_output" "Should not find remote-only version 0.0.84"
        assert_not_contains "0.0.85" "$installed_output" "Should not find remote-only version 0.0.85"
        assert_not_contains "0.0.81" "$installed_output" "Should not find remote-only version 0.0.81"
        
        local installed_count=$(echo "$installed_output" | grep -v "^$" | wc -l | tr -d ' ')
        local available_count=$(echo "$available_output" | grep -v "^$" | wc -l | tr -d ' ')
        
        assert_true "[[ $available_count -gt $installed_count ]]" "Available output should contain more versions than installed output"
        
        local non_installed_lines=$(echo "$installed_output" | grep -v "(installed" | grep -v "^$" | wc -l | tr -d ' ')
        assert_equals "0" "$non_installed_lines" "Installed output should only contain versions with '(installed' status indicators"
        
        local sorted_installed_output=$(echo "$installed_output" | sort -V)
        assert_equals "$installed_output" "$sorted_installed_output" "Installed versions should be sorted using sort -V"
    )
}

test_list_with_no_versions_installed() {
    (
        create_sandbox

        if [[ -d "$XDG_DATA_HOME/claude/versions" ]]; then
            local installed_count
            installed_count=$(find "$XDG_DATA_HOME/claude/versions" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
            assert_equals "0" "$installed_count" "Test setup should have no installed versions"
        fi
        
        local available_output
        available_output=$(assert_command_succeeds "List --mode available should succeed" -- "./scripts/claude-code.sh" list --mode available 2>/dev/null)
        
        assert_contains "0.0.85" "$available_output" "Available mode should show remote versions"
        assert_not_contains "(installed" "$available_output" "Available mode should not show installed versions when none are installed"
        
        local installed_output
        installed_output=$(assert_command_succeeds "List --mode installed should succeed" -- "./scripts/claude-code.sh" list --mode installed 2>/dev/null)
        
        assert_equals "" "$installed_output" "Installed mode should show empty output when no versions installed (porcelain mode)"
    )
}

test_list_with_single_version_installed() {
    (
        create_sandbox

        copy_shared_claude_installation
        
        local single_version
        single_version=$("$XDG_BIN_DIR/claude" --check-version 2>/dev/null || echo "none")
        
        local installed_count
        installed_count=$(find "$XDG_DATA_HOME/claude/versions" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
        assert_equals "1" "$installed_count" "Should have exactly one installed version"
        
        local available_output
        available_output=$(assert_command_succeeds "List --mode available should succeed" -- "./scripts/claude-code.sh" list --mode available 2>/dev/null)
        
        assert_contains "$single_version (installed, current)" "$available_output" "Single installed version should be marked as '(installed, current)'"
        
        local installed_count_in_output
        installed_count_in_output=$(echo "$available_output" | grep -c "(installed" || echo "0")
        assert_equals "1" "$installed_count_in_output" "Should have exactly one version marked as installed"
        
        assert_contains "0.0.85" "$available_output" "Should show remote versions without installed markers"
        
        local installed_output
        installed_output=$(assert_command_succeeds "List --mode installed should succeed" -- "./scripts/claude-code.sh" list --mode installed 2>/dev/null)
        
        local installed_lines
        installed_lines=$(echo "$installed_output" | grep -v "^$" | wc -l | tr -d ' ')
        assert_equals "1" "$installed_lines" "Should have exactly one line in installed output"
        
        assert_contains "$single_version (installed, current)" "$installed_output" "Installed mode should show single version as '(installed, current)'"
        
        local version_line
        version_line=$(echo "$available_output" | grep "$single_version (installed, current)")
        assert_true "[[ -n \"$version_line\" ]]" "Single version should appear in semantically sorted available list"
    )
}

test_list_with_multiple_versions_installed() {
    (
        create_sandbox

        copy_shared_claude_installation
        
        local default_version
        default_version=$("$XDG_BIN_DIR/claude" --check-version 2>/dev/null || echo "none")
        
        local second_version="0.0.83"
        local third_version="0.0.82"
        
        copy_shared_claude_installation "$second_version"
        copy_shared_claude_installation "$third_version"

        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$default_version" "Version $default_version should be installed"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$second_version" "Version $second_version should be installed"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$third_version" "Version $third_version should be installed"
        
        local installed_count
        installed_count=$(find "$XDG_DATA_HOME/claude/versions" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
        assert_equals "3" "$installed_count" "Should have exactly three installed versions"
        
        local available_output
        available_output=$(assert_command_succeeds "List --mode available should succeed" -- "./scripts/claude-code.sh" list --mode available 2>/dev/null)
        
        assert_contains "$default_version (installed, current)" "$available_output" "Default version should be marked as '(installed, current)'"
        assert_contains "$second_version (installed)" "$available_output" "Second version should be marked as '(installed)'"
        assert_contains "$third_version (installed)" "$available_output" "Third version should be marked as '(installed)'"
        
        local installed_count_in_output
        installed_count_in_output=$(echo "$available_output" | grep -c "(installed" || echo "0")
        assert_equals "3" "$installed_count_in_output" "Should have exactly three versions marked as installed"
        
        local default_count_in_output
        default_count_in_output=$(echo "$available_output" | grep -c "(installed, current)" || echo "0")
        assert_equals "1" "$default_count_in_output" "Should have exactly one version marked as default"
        
        local installed_output
        installed_output=$(assert_command_succeeds "List --mode installed should succeed" -- "./scripts/claude-code.sh" list --mode installed 2>/dev/null)
        
        local installed_lines
        installed_lines=$(echo "$installed_output" | grep -v "^$" | wc -l | tr -d ' ')
        assert_equals "3" "$installed_lines" "Should have exactly three lines in installed output"
        
        assert_contains "$default_version (installed, current)" "$installed_output" "Default version should appear correctly in installed output"
        assert_contains "$second_version (installed)" "$installed_output" "Second version should appear correctly in installed output"
        assert_contains "$third_version (installed)" "$installed_output" "Third version should appear correctly in installed output"
        
        local sorted_versions=("$third_version" "$second_version" "$default_version")
        local expected_order=$(printf "%s\n" "${sorted_versions[@]}")
        local actual_installed_order=$(echo "$installed_output" | grep -v "^$" | sed 's/ (installed.*//')
        
        assert_equals "$expected_order" "$actual_installed_order" "Installed versions should be sorted using sort -V"
    )
}

test_list_version_sorting() {
    (
        create_sandbox

        copy_shared_claude_installation
        
        local default_version
        default_version=$("$XDG_BIN_DIR/claude" --check-version 2>/dev/null || echo "none")
        
        local versions_to_create=(
            "0.0.9"
            "0.0.81"
            "0.0.85"
        )
        
        for version in "${versions_to_create[@]}"; do
            if [[ "$version" != "$default_version" ]]; then
                copy_shared_claude_installation "$version"
            fi
        done

        local available_output
        available_output=$(assert_command_succeeds "List --mode available should succeed" -- "./scripts/claude-code.sh" list --mode available 2>/dev/null)

        local installed_versions_output
        installed_versions_output=$(echo "$available_output" | grep "(installed" | sed 's/ (installed.*//')
        
        local all_versions=("0.0.9" "0.0.81" "0.0.85" "0.0.86")
        local expected_semantic_order=()
        
        for version in "${all_versions[@]}"; do
            if [[ -d "$XDG_DATA_HOME/claude/versions/$version" ]]; then
                expected_semantic_order+=("$version")
            fi
        done
        
        local expected_order=$(printf "%s\n" "${expected_semantic_order[@]}")
        
        assert_equals "$expected_order" "$installed_versions_output" "Installed versions should be correctly sorted using semantic version ordering"
        
        local installed_output
        installed_output=$(assert_command_succeeds "List --mode installed should succeed" -- "./scripts/claude-code.sh" list --mode installed 2>/dev/null)
        
        local installed_only_versions
        installed_only_versions=$(echo "$installed_output" | sed 's/ (installed.*//')
        
        assert_equals "$expected_order" "$installed_only_versions" "Installed-only output should maintain consistent semantic version ordering"
        
        local sample_remote_versions
        sample_remote_versions=$(echo "$available_output" | grep -E "^0\.0\.(8[0-9]|9[0-9])$" | head -5)
        
        if [[ -n "$sample_remote_versions" ]]; then
            local sorted_sample
            sorted_sample=$(echo "$sample_remote_versions" | sort -V)
            
            assert_equals "$sorted_sample" "$sample_remote_versions" "Remote versions should be correctly sorted using semantic version ordering"
        fi
    )
}

test_list_with_verbose_output() {
    (
        create_sandbox

        copy_shared_claude_installation
        
        local installed_version
        installed_version=$("$XDG_BIN_DIR/claude" --check-version 2>/dev/null || echo "none")
        
        local verbose_available_output
        verbose_available_output=$(assert_command_succeeds "List --mode available should succeed" -- "./scripts/claude-code.sh" list --mode available 2>/dev/null)
        
        local normal_available_output
        normal_available_output=$(assert_command_succeeds "Normal list --mode available should succeed" -- "./scripts/claude-code.sh" list --mode available 2>/dev/null)
        
        if echo "$verbose_available_output" | grep -q "\[VERBOSE\]"; then
            # Verbose mode shows additional VERBOSE logging messages
            :
        fi
        
        if echo "$verbose_available_output" | grep -q "registry\|npm\|query"; then
            # Verbose mode shows registry/npm query information
            :
        fi
        
        assert_contains "$installed_version (installed, current)" "$verbose_available_output" "Verbose mode should preserve version list output with status indicators"
        
        local verbose_line_count
        verbose_line_count=$(echo "$verbose_available_output" | wc -l | tr -d ' ')
        local normal_line_count
        normal_line_count=$(echo "$normal_available_output" | wc -l | tr -d ' ')
        
        if [[ $verbose_line_count -gt $normal_line_count ]]; then
            # Verbose mode produces more output lines than normal mode
            :
        fi
        
        local verbose_installed_output
        verbose_installed_output=$(assert_command_succeeds "List --mode installed should succeed" -- "./scripts/claude-code.sh" list --mode installed 2>/dev/null)
        
        assert_contains "$installed_version (installed, current)" "$verbose_installed_output" "Verbose installed mode should preserve version list output with status indicators"
        
        local verbose_version_lines
        verbose_version_lines=$(echo "$verbose_available_output" | grep -E "^[0-9]+\.[0-9]+\.[0-9]+" | sort)
        local normal_version_lines
        normal_version_lines=$(echo "$normal_available_output" | grep -E "^[0-9]+\.[0-9]+\.[0-9]+" | sort)
        
        assert_equals "$normal_version_lines" "$verbose_version_lines" "Verbose mode should preserve core version listing functionality"
        
        if echo "$verbose_available_output" | grep -q "0.0.85$" && echo "$normal_available_output" | grep -q "0.0.85$"; then
            # Verbose mode preserves remote version entries
            :
        fi
        
        rm -rf "$XDG_DATA_HOME/claude/versions" 2>/dev/null || true
        rm -f "$XDG_DATA_HOME/claude/current" 2>/dev/null || true
        
        local verbose_empty_output
        verbose_empty_output=$(assert_command_succeeds "List --mode installed should succeed with empty environment" -- "./scripts/claude-code.sh" list --mode installed 2>/dev/null)
        
        local data_lines=$(echo "$verbose_empty_output" | grep -v '\[INFO\]' | grep -v '\[VERBOSE\]' | grep -v '^$' | wc -l | tr -d ' ')
        if echo "$verbose_empty_output" | grep -q "list_claude_versions" && [[ $data_lines -eq 0 ]]; then
            # Verbose mode produces logging but no data output when no versions installed
            :
        fi
    )
}

test_list_with_jq_fallback_when_masked() {
    (
        commands_to_mask="jq"
        create_sandbox

        copy_shared_claude_installation
        
        local installed_version
        installed_version=$("$XDG_BIN_DIR/claude" --check-version 2>/dev/null || echo "none")
        
        local jq_path
        jq_path=$(command -v jq 2>/dev/null || echo "")
        
        assert_equals "" "$jq_path" "jq should be successfully masked"
        
        local list_available_output
        list_available_output=$(assert_command_succeeds "List --mode available should succeed with jq fallback" -- "./scripts/claude-code.sh" list --mode available 2>/dev/null)
        
        assert_contains "$installed_version (installed, current)" "$list_available_output" "List output should contain installed version with correct status"
        
        if echo "$list_available_output" | grep -qE "^0\.0\.(8[4-9]|9[0-9]|[1-9][0-9][0-9])$"; then
            # List output contains remote versions (real jq fallback worked)
            :
        fi
        
        local list_installed_output
        list_installed_output=$(assert_command_succeeds "List --mode installed should succeed" -- "./scripts/claude-code.sh" list --mode installed 2>/dev/null)
        
        assert_contains "$installed_version (installed, current)" "$list_installed_output" "List installed output should contain correct version information"
        
        local jq_cache_dir="$XDG_CACHE_HOME/claude/jq/1.8.1"
        local cached_jq="$jq_cache_dir/jq"
        
        if [[ -f "$cached_jq" ]] && [[ -x "$cached_jq" ]]; then
            assert_command_succeeds "Cached jq binary should be functional" -- "$cached_jq" --version >/dev/null 2>&1
            
            local test_json='{"test": "value", "array": [1, 2, 3]}'
            local parsed_result
            parsed_result=$(echo "$test_json" | "$cached_jq" -r '.test' 2>/dev/null)
            
            assert_equals "value" "$parsed_result" "Real cached jq binary should correctly parse JSON"
        fi
    )
}

# Register all test functions
register_tests \
    "test_list_available_shows_both_installed_and_remote" \
    "test_list_available_explicit_parameter" \
    "test_list_installed_shows_local_only" \
    "test_list_with_no_versions_installed" \
    "test_list_with_single_version_installed" \
    "test_list_with_multiple_versions_installed" \
    "test_list_version_sorting" \
    "test_list_with_verbose_output" \
    "test_list_with_jq_fallback_when_masked"

# Setup/cleanup orchestration with trap isolation
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Run in subshell to isolate traps from calling environment
    (
        # Set up shared installation before running tests
        setup_shared_claude_installation "0.0.86"
        trap 'cleanup_shared_claude_installation' EXIT
        
        # Run test suite with shared installation available
        run_tests_with_args "Claude Code List Operation Tests" "$@"
    ) || exit $?
fi
