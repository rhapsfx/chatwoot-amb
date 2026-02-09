#!/bin/bash
# test-claude-code-use.sh - Tests "scripts/claude-code.sh use" functionality
# 
# Purpose: Test "scripts/claude-code.sh use" functionality for switching between installed Claude Code versions via symlink management
# Dependencies: test-claude-code-install.sh (for setup)
# Approach: Use shared installation optimization with multiple versions, test version switching with real installations

source "$(dirname "$0")/../utils/test-harness.sh"
source "$(dirname "$0")/claude-code-shared-installation-utils.sh"
source "$(dirname "$0")/../utils/file-utils.sh"

test_use_switches_to_installed_version() {
    # Tests --use <version> switches current version symlink to specified installed version
    # Validates symlink update and immediate availability of new version without wrapper script modification
    test_log "INFO" "Testing --use switches to installed version"
    
    (
        create_sandbox

        # Copy shared installation for pristine test environment
        copy_shared_claude_installation
        
        # Get the initial installed version from the shared installation
        local initial_version
        initial_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        test_log "INFO" "Initial installed version: $initial_version"
        
        # Create additional versions using optimized shared installation copying
        # This simulates having multiple versions installed
        local second_version="0.0.85"
        local third_version="0.0.87"
        
        copy_shared_claude_installation "$second_version"
        copy_shared_claude_installation "$third_version"
        
        # Verify we have multiple versions available for switching
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$initial_version" "Initial version should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$second_version" "Second version should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$third_version" "Third version should exist"
        
        # Check initial current version
        local initial_current_symlink=$(readlink "$XDG_DATA_HOME/claude/current")
        assert_contains "$initial_version" "$initial_current_symlink" "Initial current symlink should point to initial version"
        
        # Switch to version using --use command
        test_log "INFO" "Switching to version $second_version"
        "./scripts/claude-code.sh" use --version "$second_version" --yes
        
        # Verify the symlink was updated
        local new_current_symlink=$(readlink "$XDG_DATA_HOME/claude/current")
        assert_contains "$second_version" "$new_current_symlink" "Current symlink should point to $second_version after switch"
        
        # Verify wrapper script reflects the new version immediately
        local wrapper_version
        wrapper_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        assert_contains "$second_version" "$wrapper_version" "Wrapper script should return new version after switch"
        
        # Verify the wrapper script still works (functionality test)
        local check_result
        check_result=$("$sandbox_dir/.local/bin/claude" --check 2>&1)
        assert_contains "Claude wrapper checked successfully" "$check_result" "Wrapper script should remain functional after switch"
        
        # Test switching to a third version to verify bidirectional functionality
        test_log "INFO" "Switching to version $third_version"
        "./scripts/claude-code.sh" use --version "$third_version" --yes
        
        # Verify the symlink was updated to third version
        local final_current_symlink=$(readlink "$XDG_DATA_HOME/claude/current")
        assert_contains "$third_version" "$final_current_symlink" "Current symlink should point to $third_version"
        
        # Verify wrapper script reflects the final version
        local final_wrapper_version
        final_wrapper_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        assert_contains "$third_version" "$final_wrapper_version" "Wrapper script should return final version"
        
        test_log "SUCCESS" "Version switching with symlink updates verified successfully"
    )
}

test_use_validates_version_exists() {
    # Tests --use <version> validates target version is installed before switching
    # Validates error message when specified version doesn't exist locally
    test_log "INFO" "Testing --use validates version exists"
    
    (
        create_sandbox

        # Copy shared installation for pristine test environment
        copy_shared_claude_installation
        
        # Get the initial installed version
        local initial_version
        initial_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        test_log "INFO" "Initial installed version: $initial_version"
        
        # Verify initial state is working
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$initial_version" "Initial version should exist"
        assert_file_exists "$sandbox_dir/.local/bin/claude" "Claude wrapper script should exist"
        
        # Try to use a non-existent version
        local nonexistent_version="9.9.99"
        test_log "INFO" "Attempting to switch to non-existent version: $nonexistent_version"
        
        # Capture both stdout and stderr, and the exit code
        local use_output
        local use_exit_code=0
        use_output=$("./scripts/claude-code.sh" use --version "$nonexistent_version" --yes 2>&1) || use_exit_code=$?
        
        # Verify error handling
        test_log "INFO" "Verifying error handling for non-existent version"
        
        # Should exit with non-zero exit code
        if [[ $use_exit_code -eq 0 ]]; then
            test_log "ERROR" "Use command should have failed with non-zero exit code for non-existent version"
            test_log "ERROR" "Exit code was: $use_exit_code"
            test_log "ERROR" "Output was: $use_output"
            return 1
        fi
        
        # Should contain appropriate error messages
        assert_contains "Could not switch to version $nonexistent_version, because it is not installed" "$use_output" "Error output should mention version is not installed"
        assert_contains "[ERROR]" "$use_output" "Error output should contain [ERROR] tagged message"
        assert_contains "Installed versions:" "$use_output" "Error output should list available versions"
        assert_contains "To install additional versions, use:" "$use_output" "Error output should suggest installation"
        
        # Should not contain success messages
        assert_not_contains "Successfully switched to version" "$use_output" "Error case should not show successful switch messages"
        
        # Verify that current installation is preserved (no damage done)
        test_log "INFO" "Verifying existing installation is preserved"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$initial_version" "Existing version should still exist after failed switch"
        assert_file_exists "$sandbox_dir/.local/bin/claude" "Claude wrapper script should still exist after failed switch"
        assert_symlink_exists "$XDG_DATA_HOME/claude/current" "Current symlink should still exist after failed switch"
        
        # Verify current version remains unchanged
        local current_version_after
        current_version_after=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        if [[ "$current_version_after" != "$initial_version" ]]; then
            test_log "ERROR" "Current version should remain unchanged after failed switch. Expected: $initial_version, Got: $current_version_after"
            return 1
        fi
        
        # Verify the wrapper is still functional
        local check_result
        check_result=$("$sandbox_dir/.local/bin/claude" --check 2>&1)
        assert_contains "Claude wrapper checked successfully" "$check_result" "Wrapper script should remain functional after failed switch"
        
        test_log "SUCCESS" "Version existence validation test completed successfully"
    )
}

test_use_preserves_other_versions() {
    # Tests version switching never affects other installed versions or their directory contents
    # Validates complete version isolation during switching operations
    test_log "INFO" "Testing --use preserves other versions"
    
    (
        create_sandbox

        # Copy shared installation for pristine test environment
        copy_shared_claude_installation
        
        # Get the initial installed version
        local initial_version
        initial_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        test_log "INFO" "Initial installed version: $initial_version"
        
        # Create additional versions using optimized shared installation copying
        local second_version="0.0.85"
        local third_version="0.0.87"
        
        copy_shared_claude_installation "$second_version"
        copy_shared_claude_installation "$third_version"
        
        # Add unique content to each version to verify they remain unchanged
        echo "test-marker-initial-$initial_version" > "$XDG_DATA_HOME/claude/versions/$initial_version/test-marker.txt"
        echo "test-marker-second-$second_version" > "$XDG_DATA_HOME/claude/versions/$second_version/test-marker.txt"
        echo "test-marker-third-$third_version" > "$XDG_DATA_HOME/claude/versions/$third_version/test-marker.txt"
        
        # Calculate checksums of all version directories before switching
        test_log "INFO" "Calculating checksums before version switching"
        local initial_checksum=$(calculate_directory_checksum "$XDG_DATA_HOME/claude/versions/$initial_version" "*")
        local second_checksum=$(calculate_directory_checksum "$XDG_DATA_HOME/claude/versions/$second_version" "*")
        local third_checksum=$(calculate_directory_checksum "$XDG_DATA_HOME/claude/versions/$third_version" "*")
        
        # Verify all versions exist and are different
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$initial_version" "Initial version should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$second_version" "Second version should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$third_version" "Third version should exist"
        
        # Switch to second version
        test_log "INFO" "Switching to version $second_version"
        "./scripts/claude-code.sh" use --version "$second_version" --yes
        
        # Verify current version changed
        local current_version_after_first_switch
        current_version_after_first_switch=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        assert_contains "$second_version" "$current_version_after_first_switch" "Current version should be $second_version"
        
        # Verify all other versions remain completely unchanged
        test_log "INFO" "Verifying other versions remain unchanged after first switch"
        local initial_checksum_after=$(calculate_directory_checksum "$XDG_DATA_HOME/claude/versions/$initial_version" "*")
        local third_checksum_after=$(calculate_directory_checksum "$XDG_DATA_HOME/claude/versions/$third_version" "*")
        
        if [[ "$initial_checksum" != "$initial_checksum_after" ]]; then
            test_log "ERROR" "Initial version directory was modified during switch operation"
            return 1
        fi
        
        if [[ "$third_checksum" != "$third_checksum_after" ]]; then
            test_log "ERROR" "Third version directory was modified during switch operation"
            return 1
        fi
        
        # Verify unique markers are still present
        assert_contains "test-marker-initial-$initial_version" "$(cat "$XDG_DATA_HOME/claude/versions/$initial_version/test-marker.txt")" "Initial version marker should be preserved"
        assert_contains "test-marker-third-$third_version" "$(cat "$XDG_DATA_HOME/claude/versions/$third_version/test-marker.txt")" "Third version marker should be preserved"
        
        # Switch to third version
        test_log "INFO" "Switching to version $third_version"
        "./scripts/claude-code.sh" use --version "$third_version" --yes
        
        # Verify current version changed again
        local current_version_after_second_switch
        current_version_after_second_switch=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        assert_contains "$third_version" "$current_version_after_second_switch" "Current version should be $third_version"
        
        # Verify all other versions remain completely unchanged after second switch
        test_log "INFO" "Verifying other versions remain unchanged after second switch"
        local initial_checksum_after_second=$(calculate_directory_checksum "$XDG_DATA_HOME/claude/versions/$initial_version" "*")
        local second_checksum_after_second=$(calculate_directory_checksum "$XDG_DATA_HOME/claude/versions/$second_version" "*")
        
        if [[ "$initial_checksum" != "$initial_checksum_after_second" ]]; then
            test_log "ERROR" "Initial version directory was modified during second switch operation"
            return 1
        fi
        
        if [[ "$second_checksum" != "$second_checksum_after_second" ]]; then
            test_log "ERROR" "Second version directory was modified during second switch operation"
            return 1
        fi
        
        # Verify unique markers are still present after multiple switches
        assert_contains "test-marker-initial-$initial_version" "$(cat "$XDG_DATA_HOME/claude/versions/$initial_version/test-marker.txt")" "Initial version marker should be preserved after multiple switches"
        assert_contains "test-marker-second-$second_version" "$(cat "$XDG_DATA_HOME/claude/versions/$second_version/test-marker.txt")" "Second version marker should be preserved after multiple switches"
        
        # Verify all versions are still functional (directory structure intact)
        for version in "$initial_version" "$second_version" "$third_version"; do
            assert_directory_exists "$XDG_DATA_HOME/claude/versions/$version/nodejs" "Node.js directory should exist for version $version"
            assert_file_exists "$XDG_DATA_HOME/claude/versions/$version/nodejs/bin/claude" "Claude binary should exist for version $version"
        done
        
        test_log "SUCCESS" "Version isolation verified - other versions remain completely unchanged"
    )
}

test_use_updates_current_symlink_atomically() {
    # Tests symlink update is atomic and doesn't leave system in broken state
    # Validates symlink creation uses temporary file approach for atomicity
    test_log "INFO" "Testing --use updates current symlink atomically"
    
    (
        create_sandbox

        # Copy shared installation for pristine test environment
        copy_shared_claude_installation
        
        # Get the initial installed version from the shared installation
        local initial_version
        initial_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        test_log "INFO" "Initial installed version: $initial_version"
        
        # Create additional versions using optimized shared installation copying
        local second_version="0.0.85"
        local third_version="0.0.87"
        
        copy_shared_claude_installation "$second_version"
        copy_shared_claude_installation "$third_version"
        
        # Verify we have multiple versions available for switching
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$initial_version" "Initial version should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$second_version" "Second version should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$third_version" "Third version should exist"
        
        # Test atomicity by monitoring symlink state during operation
        test_log "INFO" "Testing atomic symlink update behavior"
        
        # Check initial current version
        local initial_current_symlink=$(readlink "$XDG_DATA_HOME/claude/current")
        assert_contains "$initial_version" "$initial_current_symlink" "Initial current symlink should point to initial version"
        
        # Verify the symlink is valid (points to existing directory)
        assert_symlink_exists "$XDG_DATA_HOME/claude/current" "Current symlink should exist before switch"
        assert_directory_exists "$XDG_DATA_HOME/claude/current" "Current symlink should point to valid directory before switch"
        
        # Capture the initial state for verification
        local initial_wrapper_version
        initial_wrapper_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        assert_contains "$initial_version" "$initial_wrapper_version" "Initial wrapper should return initial version"
        
        # Switch to second version and monitor atomicity
        test_log "INFO" "Switching to version $second_version and verifying atomicity"
        "./scripts/claude-code.sh" use --version "$second_version" --yes
        
        # Verify the symlink was updated atomically (no broken state)
        test_log "INFO" "Verifying symlink is in valid state after atomic update"
        
        # The symlink should exist and be valid immediately after the operation
        assert_symlink_exists "$XDG_DATA_HOME/claude/current" "Current symlink should exist after atomic update"
        assert_directory_exists "$XDG_DATA_HOME/claude/current" "Current symlink should point to valid directory after atomic update"
        
        # Verify the symlink now points to the new version
        local new_current_symlink=$(readlink "$XDG_DATA_HOME/claude/current")
        assert_contains "$second_version" "$new_current_symlink" "Current symlink should point to $second_version after switch"
        
        # Verify wrapper script reflects the new version immediately (no broken intermediate state)
        local new_wrapper_version
        new_wrapper_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        assert_contains "$second_version" "$new_wrapper_version" "Wrapper script should return new version after atomic switch"
        
        # Verify the wrapper script is immediately functional (no broken state)
        local check_result
        check_result=$("$sandbox_dir/.local/bin/claude" --check 2>&1)
        assert_contains "Claude wrapper checked successfully" "$check_result" "Wrapper script should be functional immediately after atomic switch"
        
        # Test rapid consecutive switches to verify atomicity under stress
        test_log "INFO" "Testing atomicity under rapid consecutive switches"
        
        # Switch to third version
        "./scripts/claude-code.sh" use --version "$third_version" --yes
        
        # Verify immediate validity after second switch
        assert_symlink_exists "$XDG_DATA_HOME/claude/current" "Current symlink should exist after second switch"
        assert_directory_exists "$XDG_DATA_HOME/claude/current" "Current symlink should point to valid directory after second switch"
        
        local final_current_symlink=$(readlink "$XDG_DATA_HOME/claude/current")
        assert_contains "$third_version" "$final_current_symlink" "Current symlink should point to $third_version after second switch"
        
        # Switch back to initial version
        "./scripts/claude-code.sh" use --version "$initial_version" --yes
        
        # Verify final state is valid and atomic
        assert_symlink_exists "$XDG_DATA_HOME/claude/current" "Current symlink should exist after final switch"
        assert_directory_exists "$XDG_DATA_HOME/claude/current" "Current symlink should point to valid directory after final switch"
        
        local return_current_symlink=$(readlink "$XDG_DATA_HOME/claude/current")
        assert_contains "$initial_version" "$return_current_symlink" "Current symlink should point back to $initial_version"
        
        # Final functional verification - wrapper should work immediately
        local final_wrapper_version
        final_wrapper_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        assert_contains "$initial_version" "$final_wrapper_version" "Wrapper script should return initial version after atomic switch back"
        
        local final_check_result
        final_check_result=$("$sandbox_dir/.local/bin/claude" --check 2>&1)
        assert_contains "Claude wrapper checked successfully" "$final_check_result" "Wrapper script should remain functional after multiple atomic switches"
        
        # Verify no temporary symlink files are left behind
        test_log "INFO" "Verifying no temporary files left behind after atomic operations"
        local temp_files_count
        temp_files_count=$(find "$XDG_DATA_HOME/claude" -name "current.tmp.*" 2>/dev/null | wc -l)
        if [[ $temp_files_count -gt 0 ]]; then
            test_log "ERROR" "Found temporary symlink files after atomic operations:"
            find "$XDG_DATA_HOME/claude" -name "current.tmp.*" 2>/dev/null | while read -r temp_file; do
                test_log "ERROR" "  $temp_file"
            done
            return 1
        fi
        
        test_log "SUCCESS" "Atomic symlink update behavior verified successfully"
    )
}

test_use_maintains_wrapper_script_functionality() {
    # Tests version-agnostic wrapper script continues working after version switch without modification
    # Validates wrapper script dynamically follows updated current symlink
    test_log "INFO" "Testing --use maintains wrapper script functionality"
    
    (
        create_sandbox

        # Copy shared installation for pristine test environment
        copy_shared_claude_installation
        
        # Get the initial installed version from the shared installation
        local initial_version
        initial_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        test_log "INFO" "Initial installed version: $initial_version"
        
        # Create additional versions using optimized shared installation copying
        local second_version="0.0.85"
        local third_version="0.0.87"
        
        copy_shared_claude_installation "$second_version"
        copy_shared_claude_installation "$third_version"
        
        # Verify we have multiple versions available for switching
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$initial_version" "Initial version should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$second_version" "Second version should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$third_version" "Third version should exist"
        
        # Capture initial wrapper script content for consistency verification
        test_log "INFO" "Capturing wrapper script baseline"
        local wrapper_script="$sandbox_dir/.local/bin/claude"
        
        assert_file_exists "$wrapper_script" "Claude wrapper script should exist"
        assert_file_executable "$wrapper_script" "Claude wrapper script should be executable"
        
        # Get wrapper script content to verify it remains consistent (version-agnostic)
        local initial_wrapper_content=$(cat "$wrapper_script")
        test_log "INFO" "Captured initial wrapper script content for consistency verification"
        
        # Test initial wrapper functionality
        test_log "INFO" "Testing initial wrapper functionality"
        local initial_check_result
        initial_check_result=$("$wrapper_script" --check 2>&1)
        assert_contains "Claude wrapper checked successfully" "$initial_check_result" "Initial wrapper should be functional"
        
        local initial_version_result
        initial_version_result=$("$wrapper_script" --check-version 2>&1)
        assert_contains "$initial_version" "$initial_version_result" "Initial wrapper should return correct version"
        
        # Switch to second version
        test_log "INFO" "Switching to version $second_version and testing wrapper functionality"
        "./scripts/claude-code.sh" use --version "$second_version" --yes
        
        # Verify wrapper script content remains version-agnostic (same code, different execution path)
        test_log "INFO" "Verifying wrapper script content remains version-agnostic after version switch"
        local second_wrapper_content=$(cat "$wrapper_script")
        
        if [[ "$second_wrapper_content" != "$initial_wrapper_content" ]]; then
            test_log "ERROR" "Wrapper script content changed after version switch (should remain version-agnostic)"
            return 1
        fi
        
        # Verify wrapper still exists and is executable after recreation
        assert_file_exists "$wrapper_script" "Claude wrapper script should exist after version switch"
        assert_file_executable "$wrapper_script" "Claude wrapper script should be executable after version switch"
        
        # Test wrapper functionality after switch - should dynamically follow new version
        test_log "INFO" "Testing wrapper functionality after version switch"
        local second_check_result
        second_check_result=$("$wrapper_script" --check 2>&1)
        assert_contains "Claude wrapper checked successfully" "$second_check_result" "Wrapper should remain functional after version switch"
        
        local second_version_result
        second_version_result=$("$wrapper_script" --check-version 2>&1)
        assert_contains "$second_version" "$second_version_result" "Wrapper should dynamically return new version"
        
        # Switch to third version to test multiple switches
        test_log "INFO" "Switching to version $third_version and testing continued functionality"
        "./scripts/claude-code.sh" use --version "$third_version" --yes
        
        # Verify wrapper script content still consistent after multiple switches
        local third_wrapper_content=$(cat "$wrapper_script")
        if [[ "$third_wrapper_content" != "$initial_wrapper_content" ]]; then
            test_log "ERROR" "Wrapper script content changed after second version switch"
            return 1
        fi
        
        # Test wrapper functionality after second switch
        test_log "INFO" "Testing wrapper functionality after second version switch"
        local third_check_result
        third_check_result=$("$wrapper_script" --check 2>&1)
        assert_contains "Claude wrapper checked successfully" "$third_check_result" "Wrapper should remain functional after multiple switches"
        
        local third_version_result
        third_version_result=$("$wrapper_script" --check-version 2>&1)
        assert_contains "$third_version" "$third_version_result" "Wrapper should dynamically return third version"
        
        # Switch back to initial version to test full cycle
        test_log "INFO" "Switching back to initial version $initial_version to test full cycle"
        "./scripts/claude-code.sh" use --version "$initial_version" --yes
        
        # Final verification - wrapper content unchanged but functionality updated
        local final_wrapper_content=$(cat "$wrapper_script")
        if [[ "$final_wrapper_content" != "$initial_wrapper_content" ]]; then
            test_log "ERROR" "Wrapper script content changed after full cycle"
            return 1
        fi
        
        # Test final functionality - should be back to initial version
        local final_check_result
        final_check_result=$("$wrapper_script" --check 2>&1)
        assert_contains "Claude wrapper checked successfully" "$final_check_result" "Wrapper should remain functional after full cycle"
        
        local final_version_result
        final_version_result=$("$wrapper_script" --check-version 2>&1)
        assert_contains "$initial_version" "$final_version_result" "Wrapper should return initial version after full cycle"
        
        # Test version-agnostic behavior by verifying the wrapper works with all versions
        test_log "INFO" "Testing version-agnostic behavior with rapid switches"
        local versions=("$initial_version" "$second_version" "$third_version" "$initial_version")
        
        for test_version in "${versions[@]}"; do
            "./scripts/claude-code.sh" use --version "$test_version" --yes >/dev/null 2>&1
            
            # Verify wrapper immediately reflects the switch
            local test_version_result
            test_version_result=$("$wrapper_script" --check-version 2>&1)
            assert_contains "$test_version" "$test_version_result" "Wrapper should immediately reflect version $test_version"
            
            # Verify wrapper functionality
            local test_check_result
            test_check_result=$("$wrapper_script" --check 2>&1)
            assert_contains "Claude wrapper checked successfully" "$test_check_result" "Wrapper should be functional for version $test_version"
            
            # Verify wrapper content remains consistent (version-agnostic design)
            local current_wrapper_content=$(cat "$wrapper_script")
            if [[ "$current_wrapper_content" != "$initial_wrapper_content" ]]; then
                test_log "ERROR" "Wrapper script content changed during version switching to $test_version"
                return 1
            fi
        done
        
        test_log "SUCCESS" "Version-agnostic wrapper script functionality verified successfully"
    )
}

test_use_switches_from_any_current_version() {
    # Tests switching works regardless of which version is currently active
    # Validates switching between different version combinations
    test_log "INFO" "Testing --use switches from any current version"
    
    (
        create_sandbox

        # Copy shared installation for pristine test environment
        copy_shared_claude_installation
        
        # Get the initial installed version from the shared installation
        local initial_version
        initial_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        test_log "INFO" "Initial installed version: $initial_version"
        
        # Create additional versions using optimized shared installation copying
        local second_version="0.0.85"
        local third_version="0.0.87"
        local fourth_version="0.0.84"
        
        copy_shared_claude_installation "$second_version"
        copy_shared_claude_installation "$third_version"
        copy_shared_claude_installation "$fourth_version"
        
        # Verify we have multiple versions available for switching
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$initial_version" "Initial version should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$second_version" "Second version should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$third_version" "Third version should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$fourth_version" "Fourth version should exist"
        
        # Create array of versions for comprehensive testing
        local versions=("$initial_version" "$second_version" "$third_version" "$fourth_version")
        
        test_log "INFO" "Testing switching from each version to every other version"
        
        # Test switching from each version to every other version
        for from_version in "${versions[@]}"; do
            # First, switch to the "from" version to establish starting point
            test_log "INFO" "Setting up from version: $from_version"
            "./scripts/claude-code.sh" use --version "$from_version" --yes >/dev/null 2>&1
            
            # Verify we're at the expected starting version
            local current_before_switch
            current_before_switch=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
            assert_contains "$from_version" "$current_before_switch" "Should be starting from version $from_version"
            
            # Test switching to every other version from this starting point
            for to_version in "${versions[@]}"; do
                if [[ "$from_version" != "$to_version" ]]; then
                    test_log "INFO" "Testing switch from $from_version to $to_version"
                    
                    # Perform the switch
                    "./scripts/claude-code.sh" use --version "$to_version" --yes >/dev/null 2>&1
                    local switch_exit_code=$?
                    
                    # Verify successful switch
                    if [[ $switch_exit_code -ne 0 ]]; then
                        test_log "ERROR" "Switch from $from_version to $to_version failed with exit code: $switch_exit_code"
                        return 1
                    fi
                    
                    # Verify we're now at the target version
                    local current_after_switch
                    current_after_switch=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
                    assert_contains "$to_version" "$current_after_switch" "Should have switched from $from_version to $to_version"
                    
                    # Verify wrapper functionality after switch
                    local check_result
                    check_result=$("$sandbox_dir/.local/bin/claude" --check 2>&1)
                    assert_contains "Claude wrapper checked successfully" "$check_result" "Wrapper should be functional after switch from $from_version to $to_version"
                    
                    # Verify symlink points to correct version
                    local symlink_target=$(readlink "$XDG_DATA_HOME/claude/current")
                    assert_contains "$to_version" "$symlink_target" "Current symlink should point to $to_version after switch"
                fi
            done
        done
        
        # Test rapid consecutive switches from a single starting point
        test_log "INFO" "Testing rapid consecutive switches from single starting point"
        
        # Start from initial version
        "./scripts/claude-code.sh" use --version "$initial_version" --yes >/dev/null 2>&1
        local consecutive_start_version
        consecutive_start_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        assert_contains "$initial_version" "$consecutive_start_version" "Should start consecutive test from initial version"
        
        # Rapidly switch through all versions in sequence
        local switch_sequence=("$second_version" "$fourth_version" "$third_version" "$initial_version" "$second_version")
        
        for target_version in "${switch_sequence[@]}"; do
            test_log "INFO" "Consecutive switch to $target_version"
            
            "./scripts/claude-code.sh" use --version "$target_version" --yes >/dev/null 2>&1
            local consecutive_exit_code=$?
            
            # Verify successful switch
            if [[ $consecutive_exit_code -ne 0 ]]; then
                test_log "ERROR" "Consecutive switch to $target_version failed with exit code: $consecutive_exit_code"
                return 1
            fi
            
            # Verify we're at the correct version
            local consecutive_current_version
            consecutive_current_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
            assert_contains "$target_version" "$consecutive_current_version" "Should be at $target_version after consecutive switch"
            
            # Verify functionality is maintained
            local consecutive_check_result
            consecutive_check_result=$("$sandbox_dir/.local/bin/claude" --check 2>&1)
            assert_contains "Claude wrapper checked successfully" "$consecutive_check_result" "Wrapper should remain functional during consecutive switches"
        done
        
        # Test switching with mixed success and idempotent operations
        test_log "INFO" "Testing mixed success and idempotent operations"
        
        # Set to known version
        "./scripts/claude-code.sh" use --version "$third_version" --yes >/dev/null 2>&1
        
        # Test idempotent switch (same version)
        local idempotent_output
        idempotent_output=$("./scripts/claude-code.sh" use --version "$third_version" --yes 2>&1)
        local idempotent_exit_code=$?
        
        # Should succeed
        if [[ $idempotent_exit_code -ne 0 ]]; then
            test_log "ERROR" "Idempotent switch should succeed. Exit code: $idempotent_exit_code"
            return 1
        fi
        
        # Should show idempotent messaging
        assert_contains "Version $third_version is already the current version" "$idempotent_output" "Should show idempotent message"
        
        # Should still be at same version
        local post_idempotent_version
        post_idempotent_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        assert_contains "$third_version" "$post_idempotent_version" "Should remain at $third_version after idempotent switch"
        
        # Test regular switch after idempotent operation
        "./scripts/claude-code.sh" use --version "$fourth_version" --yes >/dev/null 2>&1
        local post_idempotent_switch_version
        post_idempotent_switch_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        assert_contains "$fourth_version" "$post_idempotent_switch_version" "Should switch normally after idempotent operation"
        
        # Final verification - ensure no versions were corrupted during switching
        test_log "INFO" "Final verification - ensuring all versions remain functional"
        
        for version in "${versions[@]}"; do
            # Switch to each version
            "./scripts/claude-code.sh" use --version "$version" --yes >/dev/null 2>&1
            
            # Verify functionality
            local final_check_result
            final_check_result=$("$sandbox_dir/.local/bin/claude" --check 2>&1)
            assert_contains "Claude wrapper checked successfully" "$final_check_result" "Version $version should remain functional after comprehensive switching tests"
            
            # Verify version reporting
            local final_version_check
            final_version_check=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
            assert_contains "$version" "$final_version_check" "Version $version should report correctly after comprehensive switching tests"
        done
        
        test_log "SUCCESS" "Version switching from any current version verified successfully"
    )
}

test_use_version_verification_after_switch() {
    # Tests claude --check-version returns correct version after successful switch
    # Validates wrapper script reflects new current version immediately
    test_log "INFO" "Testing --check-version returns correct version after switch"
    
    (
        create_sandbox

        # Copy shared installation for pristine test environment
        copy_shared_claude_installation
        
        # Get the initial installed version from the shared installation
        local initial_version
        initial_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        test_log "INFO" "Initial installed version: $initial_version"
        
        # Create additional versions using optimized shared installation copying
        local second_version="0.0.85"
        local third_version="0.0.87"
        
        copy_shared_claude_installation "$second_version"
        copy_shared_claude_installation "$third_version"
        
        # Verify we have multiple versions available for switching
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$initial_version" "Initial version should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$second_version" "Second version should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$third_version" "Third version should exist"
        
        # Verify initial version verification
        test_log "INFO" "Verifying initial version verification"
        local initial_check_version
        initial_check_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        assert_contains "$initial_version" "$initial_check_version" "Initial --check-version should return correct version"
        
        # Switch to second version and verify immediate version verification
        test_log "INFO" "Switching to version $second_version and verifying immediate version reporting"
        "./scripts/claude-code.sh" use --version "$second_version" --yes >/dev/null 2>&1
        
        # Verify version verification immediately after switch
        local second_check_version
        second_check_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        assert_contains "$second_version" "$second_check_version" "After switch to $second_version, --check-version should return correct version"
        
        # Verify the version change actually occurred
        if [[ "$second_check_version" == "$initial_check_version" ]]; then
            test_log "ERROR" "Version should have changed from $initial_version to $second_version"
            return 1
        fi
        
        # Switch to third version and verify immediate version verification
        test_log "INFO" "Switching to version $third_version and verifying immediate version reporting"
        "./scripts/claude-code.sh" use --version "$third_version" --yes >/dev/null 2>&1
        
        # Verify version verification immediately after second switch
        local third_check_version
        third_check_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        assert_contains "$third_version" "$third_check_version" "After switch to $third_version, --check-version should return correct version"
        
        # Verify the version change occurred from second to third
        if [[ "$third_check_version" == "$second_check_version" ]]; then
            test_log "ERROR" "Version should have changed from $second_version to $third_version"
            return 1
        fi
        
        # Switch back to initial version and verify version verification
        test_log "INFO" "Switching back to initial version $initial_version and verifying version reporting"
        "./scripts/claude-code.sh" use --version "$initial_version" --yes >/dev/null 2>&1
        
        # Verify version verification after return switch
        local return_check_version
        return_check_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        assert_contains "$initial_version" "$return_check_version" "After switch back to $initial_version, --check-version should return correct version"
        
        # Verify we're back to the original version
        if [[ "$return_check_version" != "$initial_check_version" ]]; then
            test_log "ERROR" "Return switch should restore original version: expected $initial_check_version, got $return_check_version"
            return 1
        fi
        
        # Test rapid consecutive switches and verify version reporting accuracy
        test_log "INFO" "Testing rapid consecutive switches with version verification"
        local rapid_versions=("$second_version" "$third_version" "$initial_version" "$second_version")
        
        for target_version in "${rapid_versions[@]}"; do
            test_log "INFO" "Rapid switch to $target_version"
            
            # Perform the switch
            "./scripts/claude-code.sh" use --version "$target_version" --yes >/dev/null 2>&1
            
            # Verify version verification immediately after switch
            local rapid_check_version
            rapid_check_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
            assert_contains "$target_version" "$rapid_check_version" "After rapid switch to $target_version, --check-version should return correct version"
            
            # Also verify the wrapper is functional
            local rapid_check_result
            rapid_check_result=$("$sandbox_dir/.local/bin/claude" --check 2>&1)
            assert_contains "Claude wrapper checked successfully" "$rapid_check_result" "Wrapper should be functional after rapid switch to $target_version"
        done
        
        # Test version verification consistency (multiple calls should return same result)
        test_log "INFO" "Testing version verification consistency"
        local consistency_version
        consistency_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        
        # Call --check-version multiple times and verify consistency
        for i in {1..5}; do
            local repeated_check_version
            repeated_check_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
            if [[ "$repeated_check_version" != "$consistency_version" ]]; then
                test_log "ERROR" "Version verification should be consistent. Call $i returned different result: expected $consistency_version, got $repeated_check_version"
                return 1
            fi
        done
        
        # Verify version verification works with different call patterns
        test_log "INFO" "Testing version verification with different call patterns"
        
        # Test with explicit path
        local explicit_path_version
        explicit_path_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        
        # Test via PATH lookup (assuming our fake shell setup works)
        local path_lookup_version
        path_lookup_version=$(claude --check-version 2>&1)
        
        # Both should return the same version
        if [[ "$explicit_path_version" != "$path_lookup_version" ]]; then
            test_log "ERROR" "Version verification should be consistent regardless of call method"
            test_log "ERROR" "Explicit path: $explicit_path_version"
            test_log "ERROR" "PATH lookup: $path_lookup_version"
            return 1
        fi
        
        test_log "SUCCESS" "Version verification after switch tested successfully"
    )
}

test_use_when_target_version_already_current() {
    # Tests --use <version> behavior when specified version is already the current/default version
    # Validates idempotent behavior with appropriate messaging and no system changes
    test_log "INFO" "Testing --use when target version already current"
    
    (
        create_sandbox

        # Copy shared installation for pristine test environment
        copy_shared_claude_installation
        
        # Get the initial installed version (this will be our current version)
        local current_version
        current_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        test_log "INFO" "Current version: $current_version"
        
        # Verify initial state
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$current_version" "Current version directory should exist"
        assert_file_exists "$sandbox_dir/.local/bin/claude" "Claude wrapper script should exist"
        
        # Create some additional versions using optimized shared installation copying to ensure we're testing a real scenario
        local additional_version="0.0.85"
        copy_shared_claude_installation "$additional_version"
        
        # Record system state before the idempotent operation
        test_log "INFO" "Recording system state before idempotent --use operation"
        local current_symlink_before=$(readlink "$XDG_DATA_HOME/claude/current")
        local wrapper_checksum_before=$(md5 -q "$sandbox_dir/.local/bin/claude")
        local version_dir_checksum_before=$(calculate_directory_checksum "$XDG_DATA_HOME/claude/versions/$current_version" "*")
        
        # Test idempotent use command - switch to the same version that's already current
        test_log "INFO" "Attempting to switch to already-current version: $current_version"
        local use_output
        use_output=$("./scripts/claude-code.sh" use --version "$current_version" --yes 2>&1)
        local use_exit_code=$?
        
        # Verify successful exit (idempotent operations should succeed)
        if [[ $use_exit_code -ne 0 ]]; then
            test_log "ERROR" "Use command should succeed for idempotent operation. Exit code: $use_exit_code"
            test_log "ERROR" "Output: $use_output"
            return 1
        fi
        
        # Verify appropriate messaging indicating no action was needed
        test_log "INFO" "Verifying idempotent operation messaging"
        assert_contains "Version $current_version is already the current version" "$use_output" "Output should indicate version is already current"
        assert_contains "No changes needed" "$use_output" "Output should indicate no changes needed"
        
        # Should not contain unnecessary switching messages
        assert_not_contains "Updated current symlink to point to" "$use_output" "Should not show symlink update for idempotent operation"
        
        # Verify system state remains completely unchanged
        test_log "INFO" "Verifying system state remains unchanged after idempotent operation"
        
        # Current version should remain the same
        local current_version_after
        current_version_after=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        if [[ "$current_version_after" != "$current_version" ]]; then
            test_log "ERROR" "Current version should remain unchanged after idempotent operation. Expected: $current_version, Got: $current_version_after"
            return 1
        fi
        
        # Symlink should remain unchanged
        local current_symlink_after=$(readlink "$XDG_DATA_HOME/claude/current")
        if [[ "$current_symlink_after" != "$current_symlink_before" ]]; then
            test_log "ERROR" "Current symlink should remain unchanged after idempotent operation"
            test_log "ERROR" "Before: $current_symlink_before"
            test_log "ERROR" "After: $current_symlink_after"
            return 1
        fi
        
        # Wrapper script should remain unchanged
        local wrapper_checksum_after=$(md5 -q "$sandbox_dir/.local/bin/claude")
        if [[ "$wrapper_checksum_after" != "$wrapper_checksum_before" ]]; then
            test_log "ERROR" "Wrapper script should remain unchanged after idempotent operation"
            return 1
        fi
        
        # Version directory should remain unchanged
        local version_dir_checksum_after=$(calculate_directory_checksum "$XDG_DATA_HOME/claude/versions/$current_version" "*")
        if [[ "$version_dir_checksum_after" != "$version_dir_checksum_before" ]]; then
            test_log "ERROR" "Version directory should remain unchanged after idempotent operation"
            return 1
        fi
        
        # Verify wrapper script functionality remains intact
        local check_result
        check_result=$("$sandbox_dir/.local/bin/claude" --check 2>&1)
        assert_contains "Claude wrapper checked successfully" "$check_result" "Wrapper script should remain functional after idempotent operation"
        
        # Test multiple idempotent calls to ensure consistency
        test_log "INFO" "Testing multiple idempotent operations for consistency"
        for i in {1..3}; do
            test_log "INFO" "Idempotent operation $i/3"
            local repeat_output
            repeat_output=$("./scripts/claude-code.sh" use --version "$current_version" --yes 2>&1)
            local repeat_exit_code=$?
            
            if [[ $repeat_exit_code -ne 0 ]]; then
                test_log "ERROR" "Repeated idempotent operation $i should succeed. Exit code: $repeat_exit_code"
                return 1
            fi
            
            assert_contains "Version $current_version is already the current version" "$repeat_output" "Repeated operation $i should show appropriate messaging"
            
            # Verify version remains unchanged
            local repeat_current_version
            repeat_current_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
            if [[ "$repeat_current_version" != "$current_version" ]]; then
                test_log "ERROR" "Version should remain unchanged after repeated idempotent operation $i"
                return 1
            fi
        done
        
        test_log "SUCCESS" "Idempotent version switching behavior verified successfully"
    )
}

test_use_error_handling_permission_issues() {
    # Tests switching behavior during filesystem permission errors on symlink operations
    # Validates graceful error handling and rollback
    test_log "INFO" "Testing --use error handling during permission issues"
    
    (
        create_sandbox

        # Copy shared installation for pristine test environment
        copy_shared_claude_installation
        
        # Get the initial installed version from the shared installation
        local initial_version
        initial_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        test_log "INFO" "Initial installed version: $initial_version"
        
        # Create additional version using optimized shared installation copying
        local second_version="0.0.85"
        
        copy_shared_claude_installation "$second_version"
        
        # Verify we have multiple versions available for switching
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$initial_version" "Initial version should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$second_version" "Second version should exist"
        
        # Test Case 1: Permission error on claude data directory (preventing symlink operations)
        test_log "INFO" "Test Case 1: Testing permission error on claude data directory"
        
        # Capture initial system state
        local initial_current_version
        initial_current_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        local initial_wrapper_checksum=$(md5 -q "$sandbox_dir/.local/bin/claude")
        
        # Make the claude data directory read-only (this prevents symlink creation/modification)
        test_log "INFO" "Setting read-only permissions on claude data directory"
        chmod 444 "$XDG_DATA_HOME/claude"
        
        # Try to switch version with permission restrictions
        test_log "INFO" "Attempting version switch with permission restrictions"
        local use_output
        local use_exit_code=0
        use_output=$("./scripts/claude-code.sh" use --version "$second_version" --yes 2>&1) || use_exit_code=$?
        
        # Restore permissions immediately for cleanup
        test_log "INFO" "Restoring permissions for cleanup"
        chmod 755 "$XDG_DATA_HOME/claude" 2>/dev/null || true
        
        # Verify error handling
        test_log "INFO" "Verifying error handling for permission issues"
        
        # Should exit with non-zero exit code
        if [[ $use_exit_code -eq 0 ]]; then
            test_log "ERROR" "Use command should have failed due to permission issues. Exit code: $use_exit_code"
            test_log "ERROR" "Output: $use_output"
            return 1
        fi
        
        # Should contain appropriate error indication
        assert_contains "[ERROR]" "$use_output" "Error output should contain [ERROR] tagged message"
        
        # Should not contain success messages
        assert_not_contains "Successfully switched to version" "$use_output" "Error case should not show success messages"
        
        # Verify current system state is preserved (no partial changes)
        test_log "INFO" "Verifying system state preservation after permission failure"
        
        # Current version should remain unchanged
        local post_error_version
        post_error_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        if [[ "$post_error_version" != "$initial_current_version" ]]; then
            test_log "ERROR" "Current version should remain unchanged after permission failure"
            test_log "ERROR" "Expected: $initial_current_version, Got: $post_error_version"
            return 1
        fi
        
        # Wrapper script should remain unchanged
        local post_error_wrapper_checksum=$(md5 -q "$sandbox_dir/.local/bin/claude")
        if [[ "$post_error_wrapper_checksum" != "$initial_wrapper_checksum" ]]; then
            test_log "ERROR" "Wrapper script should remain unchanged after permission failure"
            return 1
        fi
        
        # Verify wrapper functionality is preserved
        local check_result
        check_result=$("$sandbox_dir/.local/bin/claude" --check 2>&1)
        assert_contains "Claude wrapper checked successfully" "$check_result" "Wrapper should remain functional after permission failure"
        
        # Test Case 2: Permission error on wrapper script (preventing wrapper updates)
        test_log "INFO" "Test Case 2: Testing permission error on wrapper script"
        
        # Make the wrapper script read-only (this prevents wrapper script updates)
        test_log "INFO" "Setting read-only permissions on wrapper script"
        chmod 444 "$sandbox_dir/.local/bin/claude"
        
        # Try to switch version with wrapper script permission restrictions
        test_log "INFO" "Attempting version switch with wrapper script permission restrictions"
        local wrapper_use_output
        local wrapper_use_exit_code=0
        wrapper_use_output=$("./scripts/claude-code.sh" use --version "$second_version" --yes 2>&1) || wrapper_use_exit_code=$?
        
        # Restore permissions immediately for cleanup
        test_log "INFO" "Restoring wrapper script permissions for cleanup"
        chmod 755 "$sandbox_dir/.local/bin/claude" 2>/dev/null || true
        
        # This might succeed or fail depending on whether the wrapper script is actually recreated
        # The key is that the system should be in a consistent state regardless
        test_log "INFO" "Verifying system consistency after wrapper permission restrictions"
        
        # Current version should either be unchanged or correctly switched
        local post_wrapper_error_version
        post_wrapper_error_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        
        # The wrapper should be functional regardless of success/failure
        local wrapper_check_result
        wrapper_check_result=$("$sandbox_dir/.local/bin/claude" --check 2>&1)
        assert_contains "Claude wrapper checked successfully" "$wrapper_check_result" "Wrapper should be functional after wrapper permission restrictions"
        
        # Test Case 3: Permission error on version directory (preventing version validation)
        test_log "INFO" "Test Case 3: Testing permission error on target version directory"
        
        # First, ensure we're back to initial version before this test case
        test_log "INFO" "Resetting to initial version before testing version directory permissions"
        "./scripts/claude-code.sh" use --version "$initial_version" --yes >/dev/null 2>&1
        
        # Verify we're at the initial version
        local reset_version
        reset_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        if [[ "$reset_version" != "$initial_version" ]]; then
            test_log "ERROR" "Failed to reset to initial version. Expected: $initial_version, Got: $reset_version"
            return 1
        fi
        
        # Make the target version directory inaccessible (this prevents version validation)
        test_log "INFO" "Setting restrictive permissions on target version directory"
        chmod 000 "$XDG_DATA_HOME/claude/versions/$second_version"
        
        # Try to switch to the inaccessible version
        test_log "INFO" "Attempting version switch to inaccessible version directory"
        local version_dir_use_output
        local version_dir_use_exit_code=0
        version_dir_use_output=$("./scripts/claude-code.sh" use --version "$second_version" --yes 2>&1) || version_dir_use_exit_code=$?
        
        # Restore permissions immediately for cleanup
        test_log "INFO" "Restoring version directory permissions for cleanup"
        chmod -R 755 "$XDG_DATA_HOME/claude/versions/$second_version" 2>/dev/null || true
        
        # Should fail with error about version validation/corruption
        if [[ $version_dir_use_exit_code -eq 0 ]]; then
            test_log "ERROR" "Use command should have failed due to version directory access issues"
            test_log "ERROR" "Exit code: $version_dir_use_exit_code"
            test_log "ERROR" "Output: $version_dir_use_output"
            return 1
        fi
        
        # Should contain error about corrupted/inaccessible version
        assert_contains "[ERROR]" "$version_dir_use_output" "Error output should contain [ERROR] for version directory access issues"
        
        # Current system should remain in original state (initial version)
        local final_version
        final_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        if [[ "$final_version" != "$initial_version" ]]; then
            test_log "ERROR" "Current version should remain unchanged after version directory access failure"
            test_log "ERROR" "Expected: $initial_version, Got: $final_version"
            return 1
        fi
        
        # Test Case 4: Verify recovery after permission restoration
        test_log "INFO" "Test Case 4: Testing successful operation after permission restoration"
        
        # Now that all permissions are restored, the switch should work
        test_log "INFO" "Attempting version switch after permission restoration"
        "./scripts/claude-code.sh" use --version "$second_version" --yes >/dev/null 2>&1
        local recovery_exit_code=$?
        
        if [[ $recovery_exit_code -ne 0 ]]; then
            test_log "ERROR" "Version switch should succeed after permission restoration"
            return 1
        fi
        
        # Verify the switch worked correctly
        local recovery_version
        recovery_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        assert_contains "$second_version" "$recovery_version" "Version should switch correctly after permission restoration"
        
        # Verify functionality
        local recovery_check_result
        recovery_check_result=$("$sandbox_dir/.local/bin/claude" --check 2>&1)
        assert_contains "Claude wrapper checked successfully" "$recovery_check_result" "Wrapper should be functional after successful recovery"
        
        test_log "SUCCESS" "Permission issues error handling verified successfully"
    )
}

test_use_error_handling_corrupted_version() {
    # Tests switching behavior when target version installation is corrupted or incomplete
    # Validates version integrity checking before switch
    test_log "INFO" "Testing --use error handling for corrupted version installation"
    
    (
        create_sandbox

        # Copy shared installation for pristine test environment
        copy_shared_claude_installation
        
        # Get the initial installed version from the shared installation
        local initial_version
        initial_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        test_log "INFO" "Initial installed version: $initial_version"
        
        # Create additional version using optimized shared installation copying
        local second_version="0.0.85"
        
        copy_shared_claude_installation "$second_version"
        
        # Verify we have multiple versions available initially
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$initial_version" "Initial version should exist"
        assert_directory_exists "$XDG_DATA_HOME/claude/versions/$second_version" "Second version should exist"
        
        # Capture initial system state
        local initial_current_version
        initial_current_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        test_log "INFO" "Initial current version: $initial_current_version"
        
        # Test Case 1: Missing nodejs directory (corrupted installation)
        test_log "INFO" "Test Case 1: Testing corrupted version with missing nodejs directory"
        
        # Create a backup of the nodejs directory for later restoration
        local nodejs_backup_dir="$XDG_DATA_HOME/claude/versions/${second_version}_nodejs_backup"
        mv "$XDG_DATA_HOME/claude/versions/$second_version/nodejs" "$nodejs_backup_dir"
        
        # Try to switch to the corrupted version (missing nodejs directory)
        test_log "INFO" "Attempting to switch to version with missing nodejs directory"
        local missing_nodejs_output
        local missing_nodejs_exit_code=0
        missing_nodejs_output=$("./scripts/claude-code.sh" use --version "$second_version" --yes 2>&1) || missing_nodejs_exit_code=$?
        
        # Should fail with appropriate error
        if [[ $missing_nodejs_exit_code -eq 0 ]]; then
            test_log "ERROR" "Use command should have failed due to missing nodejs directory"
            test_log "ERROR" "Exit code: $missing_nodejs_exit_code"
            test_log "ERROR" "Output: $missing_nodejs_output"
            return 1
        fi
        
        # Verify error messages
        assert_contains "[ERROR]" "$missing_nodejs_output" "Error output should contain [ERROR] for missing nodejs directory"
        assert_contains "Version $second_version installation appears corrupted" "$missing_nodejs_output" "Should mention version corruption"
        assert_contains "missing nodejs directory" "$missing_nodejs_output" "Should specifically mention missing nodejs directory"
        assert_contains "Reinstall version with:" "$missing_nodejs_output" "Should suggest reinstallation"
        
        # Should not contain success messages
        assert_not_contains "Successfully switched to version" "$missing_nodejs_output" "Corrupted version should not show success"
        
        # Verify current system remains unchanged
        local post_missing_nodejs_version
        post_missing_nodejs_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        if [[ "$post_missing_nodejs_version" != "$initial_current_version" ]]; then
            test_log "ERROR" "Current version should remain unchanged after corrupted version switch attempt"
            test_log "ERROR" "Expected: $initial_current_version, Got: $post_missing_nodejs_version"
            return 1
        fi
        
        # Restore nodejs directory for next test
        test_log "INFO" "Restoring nodejs directory for next test case"
        mv "$nodejs_backup_dir" "$XDG_DATA_HOME/claude/versions/$second_version/nodejs"
        
        # Test Case 2: Missing claude binary (partially corrupted installation)  
        test_log "INFO" "Test Case 2: Testing corrupted version with missing claude binary"
        
        # Create a backup of the claude binary
        local claude_binary="$XDG_DATA_HOME/claude/versions/$second_version/nodejs/bin/claude"
        local claude_backup="${claude_binary}_backup"
        mv "$claude_binary" "$claude_backup"
        
        # Try to switch to the version with missing claude binary
        test_log "INFO" "Attempting to switch to version with missing claude binary"
        local missing_binary_output
        local missing_binary_exit_code=0
        missing_binary_output=$("./scripts/claude-code.sh" use --version "$second_version" --yes 2>&1) || missing_binary_exit_code=$?
        
        # Should fail with appropriate error
        if [[ $missing_binary_exit_code -eq 0 ]]; then
            test_log "ERROR" "Use command should have failed due to missing claude binary"
            test_log "ERROR" "Exit code: $missing_binary_exit_code"
            test_log "ERROR" "Output: $missing_binary_output"
            return 1
        fi
        
        # Verify error messages
        assert_contains "[ERROR]" "$missing_binary_output" "Error output should contain [ERROR] for missing claude binary"
        assert_contains "Version $second_version installation appears corrupted" "$missing_binary_output" "Should mention version corruption"
        assert_contains "missing claude binary" "$missing_binary_output" "Should specifically mention missing claude binary"
        assert_contains "Reinstall version with:" "$missing_binary_output" "Should suggest reinstallation"
        
        # Should not contain success messages
        assert_not_contains "Successfully switched to version" "$missing_binary_output" "Corrupted version should not show success"
        
        # Verify current system remains unchanged
        local post_missing_binary_version
        post_missing_binary_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        if [[ "$post_missing_binary_version" != "$initial_current_version" ]]; then
            test_log "ERROR" "Current version should remain unchanged after missing binary switch attempt"
            test_log "ERROR" "Expected: $initial_current_version, Got: $post_missing_binary_version"
            return 1
        fi
        
        # Restore claude binary for next test
        test_log "INFO" "Restoring claude binary for next test case"
        mv "$claude_backup" "$claude_binary"
        
        # Test Case 3: Corrupted nodejs directory (invalid content)
        test_log "INFO" "Test Case 3: Testing corrupted version with invalid nodejs directory content"
        
        # Create backup of entire nodejs directory
        local nodejs_dir="$XDG_DATA_HOME/claude/versions/$second_version/nodejs"
        local nodejs_full_backup="${nodejs_dir}_full_backup"
        mv "$nodejs_dir" "$nodejs_full_backup"
        
        # Create a fake nodejs directory with invalid content
        mkdir -p "$nodejs_dir/bin"
        echo "fake content" > "$nodejs_dir/bin/claude"
        # Don't make it executable to simulate corruption
        
        # Try to switch to the version with corrupted nodejs directory
        test_log "INFO" "Attempting to switch to version with corrupted nodejs directory content"
        local corrupted_content_output
        local corrupted_content_exit_code=0
        corrupted_content_output=$("./scripts/claude-code.sh" use --version "$second_version" --yes 2>&1) || corrupted_content_exit_code=$?
        
        # This may succeed or fail depending on how thorough the validation is
        # The key is that if it succeeds, the switch should not break the system
        
        # Verify current version state
        local post_corrupted_version
        post_corrupted_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        
        # If the switch succeeded, verify the system is still functional
        if [[ $corrupted_content_exit_code -eq 0 ]]; then
            test_log "INFO" "Switch to corrupted version succeeded, verifying system functionality"
            
            # The current wrapper should still be functional even if it points to corrupted version
            # (This tests the robustness of the version switching)
            local wrapper_check
            wrapper_check=$("$sandbox_dir/.local/bin/claude" --check 2>&1) || true
            
            # It's okay if the wrapper check fails here since the version is corrupted
            # The important thing is that the switch operation didn't break the system
            test_log "INFO" "Wrapper functionality after corrupted version switch: $wrapper_check"
        else
            # If it failed, verify it's a proper error with the system preserved
            test_log "INFO" "Switch to corrupted version failed as expected"
            assert_contains "[ERROR]" "$corrupted_content_output" "Error should be reported for corrupted content"
            
            # Current version should remain unchanged
            if [[ "$post_corrupted_version" != "$initial_current_version" ]]; then
                test_log "ERROR" "Current version should remain unchanged after corrupted content switch failure"
                return 1
            fi
        fi
        
        # Restore the original nodejs directory
        test_log "INFO" "Restoring original nodejs directory"
        rm -rf "$nodejs_dir"
        mv "$nodejs_full_backup" "$nodejs_dir"
        
        # Test Case 4: Recovery after fixing corruption
        test_log "INFO" "Test Case 4: Testing successful switch after fixing corruption"
        
        # Verify the version is now working correctly
        "./scripts/claude-code.sh" use --version "$second_version" --yes >/dev/null 2>&1
        local recovery_exit_code=$?
        
        if [[ $recovery_exit_code -ne 0 ]]; then
            test_log "ERROR" "Version switch should succeed after fixing corruption"
            return 1
        fi
        
        # Verify the switch worked correctly
        local recovery_version
        recovery_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
        assert_contains "$second_version" "$recovery_version" "Should switch to fixed version correctly"
        
        # Verify functionality
        local recovery_check_result
        recovery_check_result=$("$sandbox_dir/.local/bin/claude" --check 2>&1)
        assert_contains "Claude wrapper checked successfully" "$recovery_check_result" "Wrapper should be functional after recovery"
        
        # Test Case 5: Verify integrity checking is comprehensive
        test_log "INFO" "Test Case 5: Testing comprehensive integrity checking"
        
        # Switch back to initial version for clean state
        "./scripts/claude-code.sh" use --version "$initial_version" --yes >/dev/null 2>&1
        
        # Create a version directory that appears valid but has subtle corruption
        local third_version="0.0.84"
        mkdir -p "$XDG_DATA_HOME/claude/versions/$third_version/nodejs/bin"
        
        # Create a claude binary that exists but is empty (simulating partial download corruption)
        touch "$XDG_DATA_HOME/claude/versions/$third_version/nodejs/bin/claude"
        chmod +x "$XDG_DATA_HOME/claude/versions/$third_version/nodejs/bin/claude"
        
        # Try to switch to the subtly corrupted version
        test_log "INFO" "Attempting to switch to subtly corrupted version"
        local subtle_corruption_output
        local subtle_corruption_exit_code=0
        subtle_corruption_output=$("./scripts/claude-code.sh" use --version "$third_version" --yes 2>&1) || subtle_corruption_exit_code=$?
        
        # This should pass the basic integrity checks but may fail in actual usage
        # The test verifies that the system handles this gracefully
        
        if [[ $subtle_corruption_exit_code -eq 0 ]]; then
            test_log "INFO" "Switch to subtly corrupted version succeeded (expected for basic validation)"
            
            # Verify the wrapper reports the new version even if it's corrupted
            local subtle_corruption_version
            subtle_corruption_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1) || true
            test_log "INFO" "Version after subtle corruption switch: $subtle_corruption_version"
            
            # Switch back to working version to ensure system recovery
            "./scripts/claude-code.sh" use --version "$initial_version" --yes >/dev/null 2>&1
            
            local final_recovery_version
            final_recovery_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
            assert_contains "$initial_version" "$final_recovery_version" "Should recover to working version"
        else
            test_log "INFO" "Switch to subtly corrupted version failed (also acceptable)"
            # If it failed, the current version should remain unchanged
            local unchanged_version
            unchanged_version=$("$sandbox_dir/.local/bin/claude" --check-version 2>&1)
            if [[ "$unchanged_version" != "$initial_version" ]]; then
                test_log "ERROR" "Version should remain unchanged after subtle corruption failure"
                return 1
            fi
        fi
        
        test_log "SUCCESS" "Corrupted version error handling verified successfully"
    )
}

# Register all test functions
register_tests \
    "test_use_switches_to_installed_version" \
    "test_use_validates_version_exists" \
    "test_use_preserves_other_versions" \
    "test_use_updates_current_symlink_atomically" \
    "test_use_maintains_wrapper_script_functionality" \
    "test_use_switches_from_any_current_version" \
    "test_use_version_verification_after_switch" \
    "test_use_when_target_version_already_current" \
    "test_use_error_handling_permission_issues" \
    "test_use_error_handling_corrupted_version"

# Setup/cleanup orchestration with trap isolation
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Run in subshell to isolate traps from calling environment
    (
        # Set up shared installation before running tests
        setup_shared_claude_installation
        trap 'cleanup_shared_claude_installation' EXIT
        
        # Run test suite with shared installation available
        run_tests_with_args "Claude Code Use Version Tests" "$@"
    ) || exit $?
fi
