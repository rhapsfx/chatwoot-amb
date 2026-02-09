#!/bin/bash
# test-claude-code-install.sh - Tests "scripts/claude-code.sh install" functionality
# 
# Purpose: Test "scripts/claude-code.sh install" functionality directly in sandbox environments
# Dependencies: None (no shared installation utils - tests genuine install commands only)
# Approach: Use real install command invocations in isolated sandboxes, validate directory structures

source "$(dirname "$0")/../utils/test-harness.sh"

export DEBUG=true

test_install_basic_functionality() {
    (
        create_sandbox

        commands_to_mask="jq"
        setup_fake_bash_shell
        
        local test_version="0.0.85"
        
        assert_command_succeeds "Installation should succeed" -- "./scripts/claude-code.sh" install --version "$test_version" >/dev/null 2>&1
        
        assert_directory_exists "$XDG_DATA_HOME/claude" "Claude data directory should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions" "Claude versions directory should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$test_version" "Specific version directory should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/current" "Claude current symlink should exist"
        assert_directory_exists "$sandbox_dir/.local/bin" "Local bin directory should exist"
        
        local current_version_path=$(readlink "$XDG_DATA_HOME/claude/current")
        assert_contains "$test_version" "$current_version_path" "Current version should point to specific version"
        
        assert_file_exists "$sandbox_dir/.local/bin/claude" "Claude wrapper script should exist"
        assert_file_executable "$sandbox_dir/.local/bin/claude" "Claude wrapper script should be executable"
        
        local check_version_result
        check_version_result=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        assert_contains "$test_version" "$check_version_result" "Wrapper script should return installed version"
        
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$test_version/nodejs" "Node.js should be installed for specific version"
        assert_file_exists "$XDG_DATA_HOME/claude/versions/$test_version/nodejs/bin/node" "Node.js binary should exist"
        assert_file_exists "$XDG_DATA_HOME/claude/versions/$test_version/nodejs/bin/claude" "Claude binary should exist"
        
        local bash_profile_content=$(cat "$sandbox_dir/.bash_profile")
        assert_contains "# >>> xdg-user-bin start >>>" "$bash_profile_content" "Bash config should contain XDG PATH markers"
        assert_contains "# >>> claude-code.sh start >>>" "$bash_profile_content" "Bash config should contain Claude markers"
    )
}

test_install_idempotency() {
    (
        create_sandbox

        setup_fake_bash_shell
        
        local test_version="0.0.85"
        
        assert_command_succeeds "First installation should succeed" -- "./scripts/claude-code.sh" install --version "$test_version" >/dev/null 2>&1
        
        local first_install_current=$(readlink "$XDG_DATA_HOME/claude/current")
        local first_install_wrapper_content=$(<"$sandbox_dir/.local/bin/claude")
        
        assert_directory_exists "$XDG_DATA_HOME/claude" "Claude data directory should exist after first install"
        assert_file_exists "$sandbox_dir/.local/bin/claude" "Claude wrapper script should exist after first install"
        
        local first_check_result
        first_check_result=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        assert_contains "$test_version" "$first_check_result" "Wrapper should work after first install"
        
        assert_command_succeeds "Second installation should succeed" -- "./scripts/claude-code.sh" install --version "$test_version" >/dev/null 2>&1
        
        local second_install_current=$(readlink "$XDG_DATA_HOME/claude/current")
        local second_install_wrapper_content=$(<"$sandbox_dir/.local/bin/claude")
        
        assert_directory_exists "$XDG_DATA_HOME/claude" "Claude data directory should exist after second install"
        assert_file_exists "$sandbox_dir/.local/bin/claude" "Claude wrapper script should exist after second install"
        
        assert_equals "$first_install_current" "$second_install_current" "Current version should be same after repeated installation"
        assert_equals "$first_install_wrapper_content" "$second_install_wrapper_content" "Wrapper script content should be identical after repeated installation"
        
        local second_check_result
        second_check_result=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        assert_contains "$test_version" "$second_check_result" "Wrapper should work after second install"
        
        assert_command_succeeds "Third installation should succeed" -- "./scripts/claude-code.sh" install --version "$test_version" >/dev/null 2>&1
        
        local third_install_current=$(readlink "$XDG_DATA_HOME/claude/current")
        assert_equals "$first_install_current" "$third_install_current" "Current version should remain consistent after third install"
        
        local third_check_result
        third_check_result=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        assert_contains "$test_version" "$third_check_result" "Wrapper should work after third install"
    )
}

test_install_shell_configuration() {
    (
        create_sandbox

        setup_fake_all_shells

        local install_output
        install_output=$(assert_command_succeeds "Installation should succeed" -- "./scripts/claude-code.sh" install 2>&1)

        assert_directory_exists "$XDG_DATA_HOME/claude" "Claude data directory should exist"
        assert_file_exists "$sandbox_dir/.local/bin/claude" "Claude wrapper script should exist"

        assert_contains "Auto-detected shells:" "$install_output" "Installation should show detected shells"

        local xdg_marker_start="# >>> xdg-user-bin start >>>"
        local xdg_marker_end="# <<< xdg-user-bin end <<<"
        local script_marker_start="# >>> claude-code.sh start >>>"
        local script_marker_end="# <<< claude-code.sh end <<<"

        assert_file_exists "$sandbox_dir/.bash_profile"
        local bash_profile_content=$(cat "$sandbox_dir/.bash_profile")
        assert_contains "$xdg_marker_start" "$bash_profile_content" "Bash config should contain XDG PATH markers"
        assert_contains "$xdg_marker_end" "$bash_profile_content" "Bash config should contain XDG PATH end marker"
        assert_contains "$script_marker_start" "$bash_profile_content" "Bash config should contain script markers"
        assert_contains "$script_marker_end" "$bash_profile_content" "Bash config should contain script end marker"

        assert_file_exists "$sandbox_dir/.zshrc"
        local zshrc_content=$(cat "$sandbox_dir/.zshrc")
        assert_contains "$xdg_marker_start" "$zshrc_content" "Zsh config should contain XDG PATH markers"
        assert_contains "$xdg_marker_end" "$zshrc_content" "Zsh config should contain XDG PATH end marker"
        assert_contains "$script_marker_start" "$zshrc_content" "Zsh config should contain script markers"
        assert_contains "$script_marker_end" "$zshrc_content" "Zsh config should contain script end marker"

        assert_file_exists "$sandbox_dir/.config/fish/config.fish"
        local fish_config_content=$(cat "$sandbox_dir/.config/fish/config.fish")
        assert_contains "$xdg_marker_start" "$fish_config_content" "Fish config should contain XDG PATH markers"
        assert_contains "$xdg_marker_end" "$fish_config_content" "Fish config should contain XDG PATH end marker"
        assert_contains "$script_marker_start" "$fish_config_content" "Fish config should contain script markers"
        assert_contains "$script_marker_end" "$fish_config_content" "Fish config should contain script end marker"
        assert_contains "set -gx PATH" "$fish_config_content" "Fish config should use proper PATH export syntax"

        local check_result
        check_result=$("$sandbox_dir/.local/bin/claude" --check 2>&1)
        assert_contains "Claude wrapper checked successfully" "$check_result" "Wrapper script should work after shell configuration"
    )
}

test_install_with_shell_parameter_bash() {
    (
        create_sandbox

        setup_fake_all_shells
        
        local install_output
        install_output=$(assert_command_succeeds "Installation with --shell=bash should succeed" -- "./scripts/claude-code.sh" install --shell=bash 2>&1)
        
        assert_directory_exists "$XDG_DATA_HOME/claude" "Claude data directory should exist"
        assert_file_exists "$sandbox_dir/.local/bin/claude" "Claude wrapper script should exist"
        
        assert_contains "update_shell_config(bash)" "$install_output" "Installation should show target shell parameter"
        
        local bash_content=$(cat "$sandbox_dir/.bash_profile")
        assert_contains "# >>> xdg-user-bin start >>>" "$bash_content" "Bash config should be updated with --shell=bash"
        assert_contains "# >>> claude-code.sh start >>>" "$bash_content" "Bash config should have script markers"
        
        local zsh_content=$(cat "$sandbox_dir/.zshrc")
        assert_equals "" "$zsh_content" "Zsh config should be empty when --shell=bash used"
        
        local fish_content=$(cat "$sandbox_dir/.config/fish/config.fish")
        assert_equals "" "$fish_content" "Fish config should be empty when --shell=bash used"
        
        local check_result
        check_result=$("$sandbox_dir/.local/bin/claude" --check 2>&1)
        assert_contains "Claude wrapper checked successfully" "$check_result" "Wrapper script should work after bash-specific configuration"
    )
}

test_install_with_shell_parameter_zsh() {
    (
        create_sandbox

        setup_fake_all_shells
        
        local install_output
        install_output=$(assert_command_succeeds "Installation with --shell=zsh should succeed" -- "./scripts/claude-code.sh" install --shell=zsh 2>&1)
        
        assert_directory_exists "$XDG_DATA_HOME/claude" "Claude data directory should exist"
        assert_file_exists "$sandbox_dir/.local/bin/claude" "Claude wrapper script should exist"
        
        assert_contains "update_shell_config(zsh)" "$install_output" "Installation should show target shell parameter"
        
        local zsh_content=$(cat "$sandbox_dir/.zshrc")
        assert_contains "# >>> xdg-user-bin start >>>" "$zsh_content" "Zsh config should be updated with --shell=zsh"
        assert_contains "# >>> claude-code.sh start >>>" "$zsh_content" "Zsh config should have script markers"
        
        local bash_content=$(cat "$sandbox_dir/.bash_profile")
        assert_equals "" "$bash_content" "Bash config should be empty when --shell=zsh used"
        
        local fish_content=$(cat "$sandbox_dir/.config/fish/config.fish")
        assert_equals "" "$fish_content" "Fish config should be empty when --shell=zsh used"
        
        local check_result
        check_result=$("$sandbox_dir/.local/bin/claude" --check 2>&1)
        assert_contains "Claude wrapper checked successfully" "$check_result" "Wrapper script should work after zsh-specific configuration"
    )
}

test_install_with_shell_parameter_fish() {
    (
        create_sandbox

        setup_fake_all_shells
        
        local install_output
        install_output=$(assert_command_succeeds "Installation with --shell=fish should succeed" -- "./scripts/claude-code.sh" install --shell=fish 2>&1)
        
        assert_directory_exists "$XDG_DATA_HOME/claude" "Claude data directory should exist"
        assert_file_exists "$sandbox_dir/.local/bin/claude" "Claude wrapper script should exist"
        
        assert_contains "update_shell_config(fish)" "$install_output" "Installation should show target shell parameter"
        
        local fish_content=$(cat "$sandbox_dir/.config/fish/config.fish")
        assert_contains "# >>> xdg-user-bin start >>>" "$fish_content" "Fish config should be updated with --shell=fish"
        assert_contains "# >>> claude-code.sh start >>>" "$fish_content" "Fish config should have script markers"
        assert_contains "set -gx PATH" "$fish_content" "Fish config should use proper PATH export syntax"
        
        local bash_content=$(cat "$sandbox_dir/.bash_profile")
        assert_equals "" "$bash_content" "Bash config should be empty when --shell=fish used"
        
        local zsh_content=$(cat "$sandbox_dir/.zshrc")
        assert_equals "" "$zsh_content" "Zsh config should be empty when --shell=fish used"
        
        local check_result
        check_result=$("$sandbox_dir/.local/bin/claude" --check 2>&1)
        assert_contains "Claude wrapper checked successfully" "$check_result" "Wrapper script should work after fish-specific configuration"
    )
}

test_install_multiple_versions() {
    (
        create_sandbox

        commands_to_mask="zsh,fish"
        setup_fake_bash_shell

        local first_version="0.0.84"
        assert_command_succeeds "First installation should succeed" -- "./scripts/claude-code.sh" install --version "$first_version" >/dev/null 2>&1

        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$first_version" "First version directory should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$first_version/nodejs" "First version Node.js should exist"
        assert_file_exists "$XDG_DATA_HOME/claude/versions/$first_version/nodejs/bin/claude" "First version Claude binary should exist"

        local current_after_first=$(readlink "$XDG_DATA_HOME/claude/current")
        assert_contains "$first_version" "$current_after_first" "First version should be set as current after installation"

        local first_check_result
        first_check_result=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        assert_contains "$first_version" "$first_check_result" "Wrapper should return first version after first installation"

        local second_version="0.0.85"
        assert_command_succeeds "Second installation should succeed" -- "./scripts/claude-code.sh" install --version "$second_version" >/dev/null 2>&1

        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$second_version" "Second version directory should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$second_version/nodejs" "Second version Node.js should exist"
        assert_file_exists "$XDG_DATA_HOME/claude/versions/$second_version/nodejs/bin/claude" "Second version Claude binary should exist"

        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$first_version" "First version should still exist after second installation"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$second_version" "Second version should exist after installation"

        local current_after_second=$(readlink "$XDG_DATA_HOME/claude/current")
        assert_contains "$second_version" "$current_after_second" "Second version should be set as current after installation"

        local second_check_result
        second_check_result=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        assert_contains "$second_version" "$second_check_result" "Wrapper should return second version after second installation"

        local third_version="0.0.86"
        assert_command_succeeds "Third installation should succeed" -- "./scripts/claude-code.sh" install --version "$third_version" >/dev/null 2>&1

        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$third_version" "Third version directory should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$third_version/nodejs" "Third version Node.js should exist"
        assert_file_exists "$XDG_DATA_HOME/claude/versions/$third_version/nodejs/bin/claude" "Third version Claude binary should exist"

        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$first_version" "First version should still exist after third installation"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$second_version" "Second version should still exist after third installation"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$third_version" "Third version should exist after installation"

        local current_after_third=$(readlink "$XDG_DATA_HOME/claude/current")
        assert_contains "$third_version" "$current_after_third" "Third version should be set as current after installation"

        local third_check_result
        third_check_result=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        assert_contains "$third_version" "$third_check_result" "Wrapper should return third version after third installation"

        assert_file_exists "$sandbox_dir/.local/bin/claude" "Wrapper script should exist"
        assert_file_executable "$sandbox_dir/.local/bin/claude" "Wrapper script should be executable"

        local bash_profile_content=$(cat "$sandbox_dir/.bash_profile" 2>/dev/null || echo "")
        local script_marker_count=$(echo "$bash_profile_content" | grep -c "# >>> claude-code.sh start >>>" || echo "0")
        assert_equals "1" "$script_marker_count" "Shell configuration should appear only once despite multiple installations"
    )
}

test_install_error_handling_invalid_version() {
    (
        create_sandbox

        setup_fake_bash_shell

        local invalid_version="99.99.99"
        
        local install_output
        install_output=$(assert_command_fails "Installation should fail with invalid version" -- "./scripts/claude-code.sh" install --version "$invalid_version" 2>&1)

        assert_contains "Failed to install" "$install_output" "Error output should mention installation failure" ||
        assert_contains "Failed to download" "$install_output" "Error output should mention download failure" ||
        assert_contains "registry" "$install_output" "Error output should mention registry issues" ||
        assert_contains "package" "$install_output" "Error output should mention package issues"

        assert_directory_not_exists "$XDG_DATA_HOME/claude/versions/$invalid_version" "Version directory should not exist for failed installation"
        assert_file_not_exists "$sandbox_dir/.local/bin/claude" "Wrapper script should not exist after failed installation"
        assert_directory_not_exists "$XDG_DATA_HOME/claude/current" "Current symlink should not exist after failed installation"

        local bash_profile_content=$(cat "$sandbox_dir/.bash_profile" 2>/dev/null || echo "")
        # XDG PATH config may exist after failed installation (since it's added early and shared by other apps)
        # Only Claude Code specific config should not exist
        assert_not_contains "claude-code start" "$bash_profile_content" "No Claude Code config should exist after failed installation"
    )
}

# Register all test functions
register_tests \
    "test_install_basic_functionality" \
    "test_install_idempotency" \
    "test_install_shell_configuration" \
    "test_install_with_shell_parameter_bash" \
    "test_install_with_shell_parameter_zsh" \
    "test_install_with_shell_parameter_fish" \
    "test_install_multiple_versions" \
    "test_install_error_handling_invalid_version"

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests_with_args "Claude Code Installation Tests" "$@"
fi
