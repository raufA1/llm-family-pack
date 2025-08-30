#!/usr/bin/env bash
# Service management utilities for LLM Family Pack
# Version: 3.0.0

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/common.sh"

# Service management functions
start_service() {
    log_info "Starting LiteLLM proxy service..."
    
    if check_service_status; then
        log_warn "Service is already running"
        return 0
    fi
    
    if ! systemctl --user enable "${UNIT_NAME}" --now 2>/dev/null; then
        log_error "Failed to start service"
        return 1
    fi
    
    # Wait for service to be ready
    local retries=30
    local count=0
    
    while [[ $count -lt $retries ]]; do
        if check_proxy_health 2; then
            log_info "Service started successfully"
            return 0
        fi
        
        if ! check_service_status; then
            log_error "Service failed to start"
            show_service_logs
            return 1
        fi
        
        sleep 1
        count=$((count + 1))
    done
    
    log_error "Service started but health check failed after ${retries} seconds"
    show_service_logs
    return 1
}

stop_service() {
    log_info "Stopping LiteLLM proxy service..."
    
    if ! check_service_status; then
        log_warn "Service is not running"
        return 0
    fi
    
    if systemctl --user stop "${UNIT_NAME}" 2>/dev/null; then
        log_info "Service stopped successfully"
    else
        log_error "Failed to stop service"
        return 1
    fi
}

restart_service() {
    log_info "Restarting LiteLLM proxy service..."
    
    if systemctl --user restart "${UNIT_NAME}" 2>/dev/null; then
        # Wait for service to be ready
        local retries=30
        local count=0
        
        while [[ $count -lt $retries ]]; do
            if check_proxy_health 2; then
                log_info "Service restarted successfully"
                return 0
            fi
            
            if ! check_service_status; then
                log_error "Service failed to restart"
                show_service_logs
                return 1
            fi
            
            sleep 1
            count=$((count + 1))
        done
        
        log_error "Service restarted but health check failed after ${retries} seconds"
        show_service_logs
        return 1
    else
        log_error "Failed to restart service"
        return 1
    fi
}

show_service_status() {
    print_header
    echo "Service Status:"
    print_separator
    
    if systemctl --user status "${UNIT_NAME}" --no-pager 2>/dev/null; then
        echo
    else
        log_error "Failed to get service status"
        return 1
    fi
    
    # Additional health checks
    echo "Health Checks:"
    print_separator
    
    if check_proxy_health; then
        log_info "Proxy health check: OK"
    else
        log_error "Proxy health check: FAILED"
    fi
    
    if check_proxy_health 1 "/health/readiness"; then
        log_info "Proxy readiness check: OK"
    else
        log_error "Proxy readiness check: FAILED"
    fi
    
    # Port check
    echo
    echo "Network Status:"
    print_separator
    
    if command -v ss >/dev/null 2>&1; then
        if ss -ltnp | grep -q ":${DEFAULT_PORT}"; then
            log_info "Service listening on port ${DEFAULT_PORT}"
        else
            log_error "Service not listening on port ${DEFAULT_PORT}"
        fi
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -ln | grep -q ":${DEFAULT_PORT} "; then
            log_info "Service listening on port ${DEFAULT_PORT}"
        else
            log_error "Service not listening on port ${DEFAULT_PORT}"
        fi
    else
        log_warn "Cannot check port status (ss/netstat not available)"
    fi
}

show_service_logs() {
    local lines="${1:-50}"
    
    echo
    echo "Recent Service Logs (last ${lines} lines):"
    print_separator
    
    if ! journalctl --user -u "${UNIT_NAME}" -n "${lines}" -l --no-pager 2>/dev/null; then
        log_error "Failed to retrieve service logs"
        return 1
    fi
}

check_service_dependencies() {
    local missing_deps=()
    
    echo "Checking Dependencies:"
    print_separator
    
    # Check for uv
    if check_command_exists "uv"; then
        log_info "uv: Available"
    else
        log_error "uv: Missing (required for LiteLLM)"
        missing_deps+=("uv")
    fi
    
    # Check for systemd user services
    if systemctl --user status >/dev/null 2>&1; then
        log_info "systemd user services: Available"
    else
        log_error "systemd user services: Not available"
        missing_deps+=("systemd-user")
    fi
    
    # Check for curl
    if check_command_exists "curl"; then
        log_info "curl: Available"
    else
        log_error "curl: Missing (required for health checks)"
        missing_deps+=("curl")
    fi
    
    # Check configuration files
    if [[ -f "${CFG_FILE}" ]]; then
        log_info "Configuration file: Present"
    else
        log_error "Configuration file: Missing (${CFG_FILE})"
        missing_deps+=("config")
    fi
    
    if [[ -f "${ENV_FILE}" ]]; then
        log_info "Environment file: Present"
    else
        log_warn "Environment file: Missing (${ENV_FILE})"
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo
        log_error "Missing dependencies: ${missing_deps[*]}"
        return 1
    fi
    
    return 0
}

run_diagnostics() {
    print_header
    echo "LiteLLM Proxy Diagnostics"
    echo
    
    # Service status
    show_service_status
    echo
    
    # Dependencies
    check_service_dependencies
    echo
    
    # Configuration validation
    echo "Configuration Status:"
    print_separator
    
    # Source model manager for validation
    if [[ -f "${SCRIPT_DIR}/model_manager.sh" ]]; then
        # shellcheck source=lib/model_manager.sh
        source "${SCRIPT_DIR}/model_manager.sh"
        validate_model_config
    else
        log_warn "Model manager not available for configuration validation"
    fi
    
    # Environment variables
    echo
    echo "Environment Configuration:"
    print_separator
    
    if [[ -f "${ENV_FILE}" ]]; then
        while IFS= read -r line; do
            if [[ "${line}" =~ ^[A-Z_]+= ]]; then
                local key="${line%%=*}"
                if [[ "${key}" == *"KEY"* ]] || [[ "${key}" == *"TOKEN"* ]]; then
                    log_info "${key}: Set (hidden)"
                else
                    log_info "${key}: ${line#*=}"
                fi
            fi
        done < "${ENV_FILE}"
    else
        log_warn "Environment file not found"
    fi
    
    # Test basic connectivity
    echo
    echo "Connectivity Tests:"
    print_separator
    
    if check_proxy_health; then
        log_info "Local proxy: Responding"
        
        # Test a simple model call if possible
        if command -v curl >/dev/null 2>&1; then
            local test_response
            test_response="$(curl -s -m 5 "${BASE_URL}/v1/models" 2>/dev/null)" || true
            if [[ -n "${test_response}" ]]; then
                log_info "Model endpoint: Responding"
            else
                log_warn "Model endpoint: No response"
            fi
        fi
    else
        log_error "Local proxy: Not responding"
    fi
}

fix_common_issues() {
    print_header
    echo "Fixing Common Issues"
    echo
    
    local fixes_applied=0
    
    # Fix environment file permissions
    if [[ -f "${ENV_FILE}" ]]; then
        local current_perms
        current_perms="$(stat -c %a "${ENV_FILE}" 2>/dev/null)" || current_perms="unknown"
        
        if [[ "${current_perms}" != "600" ]]; then
            chmod 600 "${ENV_FILE}" && {
                log_info "Fixed environment file permissions (${current_perms} -> 600)"
                fixes_applied=$((fixes_applied + 1))
            }
        fi
    fi
    
    # Reload systemd if needed
    if systemctl --user daemon-reload 2>/dev/null; then
        log_info "Reloaded systemd user daemon"
        fixes_applied=$((fixes_applied + 1))
    fi
    
    # Clean up old log files
    if [[ -d "${CFG_DIR}" ]]; then
        find "${CFG_DIR}" -name "*.log.*" -mtime +30 -delete 2>/dev/null && {
            log_info "Cleaned up old log files"
            fixes_applied=$((fixes_applied + 1))
        }
    fi
    
    # Ensure config directory exists with correct permissions
    if ensure_config_dir; then
        fixes_applied=$((fixes_applied + 1))
    fi
    
    if [[ ${fixes_applied} -eq 0 ]]; then
        log_info "No common issues found"
    else
        log_info "Applied ${fixes_applied} fixes"
    fi
}

# Health check with custom endpoint
check_proxy_health() {
    local timeout="${1:-1}"
    local endpoint="${2:-/health}"
    
    if curl -fsS -m "${timeout}" "${BASE_URL}${endpoint}" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Export service management functions
export -f start_service stop_service restart_service show_service_status
export -f show_service_logs check_service_dependencies run_diagnostics
export -f fix_common_issues check_proxy_health