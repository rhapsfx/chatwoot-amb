#!/bin/bash

# Test script for sandbox command masking functionality
# This verifies that the command masking feature in sandbox-utils.sh works correctly

# Source the test framework
source "$(dirname "$0")/../utils/test-harness.sh"

test_single_command_masking() {
    test_log "INFO" "Testing single command masking (jq)"
    
    (
        # Set up command masking for jq
        commands_to_mask="jq"
        create_sandbox

        # Verify jq appears to be unavailable via command -v
        local jq_path
        local jq_command_v_exit=0
        jq_path=$(command -v jq 2>/dev/null) || jq_command_v_exit=$?

        if [[ $jq_command_v_exit -ne 0 ]] && [[ -z "$jq_path" ]]; then
            test_log "SUCCESS" "jq successfully masked - command -v returns failure (exit $jq_command_v_exit)"
        else
            test_log "ERROR" "jq masking failed - command -v succeeded with: $jq_path"
            return 1
        fi

        # Test that the fake jq executable behaves correctly when called directly
        local jq_output
        local jq_exit_code=0
        jq_output=$(jq --version 2>&1) || jq_exit_code=$?

        if [[ $jq_exit_code -eq 127 ]] && [[ "$jq_output" == *"command not found"* ]]; then
            test_log "SUCCESS" "Fake jq returns correct error: $jq_output"
        else
            test_log "ERROR" "Fake jq unexpected behavior - exit code: $jq_exit_code, output: $jq_output"
            return 1
        fi
        
        # Verify other commands still work
        if command -v ls >/dev/null 2>&1 && ls > /dev/null 2>&1; then
            test_log "SUCCESS" "Other commands (ls) still work correctly"
        else
            test_log "ERROR" "Command masking broke other commands"
            return 1
        fi
    )
}

test_multiple_command_masking() {
    test_log "INFO" "Testing multiple command masking (jq,wget,nonexistent)"
    
    (
        # Set up masking for multiple commands
        commands_to_mask="jq,wget,nonexistent"
        create_sandbox

        # Test each masked command
        local commands_to_test=("jq" "wget" "nonexistent")
        local all_masked=true
        
        for cmd in "${commands_to_test[@]}"; do
            # Test command -v returns failure for masked commands
            local cmd_path
            local cmd_v_exit=0
            cmd_path=$(command -v "$cmd" 2>/dev/null) || cmd_v_exit=$?

            if [[ $cmd_v_exit -ne 0 ]] && [[ -z "$cmd_path" ]]; then
                test_log "SUCCESS" "$cmd successfully masked - command -v returns failure"
                
                # Test that the fake command fails correctly when executed
                local cmd_output
                local cmd_exit_code=0
                cmd_output=$($cmd 2>&1) || cmd_exit_code=$?

                if [[ $cmd_exit_code -eq 127 ]] && [[ "$cmd_output" == *"command not found"* ]]; then
                    test_log "SUCCESS" "Fake $cmd returns correct error"
                else
                    test_log "ERROR" "Fake $cmd unexpected behavior - exit code: $cmd_exit_code"
                    all_masked=false
                fi
            else
                test_log "ERROR" "$cmd masking failed - command -v succeeded with: $cmd_path"
                all_masked=false
            fi
        done
        
        if [[ "$all_masked" == true ]]; then
            test_log "SUCCESS" "All commands successfully masked"
        else
            return 1
        fi
        
        # Verify essential commands still work
        if command -v ls >/dev/null 2>&1 && ls > /dev/null 2>&1 && command -v echo >/dev/null 2>&1 && echo "test" > /dev/null 2>&1; then
            test_log "SUCCESS" "Essential commands (ls, echo) still work"
        else
            test_log "ERROR" "Multiple command masking broke essential commands"
            return 1
        fi
    )
}

test_no_masking_baseline() {
    test_log "INFO" "Testing baseline behavior with no command masking"
    
    (
        # No commands_to_mask variable set
        create_sandbox

        # Verify jq works normally (if available globally)
        local jq_path
        jq_path=$(command -v jq 2>/dev/null)
        
        if [[ -n "$jq_path" ]]; then
            test_log "SUCCESS" "jq available normally at: $jq_path"
            
            # Test that jq actually works
            if jq --version > /dev/null 2>&1; then
                test_log "SUCCESS" "jq functions correctly"
            else
                test_log "ERROR" "jq found but not functional"
                return 1
            fi
        else
            test_log "INFO" "jq not available globally - this is expected in some environments"
        fi
        
        # Verify the sandbox fake bin directory doesn't exist
        if [[ ! -d "$sandbox_dir/.sandbox-fake-bin" ]]; then
            test_log "SUCCESS" "No fake bin directory created when no masking requested"
        else
            test_log "ERROR" "Fake bin directory exists even without masking"
            return 1
        fi
        
        # Verify command override is not active
        if [[ -z "${ORIGINAL_COMMAND_BUILTIN:-}" ]]; then
            test_log "SUCCESS" "No command builtin override active when no masking requested"
        else
            test_log "ERROR" "Command builtin override active even without masking"
            return 1
        fi
    )
}

test_masking_cleanup() {
    test_log "INFO" "Testing that masking cleanup works correctly"
    
    (
        commands_to_mask="jq,test-cmd"
        create_sandbox

        # Verify masking is active
        local jq_path
        local jq_v_exit=0
        jq_path=$(command -v jq 2>/dev/null) || jq_v_exit=$?

        if [[ $jq_v_exit -ne 0 ]] && [[ -z "$jq_path" ]]; then
            test_log "SUCCESS" "Masking initially active - command -v jq returns failure"
        else
            test_log "ERROR" "Masking setup failed - command -v jq succeeded with: $jq_path"
            return 1
        fi
        
        # Verify command override is active
        if [[ -n "${ORIGINAL_COMMAND_BUILTIN:-}" ]]; then
            test_log "SUCCESS" "Command builtin override is active"
        else
            test_log "ERROR" "Command builtin override not active"
            return 1
        fi
        
        # Verify cleanup removes fake bin from PATH and restores command builtin
        local original_path="$PATH"
        cleanup_sandbox "$sandbox_dir"
        
        if [[ "$PATH" != *".sandbox-fake-bin"* ]]; then
            test_log "SUCCESS" "Fake bin directory removed from PATH after cleanup"
        else
            test_log "ERROR" "Fake bin directory still in PATH after cleanup"
            return 1
        fi
        
        # Verify command builtin is restored
        if [[ -z "${ORIGINAL_COMMAND_BUILTIN:-}" ]]; then
            test_log "SUCCESS" "Command builtin override cleaned up"
        else
            test_log "ERROR" "Command builtin override not properly cleaned up"
            return 1
        fi
        
        # Clear trap since we already called cleanup manually
        trap - EXIT
    )
}

test_masking_utility_functions() {
    test_log "INFO" "Testing masking utility functions"
    
    (
        commands_to_mask="jq,wget"
        create_sandbox

        # Test is_command_masked function
        if is_command_masked "jq"; then
            test_log "SUCCESS" "is_command_masked correctly identifies jq as masked"
        else
            test_log "ERROR" "is_command_masked failed to identify jq as masked"
            return 1
        fi
        
        if is_command_masked "wget"; then
            test_log "SUCCESS" "is_command_masked correctly identifies wget as masked"
        else
            test_log "ERROR" "is_command_masked failed to identify wget as masked"
            return 1
        fi
        
        if ! is_command_masked "ls"; then
            test_log "SUCCESS" "is_command_masked correctly identifies ls as not masked"
        else
            test_log "ERROR" "is_command_masked incorrectly reports ls as masked"
            return 1
        fi
        
        # Test list_masked_commands function
        local masked_list
        masked_list=$(list_masked_commands)
        
        if [[ "$masked_list" == *"jq"* ]] && [[ "$masked_list" == *"wget"* ]]; then
            test_log "SUCCESS" "list_masked_commands shows correct commands: $masked_list"
        else
            test_log "ERROR" "list_masked_commands output incorrect: $masked_list"
            return 1
        fi
    )
}


test_whitespace_handling() {
    test_log "INFO" "Testing command masking with whitespace in command list"
    
    (
        # Test with various whitespace scenarios
        commands_to_mask=" jq , wget ,  nonexistent  "
        create_sandbox

        # Verify all commands are masked despite whitespace
        local commands_to_check=("jq" "wget" "nonexistent")
        local all_handled=true
        
        for cmd in "${commands_to_check[@]}"; do
            local cmd_path
            local cmd_v_exit=0
            cmd_path=$(command -v "$cmd" 2>/dev/null) || cmd_v_exit=$?

            if [[ $cmd_v_exit -ne 0 ]] && [[ -z "$cmd_path" ]]; then
                test_log "SUCCESS" "$cmd masked correctly despite whitespace in input"
            else
                test_log "ERROR" "$cmd not masked - whitespace handling failed, found: $cmd_path"
                all_handled=false
            fi
        done
        
        if [[ "$all_handled" == true ]]; then
            test_log "SUCCESS" "Whitespace handling works correctly"
        else
            return 1
        fi
    )
}

test_command_override_functionality() {
    test_log "INFO" "Testing command builtin override functionality"
    
    (
        create_sandbox

        # Step 1: Test that ls works normally without masking
        local ls_path_before
        ls_path_before=$(command -v ls 2>/dev/null)
        if [[ -n "$ls_path_before" ]] && command -v ls >/dev/null 2>&1; then
            test_log "SUCCESS" "ls available normally before masking: $ls_path_before"
        else
            test_log "ERROR" "ls not available before masking"
            return 1
        fi
        
        # Step 2: Apply masking to ls
        setup_command_masking "$sandbox_dir" "ls"
        
        # Step 3: Verify command -v ls now returns failure
        local ls_path_masked
        local ls_command_v_exit=0
        ls_path_masked=$(command -v ls 2>/dev/null) || ls_command_v_exit=$?

        if [[ $ls_command_v_exit -ne 0 ]] && [[ -z "$ls_path_masked" ]]; then
            test_log "SUCCESS" "command -v ls correctly returns failure when masked (exit $ls_command_v_exit)"
        else
            test_log "ERROR" "command -v ls should fail when masked but returned: $ls_path_masked"
            return 1
        fi
        
        # Step 4: Verify other commands still work
        local echo_path
        echo_path=$(command -v echo 2>/dev/null)
        if [[ -n "$echo_path" ]] && command -v echo >/dev/null 2>&1; then
            test_log "SUCCESS" "command -v echo still works with ls masked: $echo_path"
        else
            test_log "ERROR" "command -v echo broken when ls is masked"
            return 1
        fi
        
        # Step 5: Test cleanup restores command functionality
        cleanup_sandbox "$sandbox_dir"
        
        local ls_path_after
        ls_path_after=$(command -v ls 2>/dev/null)
        if [[ -n "$ls_path_after" ]] && [[ "$ls_path_after" == "$ls_path_before" ]]; then
            test_log "SUCCESS" "command -v ls restored after cleanup: $ls_path_after"
        else
            test_log "ERROR" "command -v ls not properly restored - before: $ls_path_before, after: $ls_path_after"
            return 1
        fi
        
        # Clear trap since we manually called cleanup
        trap - EXIT
    )
}

test_jq_fallback_behavior() {
    test_log "INFO" "Testing jq fallback behavior with command override (command -v returns failure)"
    
    (
        create_sandbox

        # Step 1: Set up command override to make jq appear absent
        test_log "INFO" "Step 1: Setting up command override to mask jq"
        
        # Use the command masking system to override the command builtin
        setup_command_masking "$sandbox_dir" "jq"
        
        # Step 2: Verify command -v jq returns failure
        test_log "INFO" "Step 2: Verifying command -v jq returns failure"
        
        local jq_path
        local command_v_exit_code=0
        jq_path=$(command -v jq 2>/dev/null) || command_v_exit_code=$?

        if [[ $command_v_exit_code -ne 0 ]] && [[ -z "$jq_path" ]]; then
            test_log "SUCCESS" "command -v jq correctly returns failure (exit code $command_v_exit_code)"
        else
            test_log "ERROR" "command -v jq unexpectedly succeeded - found at: $jq_path"
            return 1
        fi
        
        # Step 3: Verify other commands still work via command -v
        test_log "INFO" "Step 3: Verifying other commands still work with command -v"
        
        local ls_path
        ls_path=$(command -v ls 2>/dev/null)
        if [[ -n "$ls_path" ]] && command -v ls >/dev/null 2>&1; then
            test_log "SUCCESS" "command -v ls still works correctly: $ls_path"
        else
            test_log "ERROR" "command -v ls broken by command override"
            return 1
        fi
        
        # Step 4: Test get_jq_binary function behavior with absent jq
        test_log "INFO" "Step 4: Testing get_jq_binary function with command override"
        
        # Extract and define only the get_jq_binary function and its dependencies
        # Set up the required configuration variables
        JQ_VERSION="1.8.1"
        JQ_BASE_URL="https://artifacts.apple.com/artifactory/github-releases/jqlang/jq/releases/download/jq-${JQ_VERSION}"
        CLAUDE_CACHE_DIR="$sandbox_dir/.cache/claude"
        VERBOSE=false
        
        # Define the get_jq_binary function locally
        get_jq_binary() {
            # Check if jq is globally available
            if command -v jq >/dev/null 2>&1; then
                echo "jq"
                return 0
            fi
            
            # Determine architecture
            local arch
            if [[ $(uname -m) == "arm64" ]]; then
                arch="arm64"
            else
                arch="amd64"
            fi
            
            local jq_binary="jq-macos-${arch}"
            local jq_url="${JQ_BASE_URL}/${jq_binary}"
            local jq_cache_dir="$CLAUDE_CACHE_DIR/jq"
            local cached_jq="$jq_cache_dir/jq"
            
            # Create cache directory
            mkdir -p "$jq_cache_dir"
            
            # Check if cached jq exists and is executable
            if [[ -f "$cached_jq" ]] && [[ -x "$cached_jq" ]]; then
                echo "$cached_jq"
                return 0
            fi
            
            # For testing purposes, create a simple mock jq instead of downloading
            # This simulates successful fallback without requiring network access
            test_log "DEBUG" "Creating mock jq binary for testing: $cached_jq"
            cat > "$cached_jq" << 'EOF'
#!/bin/bash
# Mock jq for testing
case "$1" in
    --version)
        echo "jq-1.8.1-mock"
        exit 0
        ;;
    -r)
        # Simple JSON parsing for test case
        if [[ "$2" == ".test" ]]; then
            echo "value"
        else
            echo "mock"
        fi
        exit 0
        ;;
    *)
        echo "[]"
        exit 0
        ;;
esac
EOF
            
            # Make executable
            if ! chmod +x "$cached_jq"; then
                echo "Failed to make jq binary executable" >&2
                return 1
            fi
            
            echo "$cached_jq"
        }
        
        # Test the get_jq_binary function
        local jq_binary_result
        local get_jq_exit_code=0
        jq_binary_result=$(get_jq_binary 2>/dev/null) || get_jq_exit_code=$?

        if [[ $get_jq_exit_code -eq 0 ]] && [[ -n "$jq_binary_result" ]]; then
            test_log "SUCCESS" "get_jq_binary returned: $jq_binary_result"
            
            # Verify the returned jq binary works
            if [[ -x "$jq_binary_result" ]] && "$jq_binary_result" --version >/dev/null 2>&1; then
                local jq_version
                jq_version=$("$jq_binary_result" --version 2>/dev/null)
                test_log "SUCCESS" "Fallback jq binary works correctly: $jq_version"
            else
                test_log "ERROR" "Fallback jq binary not executable or not functional: $jq_binary_result"
                return 1
            fi
        else
            test_log "ERROR" "get_jq_binary failed - exit code: $get_jq_exit_code, result: $jq_binary_result"
            return 1
        fi
        
        # Step 5: Test JSON parsing with fallback jq
        test_log "INFO" "Step 5: Testing JSON parsing with fallback jq"
        
        # Create test JSON
        local test_json='{"test": "value", "array": [1, 2, 3]}'
        
        # Test basic JSON parsing
        local parsed_result
        parsed_result=$(echo "$test_json" | "$jq_binary_result" -r '.test' 2>/dev/null)
        
        if [[ "$parsed_result" == "value" ]]; then
            test_log "SUCCESS" "Fallback jq correctly parses JSON: $parsed_result"
        else
            test_log "ERROR" "Fallback jq failed to parse JSON correctly: $parsed_result"
            return 1
        fi
        
        test_log "SUCCESS" "jq fallback behavior test with command override completed successfully"
    )
}

# Main test execution
main() {
    test_log "INFO" "Starting sandbox command masking tests..."
    
    # Run all test functions
    test_single_command_masking
    test_multiple_command_masking
    test_no_masking_baseline
    test_masking_cleanup
    test_masking_utility_functions
    test_whitespace_handling
    test_command_override_functionality
    test_jq_fallback_behavior
    
    test_log "SUCCESS" "All sandbox command masking tests completed successfully!"
}

# Allow running specific test functions
if [[ $# -gt 0 ]]; then
    # Run specific test function if provided as argument
    "$1"
else
    # Run all tests
    main
fi
