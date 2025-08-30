#!/usr/bin/env bash
# Test framework for LLM Family Pack
# Version: 3.0.0

set -euo pipefail

# Get script directory and source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
LIB_DIR="${PROJECT_DIR}/lib"

# Source common utilities
# shellcheck source=../lib/common.sh
source "${LIB_DIR}/common.sh" || {
    echo "Error: Cannot load common utilities" >&2
    exit 1
}

# Test configuration
readonly TEST_LOG="${CFG_DIR}/test_results.log"
readonly TEMP_TEST_DIR="/tmp/llm-family-pack-tests"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test utilities
setup_test_env() {
    echo "Setting up test environment..."
    
    # Create temporary test directory
    mkdir -p "${TEMP_TEST_DIR}"
    
    # Create test log
    mkdir -p "$(dirname "${TEST_LOG}")"
    echo "Test run started at $(date)" > "${TEST_LOG}"
    
    # Backup original files if they exist
    for file in "${CFG_FILE}" "${ENV_FILE}" "${DEFAULT_MODEL_FILE}"; do
        if [[ -f "${file}" ]]; then
            cp "${file}" "${file}.test_backup" || true
        fi
    done
}

cleanup_test_env() {
    echo "Cleaning up test environment..."
    
    # Restore original files
    for file in "${CFG_FILE}" "${ENV_FILE}" "${DEFAULT_MODEL_FILE}"; do
        if [[ -f "${file}.test_backup" ]]; then
            mv "${file}.test_backup" "${file}" || true
        fi
    done
    
    # Clean up temporary directory
    rm -rf "${TEMP_TEST_DIR}" || true
    
    echo "Test run completed at $(date)" >> "${TEST_LOG}"
}

# Test assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "${expected}" == "${actual}" ]]; then
        echo "✓ PASS: ${message}"
        echo "PASS: ${message} (expected: '${expected}', got: '${actual}')" >> "${TEST_LOG}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ FAIL: ${message}"
        echo "  Expected: '${expected}'"
        echo "  Got:      '${actual}'"
        echo "FAIL: ${message} (expected: '${expected}', got: '${actual}')" >> "${TEST_LOG}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_not_equals() {
    local not_expected="$1"
    local actual="$2"
    local message="${3:-Values should not be equal}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "${not_expected}" != "${actual}" ]]; then
        echo "✓ PASS: ${message}"
        echo "PASS: ${message} (not expected: '${not_expected}', got: '${actual}')" >> "${TEST_LOG}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ FAIL: ${message}"
        echo "  Should not equal: '${not_expected}'"
        echo "  But got:          '${actual}'"
        echo "FAIL: ${message} (should not equal: '${not_expected}', but got: '${actual}')" >> "${TEST_LOG}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_true() {
    local condition="$1"
    local message="${2:-Condition should be true}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if eval "${condition}"; then
        echo "✓ PASS: ${message}"
        echo "PASS: ${message} (condition: ${condition})" >> "${TEST_LOG}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ FAIL: ${message}"
        echo "  Condition failed: ${condition}"
        echo "FAIL: ${message} (condition failed: ${condition})" >> "${TEST_LOG}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_false() {
    local condition="$1"
    local message="${2:-Condition should be false}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if ! eval "${condition}"; then
        echo "✓ PASS: ${message}"
        echo "PASS: ${message} (condition: ${condition})" >> "${TEST_LOG}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ FAIL: ${message}"
        echo "  Condition should have failed: ${condition}"
        echo "FAIL: ${message} (condition should have failed: ${condition})" >> "${TEST_LOG}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist: ${file}}"
    
    assert_true "[[ -f '${file}' ]]" "${message}"
}

assert_file_not_exists() {
    local file="$1"
    local message="${2:-File should not exist: ${file}}"
    
    assert_false "[[ -f '${file}' ]]" "${message}"
}

assert_command_success() {
    local command="$1"
    local message="${2:-Command should succeed: ${command}}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if eval "${command}" >/dev/null 2>&1; then
        echo "✓ PASS: ${message}"
        echo "PASS: ${message} (command: ${command})" >> "${TEST_LOG}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ FAIL: ${message}"
        echo "  Command failed: ${command}"
        echo "FAIL: ${message} (command failed: ${command})" >> "${TEST_LOG}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_command_failure() {
    local command="$1"
    local message="${2:-Command should fail: ${command}}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if ! eval "${command}" >/dev/null 2>&1; then
        echo "✓ PASS: ${message}"
        echo "PASS: ${message} (command: ${command})" >> "${TEST_LOG}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ FAIL: ${message}"
        echo "  Command should have failed: ${command}"
        echo "FAIL: ${message} (command should have failed: ${command})" >> "${TEST_LOG}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test runner
run_test_suite() {
    local test_file="$1"
    local test_name="$(basename "${test_file}" .sh)"
    
    echo
    echo "Running test suite: ${test_name}"
    echo "=================================="
    
    # Source and run the test file
    if [[ -f "${test_file}" ]]; then
        # shellcheck source=/dev/null
        source "${test_file}"
    else
        echo "✗ ERROR: Test file not found: ${test_file}"
        return 1
    fi
}

# Main test execution
run_all_tests() {
    print_header
    echo "LLM Family Pack Test Suite"
    echo
    
    setup_test_env
    
    # Find and run all test files
    local test_files
    mapfile -t test_files < <(find "${SCRIPT_DIR}" -name "test_*.sh" -not -name "test_framework.sh")
    
    for test_file in "${test_files[@]}"; do
        run_test_suite "${test_file}"
    done
    
    # Print summary
    echo
    echo "Test Results Summary"
    echo "===================="
    echo "Tests run:    ${TESTS_RUN}"
    echo "Tests passed: ${TESTS_PASSED}"
    echo "Tests failed: ${TESTS_FAILED}"
    
    if [[ ${TESTS_FAILED} -eq 0 ]]; then
        echo "✓ All tests passed!"
        echo "SUCCESS: All ${TESTS_RUN} tests passed" >> "${TEST_LOG}"
    else
        echo "✗ ${TESTS_FAILED} test(s) failed"
        echo "FAILURE: ${TESTS_FAILED} out of ${TESTS_RUN} tests failed" >> "${TEST_LOG}"
    fi
    
    echo
    echo "Detailed results: ${TEST_LOG}"
    
    cleanup_test_env
    
    # Exit with error code if tests failed
    [[ ${TESTS_FAILED} -eq 0 ]]
}

# Usage information
usage() {
    cat <<USAGE
Test Framework for LLM Family Pack

USAGE:
    test_framework.sh [command]

COMMANDS:
    run                 Run all tests
    list                List available test files
    help                Show this help message

EXAMPLES:
    ./test_framework.sh run
    ./test_framework.sh list

USAGE
}

# Main execution
main() {
    local command="${1:-run}"
    
    case "${command}" in
        run)
            run_all_tests
            ;;
        list)
            echo "Available test files:"
            find "${SCRIPT_DIR}" -name "test_*.sh" -not -name "test_framework.sh" | sort
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            echo "Unknown command: ${command}"
            usage
            exit 1
            ;;
    esac
}

# Export test functions for use in test files
export -f assert_equals assert_not_equals assert_true assert_false
export -f assert_file_exists assert_file_not_exists
export -f assert_command_success assert_command_failure

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi