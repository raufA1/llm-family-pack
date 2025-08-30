#!/usr/bin/env bash
# Tests for model manager utilities
# Version: 3.0.0

# Source model manager for testing
# shellcheck source=../lib/model_manager.sh
source "${LIB_DIR}/model_manager.sh" || {
    echo "Error: Cannot load model manager" >&2
    exit 1
}

test_model_configuration() {
    echo "Testing model configuration functions..."
    
    # Create test configuration
    local test_config="${TEMP_TEST_DIR}/test_config.yaml"
    mkdir -p "${TEMP_TEST_DIR}"
    
    cat > "${test_config}" <<'EOF'
model_list:
  - model_name: "test-model"
    litellm_params:
      model: openrouter/test/model
      api_base: https://openrouter.ai/api/v1
      max_tokens: 4096
  - model_name: "another-model"
    litellm_params:
      model: gpt-3.5-turbo
      api_base: https://api.openai.com/v1
      max_tokens: 2048

litellm_settings: {}

general_settings:
  disable_database: true
EOF

    # Temporarily override CFG_FILE for testing
    local original_cfg="${CFG_FILE}"
    CFG_FILE="${test_config}"
    
    # Test lookup_alias_block
    assert_command_success "lookup_alias_block 'test-model'" "Should find existing alias"
    assert_command_failure "lookup_alias_block 'non-existent-model'" "Should not find non-existent alias"
    
    # Test get_aliases_from_config
    local aliases
    aliases="$(get_aliases_from_config)"
    assert_true "[[ '${aliases}' == *'test-model'* ]]" "Should find test-model in aliases"
    assert_true "[[ '${aliases}' == *'another-model'* ]]" "Should find another-model in aliases"
    
    # Test resolve_backing_to_tuple
    local tuple
    tuple="$(resolve_backing_to_tuple 'test-model')"
    assert_equals "openrouter/test/model|https://openrouter.ai/api/v1|4096" "${tuple}" "Should resolve model configuration"
    
    # Test direct model ID resolution
    tuple="$(resolve_backing_to_tuple 'openrouter/direct/model')"
    assert_equals "openrouter/direct/model|https://openrouter.ai/api/v1|8192" "${tuple}" "Should handle direct model IDs"
    
    # Restore original CFG_FILE
    CFG_FILE="${original_cfg}"
}

test_alias_management() {
    echo "Testing alias management functions..."
    
    # Create temporary config for alias operations
    local test_config="${TEMP_TEST_DIR}/alias_test_config.yaml"
    mkdir -p "${TEMP_TEST_DIR}"
    
    cat > "${test_config}" <<'EOF'
model_list: []

litellm_settings: {}

general_settings:
  disable_database: true
EOF

    # Temporarily override CFG_FILE for testing
    local original_cfg="${CFG_FILE}"
    CFG_FILE="${test_config}"
    
    # Test append_or_replace_alias (new alias)
    assert_command_success "append_or_replace_alias 'new-model' 'gpt-4' 'https://api.openai.com/v1' '8192'" "Should add new alias"
    assert_command_success "lookup_alias_block 'new-model'" "New alias should be found after adding"
    
    # Test append_or_replace_alias (update existing)
    assert_command_success "append_or_replace_alias 'new-model' 'gpt-4-turbo' 'https://api.openai.com/v1' '4096'" "Should update existing alias"
    
    local tuple
    tuple="$(resolve_backing_to_tuple 'new-model')"
    assert_equals "gpt-4-turbo|https://api.openai.com/v1|4096" "${tuple}" "Updated alias should have new values"
    
    # Test delete_alias
    assert_command_success "delete_alias 'new-model'" "Should delete existing alias"
    assert_command_failure "lookup_alias_block 'new-model'" "Deleted alias should not be found"
    
    # Test delete non-existent alias
    assert_command_failure "delete_alias 'non-existent'" "Should fail to delete non-existent alias"
    
    # Restore original CFG_FILE
    CFG_FILE="${original_cfg}"
}

test_claude_aliases() {
    echo "Testing Claude alias management..."
    
    # Create temporary config for Claude alias testing
    local test_config="${TEMP_TEST_DIR}/claude_test_config.yaml"
    mkdir -p "${TEMP_TEST_DIR}"
    
    cat > "${test_config}" <<'EOF'
model_list: []

litellm_settings: {}

general_settings:
  disable_database: true
EOF

    # Temporarily override CFG_FILE for testing
    local original_cfg="${CFG_FILE}"
    CFG_FILE="${test_config}"
    
    # Test ensure_claude_aliases
    assert_command_success "ensure_claude_aliases 'openrouter/test/model' 'https://openrouter.ai/api/v1' '8192'" "Should create Claude aliases"
    
    # Verify both aliases were created
    assert_command_success "lookup_alias_block 'sonnet 4'" "sonnet 4 alias should exist"
    assert_command_success "lookup_alias_block 'claude-sonnet-4-20250514'" "claude-sonnet-4-20250514 alias should exist"
    
    # Verify both aliases point to the same model
    local tuple1 tuple2
    tuple1="$(resolve_backing_to_tuple 'sonnet 4')"
    tuple2="$(resolve_backing_to_tuple 'claude-sonnet-4-20250514')"
    assert_equals "${tuple1}" "${tuple2}" "Both Claude aliases should resolve to the same model"
    
    # Restore original CFG_FILE
    CFG_FILE="${original_cfg}"
}

test_config_validation() {
    echo "Testing configuration validation..."
    
    # Test with valid config
    local valid_config="${TEMP_TEST_DIR}/valid_config.yaml"
    mkdir -p "${TEMP_TEST_DIR}"
    
    cat > "${valid_config}" <<'EOF'
model_list:
  - model_name: "test-model"
    litellm_params:
      model: gpt-3.5-turbo
      api_base: https://api.openai.com/v1
      max_tokens: 4096

litellm_settings: {}

general_settings:
  disable_database: true
EOF

    # Temporarily override CFG_FILE for testing
    local original_cfg="${CFG_FILE}"
    CFG_FILE="${valid_config}"
    
    assert_command_success "validate_model_config" "Valid configuration should pass validation"
    
    # Test with missing model_list
    local invalid_config="${TEMP_TEST_DIR}/invalid_config.yaml"
    cat > "${invalid_config}" <<'EOF'
litellm_settings: {}
general_settings:
  disable_database: true
EOF

    CFG_FILE="${invalid_config}"
    assert_command_failure "validate_model_config" "Configuration without model_list should fail validation"
    
    # Test with non-existent config
    CFG_FILE="/non/existent/config.yaml"
    assert_command_failure "validate_model_config" "Non-existent configuration should fail validation"
    
    # Restore original CFG_FILE
    CFG_FILE="${original_cfg}"
}

test_config_tidying() {
    echo "Testing configuration tidying..."
    
    # Create messy config for tidying test
    local messy_config="${TEMP_TEST_DIR}/messy_config.yaml"
    mkdir -p "${TEMP_TEST_DIR}"
    
    cat > "${messy_config}" <<'EOF'
model_list:    
  - model_name: "test-model"   
    litellm_params:
      model: gpt-3.5-turbo   
      api_base: https://api.openai.com/v1   
      max_tokens: 4096   


litellm_settings: {}   


general_settings:   
  disable_database: true   
EOF

    # Temporarily override CFG_FILE for testing
    local original_cfg="${CFG_FILE}"
    CFG_FILE="${messy_config}"
    
    assert_command_success "tidy_config" "Should successfully tidy configuration"
    
    # Check that trailing whitespace was removed
    assert_false "grep -q '[[:space:]]$' '${messy_config}'" "Should not contain trailing whitespace after tidying"
    
    # Restore original CFG_FILE
    CFG_FILE="${original_cfg}"
}

# Run all tests
test_model_configuration
test_alias_management
test_claude_aliases
test_config_validation
test_config_tidying

echo "Model manager tests completed."