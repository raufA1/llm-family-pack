#!/usr/bin/env bash
# Model management utilities for LLM Family Pack
# Version: 3.0.0

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/common.sh"

# Model management functions
lookup_alias_block() {
    local alias="$1"
    validate_not_empty "alias" "${alias}"
    validate_file_exists "${CFG_FILE}"
    
    awk -v a="${alias}" '
        $0 ~ "^- model_name: \"" a "\""{found=1}
        END{ if(found) exit 0; else exit 1 }
    ' "${CFG_FILE}"
}

get_aliases_from_config() {
    if [[ ! -f "${CFG_FILE}" ]]; then
        log_warn "Configuration file not found: ${CFG_FILE}"
        return 1
    fi
    
    awk '/- model_name:/ {
        alias=$0; 
        sub(/^[[:space:]]*- model_name:[[:space:]]*"/,"",alias); 
        sub(/"$/,"",alias); 
        print alias
    }' "${CFG_FILE}" 2>/dev/null || {
        log_error "Failed to parse aliases from configuration"
        return 1
    }
}

list_models() {
    if [[ ! -f "${CFG_FILE}" ]]; then
        log_warn "Configuration file not found: ${CFG_FILE}"
        return 1
    fi
    
    log_info "Available models:"
    print_separator
    
    awk '
        /- model_name:/ {
            alias=$0; 
            sub(/^[[:space:]]*- model_name:[[:space:]]*"/,"",alias); 
            sub(/"$/,"",alias);
            state=1; 
            next
        }
        state && /model:/ { model=$2 }
        state && /api_base:/ { api=$2 }
        state && /max_tokens:/ { 
            mt=$2; 
            printf "  %-20s -> %-30s (api: %s, tokens: %s)\n", 
                   "\"" alias "\"", model, api, mt; 
            state=0 
        }
    ' "${CFG_FILE}" 2>/dev/null || {
        log_error "Failed to parse models from configuration"
        return 1
    }
}

get_default_alias() {
    if [[ -f "${DEFAULT_MODEL_FILE}" ]]; then
        cat "${DEFAULT_MODEL_FILE}"
    else
        get_aliases_from_config | head -n1 || echo "sonnet 4"
    fi
}

set_default_alias() {
    local alias="$1"
    validate_not_empty "alias" "${alias}"
    
    if ! lookup_alias_block "${alias}"; then
        die "Error: Alias '${alias}' not found in configuration"
    fi
    
    ensure_config_dir
    echo "${alias}" > "${DEFAULT_MODEL_FILE}" || die "Failed to set default alias"
    log_info "Default model set to: ${alias}"
}

resolve_backing_to_tuple() {
    local backing="$1"
    validate_not_empty "backing" "${backing}"
    
    # If it looks like a direct model ID, use OpenRouter defaults
    if [[ "${backing}" == */* ]] || [[ "${backing}" == openrouter/* ]]; then
        echo "${backing}|https://openrouter.ai/api/v1|8192"
        return 0
    fi
    
    # Look up existing alias
    if [[ ! -f "${CFG_FILE}" ]]; then
        log_warn "Configuration file not found, using defaults"
        echo "openrouter/qwen/qwen3-coder|https://openrouter.ai/api/v1|8192"
        return 0
    fi
    
    local model_id api_base max_tokens
    
    model_id="$(awk -v a="${backing}" '
        $0 ~ "^- model_name: \"" a "\""{state=1; next}
        state && /model:/ {print $2; exit}
    ' "${CFG_FILE}")"
    
    api_base="$(awk -v a="${backing}" '
        $0 ~ "^- model_name: \"" a "\""{state=1; next}
        state && /api_base:/ {print $2; exit}
    ' "${CFG_FILE}")"
    
    max_tokens="$(awk -v a="${backing}" '
        $0 ~ "^- model_name: \"" a "\""{state=1; next}
        state && /max_tokens:/ {print $2; exit}
    ' "${CFG_FILE}")"
    
    if [[ -z "${model_id:-}" ]]; then
        log_warn "Model ID not found for alias '${backing}', using default"
        echo "openrouter/qwen/qwen3-coder|https://openrouter.ai/api/v1|8192"
    else
        echo "${model_id}|${api_base:-https://openrouter.ai/api/v1}|${max_tokens:-8192}"
    fi
}

append_or_replace_alias() {
    local alias="$1"
    local model_id="$2" 
    local api_base="$3"
    local max_tokens="$4"
    
    validate_not_empty "alias" "${alias}"
    validate_not_empty "model_id" "${model_id}"
    validate_url "${api_base}"
    
    if ! [[ "${max_tokens}" =~ ^[0-9]+$ ]]; then
        die "Error: max_tokens must be a positive integer"
    fi
    
    ensure_config_dir
    
    # Ensure config file exists
    if [[ ! -f "${CFG_FILE}" ]]; then
        die "Error: Configuration file not found: ${CFG_FILE}"
    fi
    
    # Add openrouter prefix if needed
    if [[ "${api_base}" == *"openrouter.ai"* ]] && [[ "${model_id}" != openrouter/* ]]; then
        model_id="openrouter/${model_id}"
    fi
    
    local temp_file
    temp_file="$(mktemp)" || die "Failed to create temporary file"
    
    if lookup_alias_block "${alias}"; then
        # Update existing alias
        log_debug "Updating existing alias: ${alias}"
        awk -v a="${alias}" -v mid="${model_id}" -v api="${api_base}" -v mt="${max_tokens}" '
            BEGIN{skip=0}
            {
                if ($0 ~ "^- model_name: \"" a "\"") {
                    print $0; getline; print "    litellm_params:";
                    print "      model: " mid;
                    print "      api_base: " api;
                    print "      max_tokens: " mt;
                    skip=1; next
                }
                if (skip && $0 ~ "^- model_name: ") { skip=0 }
                if (!skip) print
            }
        ' "${CFG_FILE}" > "${temp_file}"
    else
        # Add new alias
        log_debug "Adding new alias: ${alias}"
        cp "${CFG_FILE}" "${temp_file}"
        {
            printf '  - model_name: "%s"\n' "${alias}"
            printf '    litellm_params:\n'
            printf '      model: %s\n' "${model_id}"
            printf '      api_base: %s\n' "${api_base}"
            printf '      max_tokens: %s\n' "${max_tokens}"
        } >> "${temp_file}"
    fi
    
    mv "${temp_file}" "${CFG_FILE}" || die "Failed to update configuration file"
    log_info "Model configured: \"${alias}\" -> ${model_id} (${api_base}, tokens: ${max_tokens})"
}

delete_alias() {
    local alias="$1"
    validate_not_empty "alias" "${alias}"
    validate_file_exists "${CFG_FILE}"
    
    if ! lookup_alias_block "${alias}"; then
        die "Error: Alias '${alias}' not found in configuration"
    fi
    
    local temp_file
    temp_file="$(mktemp)" || die "Failed to create temporary file"
    
    awk -v a="${alias}" '
        BEGIN{skip=0}
        {
            if ($0 ~ "^- model_name: \"" a "\"") { skip=1; next }
            if (skip && $0 ~ "^- model_name: ") { skip=0 }
            if (!skip) print
        }
    ' "${CFG_FILE}" > "${temp_file}"
    
    mv "${temp_file}" "${CFG_FILE}" || die "Failed to update configuration file"
    
    # Remove from default if it was the default
    if [[ -f "${DEFAULT_MODEL_FILE}" ]] && grep -qx "${alias}" "${DEFAULT_MODEL_FILE}"; then
        rm -f "${DEFAULT_MODEL_FILE}"
        log_info "Removed default model setting"
    fi
    
    log_info "Deleted alias: ${alias}"
}

ensure_claude_aliases() {
    local model_id="$1"
    local api_base="$2"
    local max_tokens="$3"
    
    append_or_replace_alias "sonnet 4" "${model_id}" "${api_base}" "${max_tokens}"
    append_or_replace_alias "claude-sonnet-4-20250514" "${model_id}" "${api_base}" "${max_tokens}"
    
    log_info "Claude aliases configured -> ${model_id}"
}

validate_model_config() {
    if [[ ! -f "${CFG_FILE}" ]]; then
        log_warn "Configuration file not found: ${CFG_FILE}"
        return 1
    fi
    
    # Check YAML syntax
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import yaml
import sys
try:
    with open('${CFG_FILE}', 'r') as f:
        yaml.safe_load(f)
    print('Configuration file syntax is valid')
except yaml.YAMLError as e:
    print(f'Configuration file syntax error: {e}')
    sys.exit(1)
" 2>/dev/null || log_warn "Could not validate YAML syntax (python3/yaml not available)"
    fi
    
    # Check required fields
    if ! grep -q "model_list:" "${CFG_FILE}"; then
        log_error "Configuration file missing 'model_list' section"
        return 1
    fi
    
    log_info "Model configuration appears valid"
    return 0
}

tidy_config() {
    if [[ ! -f "${CFG_FILE}" ]]; then
        log_warn "Configuration file not found: ${CFG_FILE}"
        return 1
    fi
    
    backup_file "${CFG_FILE}"
    
    local temp_file
    temp_file="$(mktemp)" || die "Failed to create temporary file"
    
    # Remove trailing whitespace and empty lines
    sed -E 's/[ \t]+$//' "${CFG_FILE}" | \
    awk 'NF{print} !NF&&prev==0{print} {prev=NF?1:0}' > "${temp_file}"
    
    mv "${temp_file}" "${CFG_FILE}" || die "Failed to tidy configuration file"
    log_info "Configuration file tidied"
}

# Export model management functions
export -f lookup_alias_block get_aliases_from_config list_models
export -f get_default_alias set_default_alias resolve_backing_to_tuple
export -f append_or_replace_alias delete_alias ensure_claude_aliases
export -f validate_model_config tidy_config