#!/bin/bash
# run-tests.sh - Orchestrated test runner for integration tests
#
# Purpose: Execute all integration tests with proper ordering, error handling, and reporting
# Dependencies: All registered test scripts in tests/integration/ directory
# Approach: Run tests in dependency order with comprehensive error reporting

set -euo pipefail

# CRITICAL: Calculate script paths BEFORE any directory changes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source test utilities for consistent logging and error handling
source "$SCRIPT_DIR/utils/test-harness.sh"

# Configuration
export VERBOSE="${VERBOSE:-false}"
export STOP_ON_FAILURE="${STOP_ON_FAILURE:-true}"
RUN_SPECIFIC_TEST=""
SHOW_SUMMARY=true

# Test execution tracking
declare -a TESTS_PASSED=()
declare -a TESTS_FAILED=()
declare -a TESTS_SKIPPED=()
TOTAL_START_TIME=""

# Test function statistics aggregation
TOTAL_TEST_FUNCTIONS=0
TOTAL_FUNCTIONS_PASSED=0
TOTAL_FUNCTIONS_FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_runner_info() {
    echo -e "${BLUE}[RUNNER]${NC} $1"
}

log_runner_success() {
    echo -e "${GREEN}[RUNNER]${NC} $1"
}

log_runner_error() {
    echo -e "${RED}[RUNNER]${NC} $1"
}

log_runner_warning() {
    echo -e "${YELLOW}[RUNNER]${NC} $1"
}

show_usage() {
    cat << EOF
Claude Toolkit Unified Test Runner

Usage: $(basename "$0") [OPTIONS] [TEST_PATTERN]

Options:
  --verbose, -v           Enable verbose output from individual tests
  --continue-on-failure   Continue running tests even if some fail
  --summary               Show test summary at the end (default)
  --no-summary           Skip test summary
  --parallel             Run tests in parallel (experimental)
  --help, -h             Show this help message

Test Selection:
  TEST_PATTERN           Run only tests matching this pattern (e.g., "install", "slash-commands")

Examples:
  $(basename "$0")                                  # Run all tests
  $(basename "$0") --verbose                       # Run all tests with verbose output
  $(basename "$0") install                         # Run only install-related tests
  $(basename "$0") slash-commands                  # Run only slash-commands tests
  $(basename "$0") --continue-on-failure          # Run all tests, don't stop on failures

Available Test Categories:
  - Foundation Layer: claude-code tests (install, uninstall, reinstall, list)
  - Application Layer: slash-commands tests (install, uninstall, reinstall, list)
  - Utilities: sandbox and command masking tests

Test Execution Order:
  1. Utility tests (sandbox, command masking)
  2. Foundation tests (claude-code operations)
  3. Application tests (slash-commands operations)
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --continue-on-failure)
                STOP_ON_FAILURE=false
                shift
                ;;
            --summary)
                SHOW_SUMMARY=true
                shift
                ;;
            --no-summary)
                SHOW_SUMMARY=false
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            --*)
                log_runner_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                RUN_SPECIFIC_TEST="$1"
                shift
                ;;
        esac
    done
}

# Parse test output to extract test function statistics
parse_test_function_stats() {
    local test_output="$1"
    local test_name="$2"
    
    # Strip color codes for easier parsing
    local clean_output
    clean_output=$(echo "$test_output" | sed -r 's/\x1B\[[0-9;]*[JKmsu]//g')
    
    # Extract statistics from test harness output
    # Look for patterns like:
    # [21:50:19][INFO] Total tests: 14
    # [21:50:19][SUCCESS] Passed: 14
    # [21:50:19][INFO] Failed: 0
    
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    
    # Parse total tests
    if [[ "$clean_output" =~ \[[0-9:]+\]\[INFO\][[:space:]]*Total[[:space:]]+tests:[[:space:]]+([0-9]+) ]]; then
        total_tests="${BASH_REMATCH[1]}"
    fi
    
    # Parse passed tests
    if [[ "$clean_output" =~ \[[0-9:]+\]\[SUCCESS\][[:space:]]*Passed:[[:space:]]+([0-9]+) ]]; then
        passed_tests="${BASH_REMATCH[1]}"
    fi
    
    # Parse failed tests - check both INFO and ERROR levels
    if [[ "$clean_output" =~ \[[0-9:]+\]\[INFO\][[:space:]]*Failed:[[:space:]]+([0-9]+) ]]; then
        failed_tests="${BASH_REMATCH[1]}"
    elif [[ "$clean_output" =~ \[[0-9:]+\]\[ERROR\][[:space:]]*Failed:[[:space:]]+([0-9]+) ]]; then
        failed_tests="${BASH_REMATCH[1]}"
    fi
    
    # Update global counters
    TOTAL_TEST_FUNCTIONS=$((TOTAL_TEST_FUNCTIONS + total_tests))
    TOTAL_FUNCTIONS_PASSED=$((TOTAL_FUNCTIONS_PASSED + passed_tests))
    TOTAL_FUNCTIONS_FAILED=$((TOTAL_FUNCTIONS_FAILED + failed_tests))
    
    # Log the parsed statistics if verbose
    if [[ "$VERBOSE" == true ]] && [[ $total_tests -gt 0 ]]; then
        log_runner_info "  Test functions in $test_name: $total_tests total, $passed_tests passed, $failed_tests failed"
    fi
}

# Get test execution time
get_execution_time() {
    local start_time="$1"
    local end_time="$2"
    local duration=$((end_time - start_time))
    
    if [[ $duration -lt 60 ]]; then
        echo "${duration}s"
    elif [[ $duration -lt 3600 ]]; then
        echo "$((duration / 60))m $((duration % 60))s"
    else
        echo "$((duration / 3600))h $(((duration % 3600) / 60))m $((duration % 60))s"
    fi
}

# Execute a single test script
run_single_test() {
    local test_script="$1"
    local test_name
    test_name="$(basename "$test_script" .sh)"
    
    # Skip test if pattern specified and doesn't match
    if [[ -n "$RUN_SPECIFIC_TEST" ]] && [[ "$test_name" != *"$RUN_SPECIFIC_TEST"* ]]; then
        TESTS_SKIPPED+=("$test_name")
        return 0
    fi
    
    # Show running status with inline update
    printf "\r${BLUE}[RUNNER]${NC} Running test: %-50s" "$test_name"
    
    local test_start_time
    test_start_time=$(date +%s)
    local test_output=""
    local test_exit_code=0
    
    # Run test with appropriate verbosity
    if [[ "$VERBOSE" == true ]]; then
        # In verbose mode, show the initial line then let test output show normally
        echo ""  # Move to next line for verbose output
        # Capture output while still showing it in real-time
        test_output=$("$test_script" 2>&1)
        test_exit_code=$?
        # Now show the output to user
        echo "$test_output" >&2
    else
        if test_output=$("$test_script" 2>&1); then
            test_exit_code=0
        else
            test_exit_code=$?
        fi
    fi

    local test_end_time
    test_end_time=$(date +%s)
    local test_duration
    test_duration=$(get_execution_time $test_start_time $test_end_time)
    
    if [[ $test_exit_code -eq 0 ]]; then
        # Overwrite the running line with success message
        printf "\r${GREEN}[RUNNER]${NC} ✅ PASSED: %-50s (%s)\n" "$test_name" "$test_duration"
        TESTS_PASSED+=("$test_name")
        
        # Parse test function statistics from output
        if [[ -n "$test_output" ]]; then
            parse_test_function_stats "$test_output" "$test_name"
        fi
    else
        # Overwrite the running line with failure message  
        printf "\r${RED}[RUNNER]${NC} ❌ FAILED: %-50s (%s)\n" "$test_name" "$test_duration"
        TESTS_FAILED+=("$test_name")
        
        # Parse test function statistics even on failure
        if [[ -n "$test_output" ]]; then
            parse_test_function_stats "$test_output" "$test_name"
        fi
        
        # Show test output on failure (if not already shown in verbose mode)
        if [[ "$VERBOSE" != true ]] && [[ -n "$test_output" ]]; then
            echo -e "${RED}Test output:${NC}"
            echo "$test_output" | sed 's/^/  /'
            echo ""
        fi
        
        if [[ "$STOP_ON_FAILURE" == true ]]; then
            log_runner_error "Stopping test execution due to failure (use --continue-on-failure to continue)"
            return 1
        fi
    fi
    
    return 0
}

# Define test execution order based on dependencies
get_test_order() {
    # Unit tests
    echo "$SCRIPT_DIR/unit/test-sandbox-command-masking.sh"
    echo "$SCRIPT_DIR/unit/test-library-config-block-functions.sh"
    echo "$SCRIPT_DIR/unit/test-library-file-functions.sh"
    echo "$SCRIPT_DIR/unit/test-claude-toolkit-argument-parsing.sh"
    echo "$SCRIPT_DIR/unit/test-claude-code-argument-parsing.sh"
    echo "$SCRIPT_DIR/unit/test-claude-code-version-management-functions.sh"
    echo "$SCRIPT_DIR/unit/test-claude-code-set-default-version-function.sh"
    echo "$SCRIPT_DIR/unit/test-claude-slash-argument-parsing.sh"
    echo "$SCRIPT_DIR/unit/test-claude-slash-source-config-functions.sh"
    echo "$SCRIPT_DIR/unit/test-claude-agents-argument-parsing.sh"
    echo "$SCRIPT_DIR/unit/test-claude-agents-source-config-functions.sh"
    echo "$SCRIPT_DIR/unit/test-claude-template-sources-argument-parsing.sh"

    # claude-code integration tests
    echo "$SCRIPT_DIR/integration/test-claude-code-parse-arguments.sh"
    echo "$SCRIPT_DIR/integration/test-claude-code-dry-run.sh"
    echo "$SCRIPT_DIR/integration/test-claude-code-install.sh"
    echo "$SCRIPT_DIR/integration/test-claude-code-reinstall.sh"
    echo "$SCRIPT_DIR/integration/test-claude-code-uninstall.sh"
    echo "$SCRIPT_DIR/integration/test-claude-code-list.sh"
    echo "$SCRIPT_DIR/integration/test-claude-code-use.sh"

    # claude-slash integration tests
    echo "$SCRIPT_DIR/integration/test-claude-slash-parse-arguments.sh"
    echo "$SCRIPT_DIR/integration/test-claude-slash-dry-run.sh"
    echo "$SCRIPT_DIR/integration/test-claude-slash-install.sh"
    echo "$SCRIPT_DIR/integration/test-claude-slash-list.sh"
    echo "$SCRIPT_DIR/integration/test-claude-slash-reinstall.sh"
    echo "$SCRIPT_DIR/integration/test-claude-slash-uninstall.sh"
    echo "$SCRIPT_DIR/integration/test-claude-slash-uninstall-multisource.sh"

    # claude-agents integration tests
    echo "$SCRIPT_DIR/integration/test-claude-agents-parse-arguments.sh"
    echo "$SCRIPT_DIR/integration/test-claude-agents-dry-run.sh"
    echo "$SCRIPT_DIR/integration/test-claude-agents-install.sh"
    echo "$SCRIPT_DIR/integration/test-claude-agents-list.sh"
    echo "$SCRIPT_DIR/integration/test-claude-agents-reinstall.sh"
    echo "$SCRIPT_DIR/integration/test-claude-agents-uninstall.sh"
    echo "$SCRIPT_DIR/integration/test-claude-agents-uninstall-multisource.sh"

    # claude-template-sources integration tests
    echo "$SCRIPT_DIR/integration/test-claude-template-sources-add.sh"
    echo "$SCRIPT_DIR/integration/test-claude-template-sources-remove.sh"
    echo "$SCRIPT_DIR/integration/test-claude-template-sources-list.sh"
    echo "$SCRIPT_DIR/integration/test-claude-template-sources-dry-run.sh"
    echo "$SCRIPT_DIR/integration/test-claude-template-sources-errors.sh"
    echo "$SCRIPT_DIR/integration/test-claude-template-sources-integration.sh"

    # claude-toolkit integration tests
    echo "$SCRIPT_DIR/integration/test-claude-toolkit-install.sh"
    echo "$SCRIPT_DIR/integration/test-claude-toolkit-reinstall.sh"
    echo "$SCRIPT_DIR/integration/test-claude-toolkit-uninstall.sh"
}

# Show comprehensive test summary
show_test_summary() {
    local total_end_time
    total_end_time=$(date +%s)
    local total_duration
    total_duration=$(get_execution_time "${TOTAL_START_TIME:-$total_end_time}" "$total_end_time")
    
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                        TEST EXECUTION SUMMARY                  ${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Overall statistics
    local total_tests=$((${#TESTS_PASSED[@]} + ${#TESTS_FAILED[@]}))
    local pass_rate=0
    if [[ $total_tests -gt 0 ]]; then
        pass_rate=$(( (${#TESTS_PASSED[@]} * 100) / total_tests ))
    fi
    
    local function_pass_rate=0
    if [[ $TOTAL_TEST_FUNCTIONS -gt 0 ]]; then
        function_pass_rate=$(( (TOTAL_FUNCTIONS_PASSED * 100) / TOTAL_TEST_FUNCTIONS ))
    fi
    
    echo -e "${BLUE}Test Suites:${NC}"
    echo -e "  Total Run: $total_tests"
    echo -e "  ${GREEN}Passed: ${#TESTS_PASSED[@]}${NC}"
    echo -e "  ${RED}Failed: ${#TESTS_FAILED[@]}${NC}"
    echo -e "  ${YELLOW}Skipped: ${#TESTS_SKIPPED[@]}${NC}"
    echo -e "  Pass Rate: ${pass_rate}%"
    echo ""
    
    echo -e "${BLUE}Test Functions:${NC}"
    echo -e "  Total Run: $TOTAL_TEST_FUNCTIONS"
    echo -e "  ${GREEN}Passed: $TOTAL_FUNCTIONS_PASSED${NC}"
    echo -e "  ${RED}Failed: $TOTAL_FUNCTIONS_FAILED${NC}"
    echo -e "  Pass Rate: ${function_pass_rate}%"
    echo ""
    
    echo -e "${BLUE}Total Duration:${NC} $total_duration"
    echo ""
    
    # Show passed tests only if there are failures (for context)
    if [[ ${#TESTS_FAILED[@]} -gt 0 ]]; then
        if [[ ${#TESTS_PASSED[@]} -gt 0 ]]; then
            echo -e "${GREEN}✅ PASSED TESTS:${NC}"
            for test in "${TESTS_PASSED[@]}"; do
                echo -e "  ${GREEN}✓${NC} $test"
            done
            echo ""
        fi
    fi
    
    # Show failed tests
    if [[ ${#TESTS_FAILED[@]} -gt 0 ]]; then
        echo -e "${RED}❌ FAILED TESTS:${NC}"
        for test in "${TESTS_FAILED[@]}"; do
            echo -e "  ${RED}✗${NC} $test"
        done
        echo ""
    fi
    
    # Show skipped tests
    if [[ ${#TESTS_SKIPPED[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⏭️  SKIPPED TESTS:${NC}"
        for test in "${TESTS_SKIPPED[@]}"; do
            echo -e "  ${YELLOW}−${NC} $test"
        done
        echo ""
    fi
    
    # Final result
    if [[ ${#TESTS_FAILED[@]} -eq 0 ]] && [[ $TOTAL_FUNCTIONS_FAILED -eq 0 ]] && [[ $total_tests -gt 0 ]]; then
        echo -e "${GREEN}🎉 ALL TESTS PASSED! 🎉${NC}"
    elif [[ ${#TESTS_FAILED[@]} -gt 0 ]] || [[ $TOTAL_FUNCTIONS_FAILED -gt 0 ]]; then
        echo -e "${RED}💥 SOME TESTS FAILED 💥${NC}"
        if [[ $TOTAL_FUNCTIONS_FAILED -gt 0 ]]; then
            echo -e "${YELLOW}$TOTAL_FUNCTIONS_FAILED test function(s) failed across test suites${NC}"
        fi
        echo -e "${YELLOW}Check the test output above for details${NC}"
    else
        echo -e "${YELLOW}ℹ️  NO TESTS WERE RUN${NC}"
    fi
    
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
}

# Main execution function
main() {
    # Parse arguments
    parse_arguments "$@"
    
    # Show header
    echo ""
    echo -e "${CYAN}Claude Toolkit Test Runner${NC}"
    echo ""
    
    if [[ -n "$RUN_SPECIFIC_TEST" ]]; then
        log_runner_info "Running tests matching pattern: '$RUN_SPECIFIC_TEST'"
    else
        log_runner_info "Running all integration tests"
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        log_runner_info "Verbose mode enabled"
    fi
    
    if [[ "$STOP_ON_FAILURE" == false ]]; then
        log_runner_info "Continue-on-failure mode enabled"
    fi
    
    echo ""
    
    # Record start time
    TOTAL_START_TIME=$(date +%s)
    
    # Get test order and execute
    while IFS= read -r test_script; do
        if [[ -f "$test_script" ]] && [[ -x "$test_script" ]]; then
            if ! run_single_test "$test_script"; then
                break
            fi
        else
            log_runner_warning "Test script not found or not executable: $test_script"
        fi
    done < <(get_test_order)
    
    # Show summary if requested
    if [[ "$SHOW_SUMMARY" == true ]]; then
        show_test_summary
    fi
    
    # Exit with appropriate code
    if [[ ${#TESTS_FAILED[@]} -gt 0 ]] || [[ $TOTAL_FUNCTIONS_FAILED -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Trap for cleanup on exit
cleanup_on_exit() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]] && [[ "$SHOW_SUMMARY" == true ]]; then
        echo ""
        log_runner_error "Test execution interrupted"
    fi
    exit $exit_code
}

trap cleanup_on_exit EXIT

# Run main function
main "$@"
