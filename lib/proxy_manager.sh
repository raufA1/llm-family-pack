#!/usr/bin/env bash
# Proxy management utilities for LLM Family Pack
# Version: 1.0.0

set -euo pipefail

# Source common utilities if not already sourced
if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck source=lib/common.sh
    source "${SCRIPT_DIR}/common.sh"
fi

# --- Configuration Paths ---

_get_proxy_config_dir() {
    echo "${HOME}/.config/llm-family-pack"
}

_get_proxies_file() {
    echo "$(_get_proxy_config_dir)/proxies.conf"
}

_get_active_proxy_file() {
    echo "$(_get_proxy_config_dir)/active_proxy"
}

# --- Core Proxy Management ---

# Ensures the proxy configuration directory exists
_ensure_proxy_config_dir() {
    local config_dir
    config_dir="$(_get_proxy_config_dir)"
    if [[ ! -d "${config_dir}" ]]; then
        mkdir -p "${config_dir}"
        log_info "Created proxy configuration directory: ${config_dir}"
    fi
}

# Adds or updates a proxy in the configuration file
add_proxy() {
    local name="$1"
    local url="$2"

    validate_not_empty "Proxy name" "${name}"
    validate_url "${url}"
    _ensure_proxy_config_dir

    local proxies_file
    proxies_file="$(_get_proxies_file)"
    
    # Create file if it doesn't exist
    touch "${proxies_file}"

    # Remove existing entry if it exists
    if grep -q -E "^${name}[[:space:]]+" "${proxies_file}"; then
        sed -i "/^${name}[[:space:]]\+/d" "${proxies_file}"
        log_info "Updating existing proxy: ${name}"
    else
        log_info "Adding new proxy: ${name}"
    fi

    # Add new entry
    echo "${name} ${url}" >> "${proxies_file}"
    log_info "Successfully saved proxy '${name}'."
}

# Removes a proxy from the configuration file
remove_proxy() {
    local name="$1"
    validate_not_empty "Proxy name" "${name}"

    local proxies_file
    proxies_file="$(_get_proxies_file)"

    if [[ ! -f "${proxies_file}" ]] || ! grep -q -E "^${name}[[:space:]]+" "${proxies_file}"; then
        log_warn "Proxy '${name}' not found."
        return 1
    fi

    sed -i "/^${name}[[:space:]]\+/d" "${proxies_file}"
    log_info "Successfully removed proxy '${name}'."

    # If the removed proxy was active, deactivate it
    local active_proxy
    active_proxy="$(get_active_proxy_name)"
    if [[ "${active_proxy}" == "${name}" ]]; then
        switch_proxy "none"
        log_info "Deactivated proxy as it was removed."
    fi
}

# Lists all configured proxies
list_proxies() {
    print_header "Configured Proxies"
    
    local proxies_file
    proxies_file="$(_get_proxies_file)"

    if [[ ! -f "${proxies_file}" ]] || [[ ! -s "${proxies_file}" ]]; then
        log_info "No proxies configured. Use 'llm proxy add <name> <url>' to add one."
        return
    fi

    local active_proxy
    active_proxy="$(get_active_proxy_name)"

    while IFS= read -r line || [[ -n "$line" ]]; do
        local name
        local url
        name=$(echo "$line" | awk '{print $1}')
        url=$(echo "$line" | awk '{print $2}')

        if [[ "${name}" == "${active_proxy}" ]]; then
            echo -e "  ${GREEN}* ${name}${NC} -> ${url} (active)"
        else
            echo "    ${name} -> ${url}"
        fi
    done < "${proxies_file}"
}

# Switches the active proxy
switch_proxy() {
    local name="$1"
    validate_not_empty "Proxy name" "${name}"
    _ensure_proxy_config_dir

    local active_proxy_file
    active_proxy_file="$(_get_active_proxy_file)"

    if [[ "${name}" == "none" ]]; then
        if [[ -f "${active_proxy_file}" ]]; then
            rm "${active_proxy_file}"
        fi
        log_info "Proxy deactivated."
        update_systemd_proxy
        return
    fi

    local proxies_file
    proxies_file="$(_get_proxies_file)"
    if ! grep -q -E "^${name}[[:space:]]+" "${proxies_file}"; then
        log_error "Proxy '${name}' not found in configuration."
        return 1
    fi

    echo "${name}" > "${active_proxy_file}"
    log_info "Switched active proxy to '${name}'."
    update_systemd_proxy
}

# Gets the name of the currently active proxy
get_active_proxy_name() {
    local active_proxy_file
    active_proxy_file="$(_get_active_proxy_file)"
    if [[ -f "${active_proxy_file}" ]]; then
        cat "${active_proxy_file}"
    else
        echo "none"
    fi
}

# Gets the URL of the currently active proxy
get_active_proxy_url() {
    local active_proxy_name
    active_proxy_name="$(get_active_proxy_name)"

    if [[ "${active_proxy_name}" == "none" ]]; then
        echo ""
        return
    fi

    local proxies_file
    proxies_file="$(_get_proxies_file)"
    if [[ -f "${proxies_file}" ]]; then
        grep -E "^${active_proxy_name}[[:space:]]+" "${proxies_file}" | awk '{print $2}'
    else
        echo ""
    fi
}

# Shows the status of the active proxy
show_proxy_status() {
    print_header "Proxy Status"
    local active_proxy_name
    active_proxy_name="$(get_active_proxy_name)"
    
    if [[ "${active_proxy_name}" == "none" ]]; then
        log_info "Proxy is currently disabled."
    else
        local proxy_url
        proxy_url="$(get_active_proxy_url)"
        log_info "Active Proxy: ${active_proxy_name}"
        echo "URL: ${proxy_url}"
    fi
}

# --- System Integration ---

# Updates systemd user environment with the active proxy
update_systemd_proxy() {
    if ! command -v systemctl >/dev/null || ! systemctl --user status >/dev/null 2>&1; then
        log_warn "systemd user services not available. Cannot apply proxy settings automatically."
        log_warn "Please set HTTP_PROXY and HTTPS_PROXY environment variables manually."
        return 1
    fi

    local proxy_url
    proxy_url="$(get_active_proxy_url)"

    if [[ -n "${proxy_url}" ]]; then
        systemctl --user set-environment "HTTP_PROXY=${proxy_url}"
        systemctl --user set-environment "HTTPS_PROXY=${proxy_url}"
        log_info "Applied proxy '${proxy_url}' to systemd user environment."
    else
        systemctl --user unset-environment "HTTP_PROXY" "HTTPS_PROXY"
        log_info "Removed proxy settings from systemd user environment."
    fi
    
    log_warn "Run 'llm restart' for the changes to take full effect."
}

# Export functions for use in other scripts
export -f add_proxy remove_proxy list_proxies switch_proxy get_active_proxy_name get_active_proxy_url show_proxy_status update_systemd_proxy
