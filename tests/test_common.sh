#!/usr/bin/env bash
# Tests for common utilities
# Version: 3.0.0

# Test common utility functions
test_normalize_alias() {
    echo "Testing normalize_alias function..."
    
    # Test basic normalization
    assert_equals "sonnet 4" "$(normalize_alias "sonnet_4")" "Underscore to space conversion"
    assert_equals "sonnet 4" "$(normalize_alias "Sonnet-4")" "Case and hyphen normalization"
    assert_equals "sonnet 4" "$(normalize_alias "SONNET 4")" "Case normalization"
    
    # Test Claude-specific patterns
    assert_equals "sonnet 4" "$(normalize_alias "sonnet4")" "Sonnet 4 pattern recognition"
    assert_equals "sonnet 3.5" "$(normalize_alias "sonnet-3.5")" "Sonnet 3.5 pattern recognition"
    assert_equals "haiku 3.5" "$(normalize_alias "haiku3.5")" "Haiku 3.5 pattern recognition"
    assert_equals "opus" "$(normalize_alias "OPUS")" "Opus pattern recognition"
    
    # Test slash replacement
    assert_equals "qwen-coder" "$(normalize_alias "qwen/coder")" "Slash to hyphen conversion"
}

test_validation_functions() {
    echo "Testing validation functions..."
    
    # Test validate_not_empty
    assert_command_success "validate_not_empty 'test' 'value'" "Valid non-empty value"
    assert_command_failure "validate_not_empty 'test' ''" "Empty value should fail"
    
    # Test validate_url
    assert_command_success "validate_url 'https://api.openai.com/v1'" "Valid HTTPS URL"
    assert_command_success "validate_url 'http://localhost:4000'" "Valid HTTP URL"
    assert_command_failure "validate_url 'not-a-url'" "Invalid URL should fail"
    assert_command_failure "validate_url 'ftp://example.com'" "Non-HTTP URL should fail"
    
    # Test validate_port
    assert_command_success "validate_port '4000'" "Valid port number"
    assert_command_success "validate_port '80'" "Valid low port number"
    assert_command_success "validate_port '65535'" "Valid high port number"
    assert_command_failure "validate_port '0'" "Port 0 should fail"
    assert_command_failure "validate_port '65536'" "Port above 65535 should fail"
    assert_command_failure "validate_port 'not-a-number'" "Non-numeric port should fail"
}

test_config_functions() {
    echo "Testing configuration functions..."
    
    # Create temporary config file for testing
    local test_config="${TEMP_TEST_DIR}/test.env"
    mkdir -p "${TEMP_TEST_DIR}"
    
    # Test setting and getting config values
    set_config_value "TEST_KEY" "test_value" "${test_config}"
    assert_equals "test_value" "$(get_config_value "TEST_KEY" "${test_config}")" "Set and get config value"
    
    # Test updating existing value
    set_config_value "TEST_KEY" "updated_value" "${test_config}"
    assert_equals "updated_value" "$(get_config_value "TEST_KEY" "${test_config}")" "Update existing config value"
    
    # Test file permissions
    local perms
    perms="$(stat -c %a "${test_config}" 2>/dev/null || stat -f %A "${test_config}" 2>/dev/null || echo "unknown")"
    assert_equals "600" "${perms}" "Config file should have 600 permissions"
}

test_logging_functions() {
    echo "Testing logging functions..."
    
    # Test that logging functions don't fail
    assert_command_success "log_info 'Test info message'" "Log info should succeed"
    assert_command_success "log_warn 'Test warning message'" "Log warn should succeed"
    assert_command_success "log_error 'Test error message'" "Log error should succeed"
    
    # Test debug logging (should only work when DEBUG=1)
    unset DEBUG
    assert_command_success "log_debug 'Test debug message'" "Log debug should succeed even without DEBUG"
    
    export DEBUG=1
    assert_command_success "log_debug 'Test debug message with DEBUG=1'" "Log debug should succeed with DEBUG=1"
    unset DEBUG
}

test_utility_functions() {
    echo "Testing utility functions..."
    
    # Test get_version
    local version
    version="$(get_version)"
    assert_not_equals "" "${version}" "Version should not be empty"
    assert_true "[[ '${version}' =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]" "Version should match semantic versioning pattern"
    
    # Test check_command_exists
    assert_command_success "check_command_exists 'bash'" "bash command should exist"
    assert_command_failure "check_command_exists 'non-existent-command-12345'" "Non-existent command should fail"
}

# Run all tests
test_normalize_alias
test_validation_functions
test_config_functions
test_logging_functions
test_utility_functions

echo "Common utilities tests completed."