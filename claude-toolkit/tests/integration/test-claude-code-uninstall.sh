#!/bin/bash
# test-claude-code-uninstall.sh - Tests "scripts/claude-code.sh uninstall" command functionality
# 
# Purpose: Test "scripts/claude-code.sh uninstall" command functionality with version awareness
# Dependencies: test-claude-code-install.sh (for setup)
# Approach: Use shared installation optimization - create one real installation, copy to each test sandbox

source "$(dirname "$0")/../utils/test-harness.sh"
source "$(dirname "$0")/claude-code-shared-installation-utils.sh"

export DEBUG=true

test_uninstall_single_default_installation() {
    (
        create_sandbox

        copy_shared_claude_installation
        
        assert_directory_exists "$XDG_DATA_HOME/claude" "Claude data directory should exist before uninstall"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions" "Claude versions directory should exist before uninstall"
        assert_symlink_exists "$XDG_DATA_HOME/claude/current" "Claude current symlink should exist before uninstall"
        assert_file_exists "$sandbox_dir/.local/bin/claude" "Claude wrapper script should exist before uninstall"
        assert_file_executable "$sandbox_dir/.local/bin/claude" "Claude wrapper script should be executable before uninstall"
        
        assert_file_exists "$sandbox_dir/.bash_profile" "Bash config should exist before uninstall"
        local pre_bash_profile_content=$(cat "$sandbox_dir/.bash_profile")
        assert_contains "# >>> xdg-user-bin start >>>" "$pre_bash_profile_content" "Bash config should contain XDG PATH markers before uninstall"
        assert_contains "# >>> claude-code.sh start >>>" "$pre_bash_profile_content" "Bash config should contain Claude Code markers before uninstall"
        
        local installed_version
        installed_version=$(assert_command_succeeds "Claude version check should succeed" -- "$sandbox_dir/.local/bin/claude" --check-version 2>/dev/null)
        
        local uninstall_output
        uninstall_output=$(assert_command_succeeds "Uninstall should succeed" -- "./scripts/claude-code.sh" uninstall --yes 2>&1)
        
        assert_contains "Starting Claude Code uninstall" "$uninstall_output" "Uninstall output should mention uninstall operation"
        assert_contains "Cleaned up Claude Code infrastructure" "$uninstall_output" "Uninstall output should confirm success"
        
        assert_directory_not_exists "$XDG_DATA_HOME/claude" "Claude data directory should be completely removed after single installation uninstall"
        assert_file_not_exists "$sandbox_dir/.local/bin/claude" "Claude wrapper script should be removed after single installation uninstall"
        assert_directory_not_exists "$sandbox_dir/.cache/claude" "Claude cache directory should be removed after single installation uninstall"
        
        local post_bash_profile_content=$(cat "$sandbox_dir/.bash_profile" 2>/dev/null || echo "")
        assert_not_contains "# >>> claude-code.sh start >>>" "$post_bash_profile_content" "Bash config should not contain Claude Code markers after uninstall"
        
        # Verify only script-specific configuration was removed, XDG PATH config should remain
        local filtered_content=$(echo "$post_bash_profile_content" | grep -v '# >>> xdg-user-bin start >>>' | grep -v '# XDG user executables directory' | grep -v 'export PATH=' | grep -v '# <<< xdg-user-bin end <<<')
        local non_whitespace_lines=$(echo "$filtered_content" | grep -v '^[[:space:]]*$' | grep -v '^[[:space:]]*#' | wc -l | tr -d ' ')
        assert_equals "0" "$non_whitespace_lines" "Shell config should only contain XDG PATH configuration after uninstall"

        local bin_contents=$(ls -1A "$sandbox_dir/.local/bin" 2>/dev/null | wc -l)
        if [[ $bin_contents -gt 0 ]]; then
            local non_shell_contents=$(ls -1A "$sandbox_dir/.local/bin" 2>/dev/null | grep -v "^bash$" | wc -l)
            assert_equals "0" "$non_shell_contents" "Local bin directory should be clean after uninstall"
        fi
    )
}

test_uninstall_single_specified_installation() {
    (
        create_sandbox

        copy_shared_claude_installation
        
        assert_directory_exists "$XDG_DATA_HOME/claude" "Claude data directory should exist before uninstall"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions" "Claude versions directory should exist before uninstall"
        assert_symlink_exists "$XDG_DATA_HOME/claude/current" "Claude current symlink should exist before uninstall"
        assert_file_exists "$sandbox_dir/.local/bin/claude" "Claude wrapper script should exist before uninstall"
        assert_file_executable "$sandbox_dir/.local/bin/claude" "Claude wrapper script should be executable before uninstall"
        
        assert_file_exists "$sandbox_dir/.bash_profile" "Bash config should exist before uninstall"
        local pre_bash_profile_content=$(cat "$sandbox_dir/.bash_profile")
        assert_contains "# >>> xdg-user-bin start >>>" "$pre_bash_profile_content" "Bash config should contain XDG PATH markers before uninstall"
        assert_contains "# >>> claude-code.sh start >>>" "$pre_bash_profile_content" "Bash config should contain Claude Code markers before uninstall"
        assert_contains "\${XDG_BIN_DIR:-\$HOME/.local/bin}:\$PATH" "$pre_bash_profile_content" "Bash config should contain variable-based XDG PATH before uninstall"
        
        local installed_version
        installed_version=$(assert_command_succeeds "Claude version check should succeed" -- "$sandbox_dir/.local/bin/claude" --check-version 2>/dev/null)
        
        assert_command_succeeds "Uninstall with specific version should succeed" -- "./scripts/claude-code.sh" uninstall --version "$installed_version" --yes >/dev/null 2>&1
        
        assert_directory_not_exists "$XDG_DATA_HOME/claude" "Claude data directory should be removed after single installation uninstall"
        assert_file_not_exists "$sandbox_dir/.local/bin/claude" "Claude wrapper script should be removed after single installation uninstall"
        assert_directory_not_exists "$sandbox_dir/.cache/claude" "Claude cache directory should be removed after single installation uninstall"
        
        local post_bash_profile_content=$(cat "$sandbox_dir/.bash_profile" 2>/dev/null || echo "")
        assert_not_contains "# >>> claude-code.sh start >>>" "$post_bash_profile_content" "Bash config should not contain Claude Code markers after uninstall"
        
        # Verify only script-specific configuration was removed, XDG PATH config should remain
        local filtered_content=$(echo "$post_bash_profile_content" | grep -v '# >>> xdg-user-bin start >>>' | grep -v '# XDG user executables directory' | grep -v 'export PATH=' | grep -v '# <<< xdg-user-bin end <<<')
        local non_whitespace_lines=$(echo "$filtered_content" | grep -v '^[[:space:]]*$' | grep -v '^[[:space:]]*#' | wc -l | tr -d ' ')
        assert_equals "0" "$non_whitespace_lines" "Shell config should only contain XDG PATH configuration after uninstall"

        local bin_contents=$(ls -1A "$sandbox_dir/.local/bin" 2>/dev/null | wc -l)
        if [[ $bin_contents -gt 0 ]]; then
            local non_shell_contents=$(ls -1A "$sandbox_dir/.local/bin" 2>/dev/null | grep -v "^bash$" | wc -l)
            assert_equals "0" "$non_shell_contents" "Local bin directory should be clean after uninstall"
        fi
    )
}

test_uninstall_default_installation_preserves_other_versions() {
    (
        create_sandbox

        copy_shared_claude_installation

        local initial_version
        initial_version=$(assert_command_succeeds "Claude version check should succeed" -- "$sandbox_dir/.local/bin/claude" --check-version 2>/dev/null)

        local second_version="0.0.85"
        copy_shared_claude_installation "$second_version"

        local versions_count=$(ls -1 "$XDG_DATA_HOME/claude/versions" 2>/dev/null | wc -l)
        assert_true "[[ $versions_count -ge 2 ]]" "Should have multiple versions installed"

        assert_directory_exists "$XDG_DATA_HOME/claude" "Claude data directory should exist before uninstall"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions" "Claude versions directory should exist before uninstall"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$initial_version" "Initial version directory should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$second_version" "Second version directory should exist"
        assert_file_exists "$sandbox_dir/.local/bin/claude" "Claude wrapper script should exist before uninstall"

        assert_file_exists "$sandbox_dir/.bash_profile" "Bash config should exist before uninstall"
        local pre_bash_profile_content=$(cat "$sandbox_dir/.bash_profile")
        assert_contains "# >>> xdg-user-bin start >>>" "$pre_bash_profile_content" "Bash config should contain XDG PATH markers before uninstall"
        assert_contains "# >>> claude-code.sh start >>>" "$pre_bash_profile_content" "Bash config should contain Claude Code markers before uninstall"

        local current_version_before
        current_version_before=$(assert_command_succeeds "Claude version check should succeed" -- "$sandbox_dir/.local/bin/claude" --check-version 2>/dev/null)
        assert_equals "$initial_version" "$current_version_before" "Current version should be initial version"

        assert_command_succeeds "Uninstall default version should succeed" -- "./scripts/claude-code.sh" uninstall --yes >/dev/null 2>&1

        assert_directory_exists "$XDG_DATA_HOME/claude" "Claude data directory should still exist (other versions remain)"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions" "Claude versions directory should still exist"

        assert_directory_not_exists "$XDG_DATA_HOME/claude/versions/$initial_version" "Initial version directory should be removed after uninstall"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$second_version" "Second version directory should still exist"

        assert_file_exists "$sandbox_dir/.local/bin/claude" "Claude wrapper script should still exist (other versions remain)"
        assert_file_executable "$sandbox_dir/.local/bin/claude" "Claude wrapper script should still be executable"

        assert_symlink_exists "$XDG_DATA_HOME/claude/current" "Current symlink should exist after smart version switching"

        local current_version_after
        current_version_after=$(assert_command_succeeds "Claude version check should succeed" -- "$sandbox_dir/.local/bin/claude" --check-version 2>/dev/null)
        assert_equals "$second_version" "$current_version_after" "Current version should switch to remaining version"

        local post_bash_profile_content=$(cat "$sandbox_dir/.bash_profile" 2>/dev/null || echo "")
        assert_equals "$pre_bash_profile_content" "$post_bash_profile_content" "Shell configuration should not change when other versions remain"

        assert_directory_exists "$sandbox_dir/.cache/claude" "Cache directory should be preserved (other versions remain)"
    )
}

test_uninstall_specified_installation_preserves_other_versions() {
    (
        create_sandbox

        copy_shared_claude_installation

        local initial_version
        initial_version=$(assert_command_succeeds "Claude version check should succeed" -- "$sandbox_dir/.local/bin/claude" --check-version 2>/dev/null)

        local second_version="0.0.85"
        local third_version="0.0.84"
        
        copy_shared_claude_installation "$second_version"
        copy_shared_claude_installation "$third_version"
        
        rm -f "$XDG_DATA_HOME/claude/current"
        ln -sf "versions/$initial_version" "$XDG_DATA_HOME/claude/current"

        local versions_count=$(ls -1 "$XDG_DATA_HOME/claude/versions" 2>/dev/null | wc -l)
        assert_true "[[ $versions_count -ge 3 ]]" "Should have multiple versions installed"

        assert_directory_exists "$XDG_DATA_HOME/claude" "Claude data directory should exist before uninstall"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions" "Claude versions directory should exist before uninstall"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$initial_version" "Initial version directory should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$second_version" "Second version directory should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$third_version" "Third version directory should exist"
        assert_file_exists "$sandbox_dir/.local/bin/claude" "Claude wrapper script should exist before uninstall"

        assert_file_exists "$sandbox_dir/.bash_profile" "Bash config should exist before uninstall"
        local pre_bash_profile_content=$(cat "$sandbox_dir/.bash_profile")
        assert_contains "# >>> xdg-user-bin start >>>" "$pre_bash_profile_content" "Bash config should contain XDG PATH markers before uninstall"
        assert_contains "# >>> claude-code.sh start >>>" "$pre_bash_profile_content" "Bash config should contain Claude Code markers before uninstall"

        local current_version_before
        current_version_before=$(assert_command_succeeds "Claude version check should succeed" -- "$sandbox_dir/.local/bin/claude" --check-version 2>/dev/null)
        assert_equals "$initial_version" "$current_version_before" "Current version should be initial version"

        assert_command_succeeds "Uninstall non-default version should succeed" -- "./scripts/claude-code.sh" uninstall --version "$third_version" --yes >/dev/null 2>&1

        assert_directory_exists "$XDG_DATA_HOME/claude" "Claude data directory should still exist (other versions remain)"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions" "Claude versions directory should still exist"

        assert_directory_not_exists "$XDG_DATA_HOME/claude/versions/$third_version" "Third version directory should be removed after uninstall"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$initial_version" "Initial version directory should still exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$second_version" "Second version directory should still exist"

        local current_version_after_nondefault
        current_version_after_nondefault=$(assert_command_succeeds "Claude version check should succeed" -- "$sandbox_dir/.local/bin/claude" --check-version 2>/dev/null)
        assert_equals "$initial_version" "$current_version_after_nondefault" "Current version should remain unchanged after non-default uninstall"

        assert_command_succeeds "Uninstall default version should succeed" -- "./scripts/claude-code.sh" uninstall --version "$initial_version" --yes >/dev/null 2>&1

        assert_directory_exists "$XDG_DATA_HOME/claude" "Claude data directory should still exist (other versions remain)"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions" "Claude versions directory should still exist"

        assert_directory_not_exists "$XDG_DATA_HOME/claude/versions/$initial_version" "Initial version directory should be removed after uninstall"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$second_version" "Second version directory should still exist"

        assert_file_exists "$sandbox_dir/.local/bin/claude" "Claude wrapper script should still exist (other versions remain)"
        assert_file_executable "$sandbox_dir/.local/bin/claude" "Claude wrapper script should still be executable"

        assert_symlink_exists "$XDG_DATA_HOME/claude/current" "Current symlink should exist after smart version switching"

        local current_version_after_default
        current_version_after_default=$(assert_command_succeeds "Claude version check should succeed" -- "$sandbox_dir/.local/bin/claude" --check-version 2>/dev/null)
        assert_equals "$second_version" "$current_version_after_default" "Current version should switch to remaining version after default uninstall"

        local post_bash_profile_content=$(cat "$sandbox_dir/.bash_profile" 2>/dev/null || echo "")
        assert_equals "$pre_bash_profile_content" "$post_bash_profile_content" "Shell configuration should not change when other versions remain"

        assert_directory_exists "$sandbox_dir/.cache/claude" "Cache directory should be preserved (other versions remain)"
    )
}

test_uninstall_with_all_flag() {
    (
        create_sandbox

        copy_shared_claude_installation

        local initial_version
        initial_version=$(assert_command_succeeds "Claude version check should succeed" -- "$sandbox_dir/.local/bin/claude" --check-version 2>/dev/null)
        local second_version="0.0.85"
        local third_version="0.0.84"
        
        copy_shared_claude_installation "$second_version"
        copy_shared_claude_installation "$third_version"

        local versions_count=$(ls -1 "$XDG_DATA_HOME/claude/versions" 2>/dev/null | wc -l)
        assert_true "[[ $versions_count -ge 3 ]]" "Should have multiple versions for complete cleanup test"

        assert_directory_exists "$XDG_DATA_HOME/claude" "Claude data directory should exist before uninstall"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions" "Claude versions directory should exist before uninstall"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$initial_version" "Initial version directory should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$second_version" "Second version directory should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$third_version" "Third version directory should exist"
        assert_symlink_exists "$XDG_DATA_HOME/claude/current" "Current symlink should exist before uninstall"
        assert_file_exists "$sandbox_dir/.local/bin/claude" "Claude wrapper script should exist before uninstall"
        assert_file_executable "$sandbox_dir/.local/bin/claude" "Claude wrapper script should be executable before uninstall"

        assert_file_exists "$sandbox_dir/.bash_profile" "Bash config should exist before uninstall"
        local pre_bash_profile_content=$(cat "$sandbox_dir/.bash_profile")
        assert_contains "# >>> xdg-user-bin start >>>" "$pre_bash_profile_content" "Bash config should contain XDG PATH markers before uninstall"
        assert_contains "# >>> claude-code.sh start >>>" "$pre_bash_profile_content" "Bash config should contain Claude Code markers before uninstall"

        assert_command_succeeds "Uninstall with --all flag should succeed" -- "./scripts/claude-code.sh" uninstall --all --yes >/dev/null 2>&1

        assert_directory_not_exists "$XDG_DATA_HOME/claude" "Claude data directory should be completely removed after --all uninstall"
        assert_file_not_exists "$sandbox_dir/.local/bin/claude" "Claude wrapper script should be removed after --all uninstall"
        assert_directory_not_exists "$sandbox_dir/.cache/claude" "Claude cache directory should be removed after --all uninstall"

        local post_bash_profile_content=$(cat "$sandbox_dir/.bash_profile" 2>/dev/null || echo "")
        assert_not_contains "# >>> claude-code.sh start >>>" "$post_bash_profile_content" "Bash config should not contain Claude Code markers after --all uninstall"

        local filtered_content=$(echo "$post_bash_profile_content" | grep -v '# >>> xdg-user-bin start >>>' | grep -v '# XDG user executables directory' | grep -v 'export PATH=' | grep -v '# <<< xdg-user-bin end <<<')
        local non_whitespace_lines=$(echo "$filtered_content" | grep -v '^[[:space:]]*$' | grep -v '^[[:space:]]*#' | wc -l | tr -d ' ')
        assert_equals "0" "$non_whitespace_lines" "Shell config should only contain XDG PATH configuration after --all uninstall"

        local bin_contents=$(ls -1A "$sandbox_dir/.local/bin" 2>/dev/null | wc -l)
        if [[ $bin_contents -gt 0 ]]; then
            local non_shell_contents=$(ls -1A "$sandbox_dir/.local/bin" 2>/dev/null | grep -v "^bash$" | wc -l)
            assert_equals "0" "$non_shell_contents" "Local bin directory should be clean after --all uninstall"
        fi
    )
}

test_uninstall_shell_configuration_cleanup() {
    (
        create_sandbox

        copy_shared_claude_installation
        
        assert_file_exists "$sandbox_dir/.bash_profile" "Bash config should exist before uninstall"
        local pre_bash_profile_content=$(cat "$sandbox_dir/.bash_profile")
        assert_contains "# >>> xdg-user-bin start >>>" "$pre_bash_profile_content" "Bash config should contain XDG PATH markers before uninstall"
        assert_contains "# >>> claude-code.sh start >>>" "$pre_bash_profile_content" "Bash config should contain Claude Code markers before uninstall"
        
        assert_command_succeeds "Uninstall should succeed" -- "./scripts/claude-code.sh" uninstall --yes >/dev/null 2>&1
        
        local post_bash_profile_content=$(cat "$sandbox_dir/.bash_profile" 2>/dev/null || echo "")
        assert_not_contains "# >>> claude-code.sh start >>>" "$post_bash_profile_content" "Bash config should not contain Claude Code markers after uninstall"
        
        # Verify only script-specific configuration was removed, XDG PATH config should remain
        local filtered_content=$(echo "$post_bash_profile_content" | grep -v '# >>> xdg-user-bin start >>>' | grep -v '# XDG user executables directory' | grep -v 'export PATH=' | grep -v '# <<< xdg-user-bin end <<<')
        local non_whitespace_lines=$(echo "$filtered_content" | grep -v '^[[:space:]]*$' | grep -v '^[[:space:]]*#' | wc -l | tr -d ' ')
        assert_equals "0" "$non_whitespace_lines" "Shell config should only contain XDG PATH configuration after uninstall"

        local post_zshrc_content=$(cat "$sandbox_dir/.zshrc" 2>/dev/null || echo "")
        assert_not_contains "# >>> claude-code.sh start >>>" "$post_zshrc_content" "Zsh config should not contain Claude Code markers after uninstall"

        local post_fish_content=$(cat "$sandbox_dir/.config/fish/config.fish" 2>/dev/null || echo "")
        assert_not_contains "# >>> claude-code.sh start >>>" "$post_fish_content" "Fish config should not contain Claude Code markers after uninstall"
    )
}

test_uninstall_error_handling_nonexistent_version() {
    (
        create_sandbox

        copy_shared_claude_installation
        
        assert_directory_exists "$XDG_DATA_HOME/claude" "Claude data directory should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions" "Claude versions directory should exist"
        
        local installed_version
        installed_version=$(ls -1 "$XDG_DATA_HOME/claude/versions" | head -n1)
        
        local nonexistent_version="9.9.99"
        
        local uninstall_output
        uninstall_output=$(assert_command_fails "Uninstall of nonexistent version should fail" -- "./scripts/claude-code.sh" uninstall --version "$nonexistent_version" --yes 2>&1)
        
        assert_contains "Version $nonexistent_version is not installed" "$uninstall_output" "Error output should mention version is not installed"
        assert_contains "[ERROR]" "$uninstall_output" "Error output should contain [ERROR] tagged message"
        
        assert_not_contains "Removed version directory" "$uninstall_output" "Error case should not show successful removal messages"
        assert_not_contains "Cleaned up Claude Code infrastructure" "$uninstall_output" "Error case should not show cleanup success messages"
        
        assert_directory_exists "$XDG_DATA_HOME/claude" "Claude data directory should still exist after failed uninstall"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$installed_version" "Existing version should still exist after failed uninstall"
        assert_file_exists "$sandbox_dir/.local/bin/claude" "Claude wrapper script should still exist after failed uninstall"
        assert_symlink_exists "$XDG_DATA_HOME/claude/current" "Current symlink should still exist after failed uninstall"
        
        assert_command_succeeds "Claude wrapper should still be functional" -- "$sandbox_dir/.local/bin/claude" --check >/dev/null 2>&1
    )
}

test_uninstall_error_handling_permission_issues() {
    (
        create_sandbox

        copy_shared_claude_installation
        
        assert_directory_exists "$XDG_DATA_HOME/claude" "Claude data directory should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions" "Claude versions directory should exist"
        
        local installed_version
        installed_version=$(ls -1 "$XDG_DATA_HOME/claude/versions" | head -n1)
        
        chmod 444 "$XDG_DATA_HOME/claude/versions/$installed_version"
        chmod 444 "$XDG_DATA_HOME/claude/versions"
        
        local uninstall_output
        uninstall_output=$(assert_command_fails "Uninstall should fail due to permission issues" -- "./scripts/claude-code.sh" uninstall --version "$installed_version" --yes 2>&1)
        
        chmod 755 "$XDG_DATA_HOME/claude/versions" 2>/dev/null || true
        chmod -R 755 "$XDG_DATA_HOME/claude/versions/$installed_version" 2>/dev/null || true
        
        assert_contains "[ERROR]" "$uninstall_output" "Error output should contain [ERROR] tagged message"
        assert_not_contains "Cleaned up Claude Code infrastructure" "$uninstall_output" "Error case should not show complete cleanup success messages"
        
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$installed_version" "Version directory should still exist after permission failure"
        
        assert_command_succeeds "Claude wrapper should work after permission test" -- "$sandbox_dir/.local/bin/claude" --check >/dev/null 2>&1
    )
}

# Register all test functions
register_tests \
    "test_uninstall_single_default_installation" \
    "test_uninstall_single_specified_installation" \
    "test_uninstall_default_installation_preserves_other_versions" \
    "test_uninstall_specified_installation_preserves_other_versions" \
    "test_uninstall_with_all_flag" \
    "test_uninstall_shell_configuration_cleanup" \
    "test_uninstall_error_handling_nonexistent_version" \
    "test_uninstall_error_handling_permission_issues"

# Setup/cleanup orchestration with trap isolation
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Run in subshell to isolate traps from calling environment
    (
        # Set up shared installation before running tests
        setup_shared_claude_installation "0.0.86"
        trap 'cleanup_shared_claude_installation' EXIT
        
        # Run test suite with shared installation available
        run_tests_with_args "Claude Code Uninstallation Tests" "$@"
    ) || exit $?
fi
