#!/bin/bash
# test-harness.sh - Reusable test framework for CCTK
# Provides standardized test lifecycle, assertions, and utilities

set -euo pipefail

# Import utility modules
HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${HARNESS_DIR}/assertion-utils.sh"
source "${HARNESS_DIR}/sandbox-utils.sh"

# Test configuration
TEST_VERBOSE="${TEST_VERBOSE:-0}"

# Colors for test output
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'

# Global test state
TEST_SUITE_NAME=""
REGISTERED_TESTS=()
TEST_STATS_TOTAL=0
TEST_STATS_PASSED=0
TEST_STATS_FAILED=0

# Test logging with DEBUG support and multiple arguments
test_log() {
    local level="$1"
    shift
    local timestamp=$(date '+%H:%M:%S')
    
    case "$level" in
        "DEBUG")
            if [[ "$TEST_VERBOSE" == "1" ]]; then
                echo -e "${YELLOW}[$timestamp][DEBUG]${NC} $*" >&2
            fi
            ;;
        "ERROR")
            echo -e "${RED}[${NC}${timestamp}${RED}][${NC}${level}${RED}]${NC} $*" >&2
            ;;
        "SUCCESS")
            echo -e "${GREEN}[${NC}${timestamp}${GREEN}][${NC}${level}${GREEN}]${NC} $*" >&2
            ;;
        "INFO")
            echo -e "${BLUE}[${NC}${timestamp}${BLUE}][${NC}${level}${BLUE}]${NC} $*" >&2
            ;;
        "WARNING")
            echo -e "${YELLOW}[${NC}${timestamp}${YELLOW}][${NC}${level}${YELLOW}]${NC} $*" >&2
            ;;
        *)
            echo "[${timestamp}][${level}] $*" >&2
            ;;
    esac
}

# Test registration and discovery
register_tests() {
    REGISTERED_TESTS=("$@")
    test_log "DEBUG" "Registered ${#REGISTERED_TESTS[@]} tests: ${REGISTERED_TESTS[*]}"
}

# Test suite lifecycle management
_test_suite_setup() {
    local suite_name="$1"
    TEST_SUITE_NAME="$suite_name"
    TEST_STATS_TOTAL=0
    TEST_STATS_PASSED=0
    TEST_STATS_FAILED=0
    
    test_log "INFO" "Starting test suite: $suite_name"

    if declare -f test_suite_setup >/dev/null 2>&1; then
        test_suite_setup
    fi
}

_test_suite_teardown() {
    # Print test suite summary
    test_log "INFO" "Test suite '$TEST_SUITE_NAME' completed"
    test_log "INFO" "Total tests: $TEST_STATS_TOTAL"
    test_log "SUCCESS" "Passed: $TEST_STATS_PASSED"

    if declare -f test_suite_teardown >/dev/null 2>&1; then
        test_suite_teardown
    fi

    if [[ "$TEST_STATS_FAILED" -gt 0 ]]; then
        test_log "ERROR" "Failed: $TEST_STATS_FAILED"
        return 1
    else
        test_log "INFO" "Failed: $TEST_STATS_FAILED"
        return 0
    fi
}

# Run a single test function
run_single_test() {
    local test_func="$1"
    local test_result=0
    
    TEST_STATS_TOTAL=$((TEST_STATS_TOTAL + 1))
    test_log "INFO" "Running test: $test_func"
    
    # Set up test environment
    if declare -f test_setup >/dev/null 2>&1; then
        test_setup
    fi
    
    # Run the test
    if $test_func; then
        TEST_STATS_PASSED=$((TEST_STATS_PASSED + 1))
        test_log "SUCCESS" "Test passed: $test_func"
        test_result=0
    else
        TEST_STATS_FAILED=$((TEST_STATS_FAILED + 1))
        test_log "ERROR" "Test failed: $test_func"
        test_result=1
    fi
    
    # Clean up test environment
    if declare -f test_teardown >/dev/null 2>&1; then
        test_teardown
    fi
    
    echo ""
    return $test_result
}

# Run all registered tests
run_all_tests() {
    local overall_result=0
    
    for test_func in "${REGISTERED_TESTS[@]}"; do
        if ! run_single_test "$test_func"; then
            overall_result=1
        fi
    done
    
    return $overall_result
}

# Run all registered test functions (used by individual test files)
run_registered_tests() {
    local suite_name="${1:-$(basename "${BASH_SOURCE[1]}" .sh)}"
    shift
    local specific_tests=("$@")
    
    # Default behavior - run all registered tests
    if [[ ${#REGISTERED_TESTS[@]} -eq 0 ]]; then
        test_log "WARNING" "No tests registered in this test suite"
        return 0
    fi

    # Determine which tests to run
    local tests_to_run=()
    if [[ ${#specific_tests[@]} -gt 0 ]]; then
        # Run specific tests
        for test_name in "${specific_tests[@]}"; do
            # Check if test is registered
            local found=false
            for registered_test in "${REGISTERED_TESTS[@]}"; do
                if [[ "$registered_test" == "$test_name" ]]; then
                    tests_to_run+=("$test_name")
                    found=true
                    break
                fi
            done
            if [[ "$found" == false ]]; then
                test_log "WARNING" "Test '$test_name' not found in registered tests"
                test_log "INFO" "Available tests: ${REGISTERED_TESTS[*]}"
            fi
        done
    else
        # Run all registered tests
        tests_to_run=("${REGISTERED_TESTS[@]}")
    fi
    
    if [[ ${#tests_to_run[@]} -eq 0 ]]; then
        test_log "ERROR" "No valid tests to run"
        return 1
    fi

    # Set up test suite
    _test_suite_setup "$suite_name"

    # Run selected tests
    local result=0
    local original_registered=("${REGISTERED_TESTS[@]}")
    REGISTERED_TESTS=("${tests_to_run[@]}")
    
    if ! run_all_tests; then
        result=1
    fi
    
    # Restore original registered tests
    REGISTERED_TESTS=("${original_registered[@]}")
    
    # Tear down test suite
    if ! _test_suite_teardown; then
        result=1
    fi
    
    return $result
}

# Helper function for parameterized test execution
# Usage: run_tests_with_args "Test Suite Name" "$@"
# This encapsulates all the boilerplate for command-line argument parsing
run_tests_with_args() {
    local suite_name="$1"
    shift

    # Parse command line arguments for specific test functions
    local specific_tests=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                echo "Usage: $(basename "${BASH_SOURCE[1]}") [test_function_name ...]"
                echo ""
                echo "Available test functions:"
                for test in "${REGISTERED_TESTS[@]}"; do
                    echo "  $test"
                done
                echo ""
                echo "Examples:"
                echo "  $(basename "${BASH_SOURCE[1]}")                    # Run all tests"
                if [[ ${#REGISTERED_TESTS[@]} -gt 0 ]]; then
                    echo "  $(basename "${BASH_SOURCE[1]}") ${REGISTERED_TESTS[0]} # Run specific test"
                fi
                if [[ ${#REGISTERED_TESTS[@]} -gt 1 ]]; then
                    echo "  $(basename "${BASH_SOURCE[1]}") ${REGISTERED_TESTS[0]} ${REGISTERED_TESTS[1]} # Run multiple tests"
                fi
                exit 0
                ;;
            test_*)
                # Validate that this is a registered test function
                if [[ " ${REGISTERED_TESTS[*]} " =~ " $1 " ]]; then
                    specific_tests+=("$1")
                else
                    echo "Error: Unknown test function '$1'" >&2
                    echo "Available tests: ${REGISTERED_TESTS[*]}" >&2
                    exit 1
                fi
                ;;
            *)
                echo "Error: Unknown argument '$1'" >&2
                echo "Use --help for usage information" >&2
                exit 1
                ;;
        esac
        shift
    done

    # Run tests with optional specific test selection
    if [[ ${#specific_tests[@]} -gt 0 ]]; then
        run_registered_tests "$suite_name" "${specific_tests[@]}"
    else
        run_registered_tests "$suite_name"
    fi
}

# Export key functions for test files
export -f test_log
export -f register_tests
export -f run_tests_with_args
