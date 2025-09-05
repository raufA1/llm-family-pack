#!/usr/bin/env bash
# Common utilities for LLM Family Pack
# Version: 3.0.0

set -euo pipefail

# Constants - only declare if not already set
if [[ -z "${LFP_VERSION:-}" ]]; then
    readonly LFP_VERSION="4.0.0"
    readonly CFG_DIR="${HOME}/.config/litellm"
    readonly CFG_FILE="${CFG_DIR}/config.yaml"
    readonly ENV_FILE="${CFG_DIR}/env"
    readonly DEFAULT_MODEL_FILE="${CFG_DIR}/default_model"
    readonly UNIT_NAME="litellm.service"
    readonly DEFAULT_PORT=4000
    readonly BASE_URL="http://127.0.0.1:${DEFAULT_PORT}"
    readonly LOG_FILE="${CFG_DIR}/llm-family-pack.log"

    # Colors for output
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly NC='\033[0m' # No Color
fi

# Logging functions
log_info() {
    local msg="$1"
    echo -e "${GREEN}[INFO]${NC} ${msg}" | tee -a "${LOG_FILE}" 2>/dev/null || echo -e "${GREEN}[INFO]${NC} ${msg}"
}

log_warn() {
    local msg="$1"
    echo -e "${YELLOW}[WARN]${NC} ${msg}" | tee -a "${LOG_FILE}" 2>/dev/null || echo -e "${YELLOW}[WARN]${NC} ${msg}"
}

log_error() {
    local msg="$1"
    echo -e "${RED}[ERROR]${NC} ${msg}" | tee -a "${LOG_FILE}" 2>/dev/null || echo -e "${RED}[ERROR]${NC} ${msg}"
}

log_debug() {
    local msg="$1"
    if [[ "${DEBUG:-}" == "1" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} ${msg}" | tee -a "${LOG_FILE}" 2>/dev/null || echo -e "${BLUE}[DEBUG]${NC} ${msg}"
    fi
}

# Error handling
die() {
    log_error "$1"
    exit "${2:-1}"
}

# Validation functions
validate_not_empty() {
    local var_name="$1"
    local var_value="$2"
    if [[ -z "${var_value}" ]]; then
        die "Error: ${var_name} cannot be empty"
    fi
}

validate_url() {
    local url="$1"
    if ! [[ "${url}" =~ ^https?:// ]]; then
        die "Error: Invalid URL format: ${url}"
    fi
}

validate_port() {
    local port="$1"
    if ! [[ "${port}" =~ ^[0-9]+$ ]] || [[ "${port}" -lt 1 ]] || [[ "${port}" -gt 65535 ]]; then
        die "Error: Invalid port number: ${port}"
    fi
}

validate_file_exists() {
    local file="$1"
    if [[ ! -f "${file}" ]]; then
        die "Error: File does not exist: ${file}"
    fi
}

validate_dir_exists() {
    local dir="$1"
    if [[ ! -d "${dir}" ]]; then
        die "Error: Directory does not exist: ${dir}"
    fi
}

# Configuration management
ensure_config_dir() {
    if [[ ! -d "${CFG_DIR}" ]]; then
        log_debug "Creating config directory: ${CFG_DIR}"
        mkdir -p "${CFG_DIR}" || die "Failed to create config directory: ${CFG_DIR}"
    fi
}

ensure_log_file() {
    ensure_config_dir
    if [[ ! -f "${LOG_FILE}" ]]; then
        touch "${LOG_FILE}" || log_warn "Could not create log file: ${LOG_FILE}"
    fi
}

backup_file() {
    local file="$1"
    if [[ -f "${file}" ]]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "${file}" "${backup}" || die "Failed to backup file: ${file}"
        log_debug "Backed up ${file} to ${backup}"
    fi
}

# System checks
check_command_exists() {
    local cmd="$1"
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

check_service_status() {
    if systemctl --user is-active "${UNIT_NAME}" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

check_proxy_health() {
    local timeout="${1:-1}"
    if curl -fsS -m "${timeout}" "${BASE_URL}/health" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Network utilities
get_available_port() {
    local port="${1:-${DEFAULT_PORT}}"
    while netstat -ln 2>/dev/null | grep -q ":${port} "; do
        port=$((port + 1))
    done
    echo "${port}"
}

# File operations
safe_write_file() {
    local file="$1"
    local content="$2"
    local mode="${3:-644}"
    
    backup_file "${file}"
    echo "${content}" > "${file}" || die "Failed to write to file: ${file}"
    chmod "${mode}" "${file}" || die "Failed to set permissions on file: ${file}"
    log_debug "Successfully wrote to file: ${file}"
}

# Configuration parsing
get_config_value() {
    local key="$1"
    local config_file="${2:-${ENV_FILE}}"
    
    if [[ -f "${config_file}" ]]; then
        grep "^${key}=" "${config_file}" 2>/dev/null | tail -n1 | cut -d= -f2- || true
    fi
}

set_config_value() {
    local key="$1"
    local value="$2"
    local config_file="${3:-${ENV_FILE}}"
    
    ensure_config_dir
    
    if [[ -f "${config_file}" ]] && grep -q "^${key}=" "${config_file}"; then
        # Update existing value
        sed -i "s/^${key}=.*/${key}=${value}/" "${config_file}"
    else
        # Add new value
        echo "${key}=${value}" >> "${config_file}"
    fi
    
    chmod 600 "${config_file}" || die "Failed to set permissions on config file"
    log_debug "Set ${key} in ${config_file}"
}

# Model management utilities
normalize_alias() {
    local alias="$1"
    # Convert underscores to spaces and hyphens, lowercase
    alias="${alias//_/ - }"
    alias="${alias//\//-}"
    alias="$(echo "${alias}" | tr 'A-Z' 'a-z')"
    
    # Handle special Claude model name patterns
    if [[ "${alias}" =~ sonnet[[:space:]-]?4 ]]; then 
        echo "sonnet 4"
    elif [[ "${alias}" =~ sonnet[[:space:]-]?3\.?5 ]]; then 
        echo "sonnet 3.5"
    elif [[ "${alias}" =~ haiku[[:space:]-]?3\.?5 ]]; then 
        echo "haiku 3.5"
    elif [[ "${alias}" =~ opus ]]; then 
        echo "opus"
    else
        echo "${alias//-/ }"
    fi
}

# Cleanup functions
cleanup_temp_files() {
    find "${CFG_DIR}" -name "*.tmp" -mtime +1 -delete 2>/dev/null || true
    find "${CFG_DIR}" -name "*.backup.*" -mtime +7 -delete 2>/dev/null || true
}

# Version information
get_version() {
    echo "${LFP_VERSION}"
}

# Help and usage utilities
print_header() {
    echo -e "${BLUE}LLM Family Pack v${LFP_VERSION}${NC}"
    echo -e "${BLUE}=================================${NC}"
}

print_separator() {
    echo -e "${BLUE}--------------------------------${NC}"
}

# Initialize common utilities
init_common() {
    ensure_log_file
    cleanup_temp_files
    log_debug "Common utilities initialized"
}

# Export functions that should be available to other scripts
export -f log_info log_warn log_error log_debug
export -f die validate_not_empty validate_url validate_port
export -f ensure_config_dir check_command_exists check_service_status
export -f check_proxy_health get_config_value set_config_value
export -f normalize_alias print_header print_separator