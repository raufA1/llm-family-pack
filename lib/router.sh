#!/usr/bin/env bash
# Advanced routing system for LLM Family Pack
# Version: 4.0.0

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/common.sh"

# Routing configuration
readonly ROUTES_FILE="${CFG_DIR}/routes.yaml"
readonly ROUTING_STATE="${CFG_DIR}/routing_state.json"
readonly HEALTH_CHECK_INTERVAL=30
readonly FAILOVER_TIMEOUT=5

# Load balancing algorithms
readonly LB_ROUND_ROBIN="round_robin"
readonly LB_WEIGHTED="weighted"
readonly LB_LEAST_CONNECTIONS="least_connections"
readonly LB_COST_OPTIMIZED="cost_optimized"
readonly LB_LATENCY_BASED="latency_based"

# Route priorities
readonly PRIORITY_PRIMARY=1
readonly PRIORITY_SECONDARY=2
readonly PRIORITY_FALLBACK=3
readonly PRIORITY_EMERGENCY=4

# Initialize routing system
init_routing() {
    log_debug "Initializing routing system..."
    ensure_config_dir
    
    # Create routing state file if not exists
    if [[ ! -f "${ROUTING_STATE}" ]]; then
        create_initial_routing_state
    fi
    
    # Create routes configuration if not exists
    if [[ ! -f "${ROUTES_FILE}" ]]; then
        create_default_routes_config
    fi
    
    log_debug "Routing system initialized"
}

# Create initial routing state
create_initial_routing_state() {
    cat > "${ROUTING_STATE}" <<'JSON'
{
  "version": "4.0.0",
  "last_updated": "",
  "routes": {},
  "health_status": {},
  "statistics": {
    "total_requests": 0,
    "successful_requests": 0,
    "failed_requests": 0,
    "failovers": 0
  },
  "load_balancer_state": {}
}
JSON
    log_debug "Created initial routing state file"
}

# Create default routes configuration
create_default_routes_config() {
    cat > "${ROUTES_FILE}" <<'YAML'
# Advanced Routing Configuration for LLM Family Pack v4.0.0

# Global routing settings
global:
  default_algorithm: round_robin
  health_check_interval: 30
  failover_timeout: 5
  retry_attempts: 3
  circuit_breaker_threshold: 5

# Route groups - logical grouping of models
route_groups:
  gpt-4:
    algorithm: cost_optimized
    routes:
      - name: "primary-gpt4"
        model: "openrouter/openai/gpt-4"
        provider: "openrouter"
        priority: 1
        weight: 70
        cost_per_1m_tokens: 30.0
        max_tokens: 8192
        
      - name: "fallback-qwen"
        model: "openrouter/qwen/qwen2.5-coder-32b-instruct"
        provider: "openrouter"
        priority: 2
        weight: 30
        cost_per_1m_tokens: 0.27
        max_tokens: 8192
        
  claude-sonnet:
    algorithm: weighted
    routes:
      - name: "primary-claude"
        model: "anthropic/claude-3-5-sonnet-20241022"
        provider: "anthropic"
        priority: 1
        weight: 80
        cost_per_1m_tokens: 15.0
        max_tokens: 8192
        
      - name: "fallback-deepseek"
        model: "openrouter/deepseek/deepseek-coder"
        provider: "openrouter"
        priority: 2
        weight: 20
        cost_per_1m_tokens: 0.14
        max_tokens: 8192

  coding-models:
    algorithm: latency_based
    routes:
      - name: "qwen-coder"
        model: "openrouter/qwen/qwen2.5-coder-32b-instruct"
        provider: "openrouter"
        priority: 1
        weight: 40
        cost_per_1m_tokens: 0.27
        region: "us-east"
        
      - name: "deepseek-coder"
        model: "openrouter/deepseek/deepseek-coder"
        provider: "openrouter"
        priority: 1
        weight: 35
        cost_per_1m_tokens: 0.14
        region: "us-west"
        
      - name: "codestral"
        model: "openrouter/mistralai/codestral-latest"
        provider: "openrouter"
        priority: 1
        weight: 25
        cost_per_1m_tokens: 0.20
        region: "eu-central"

# Health check configurations
health_checks:
  enabled: true
  interval: 30
  timeout: 10
  failure_threshold: 3
  success_threshold: 2
  endpoints:
    anthropic:
      url: "https://api.anthropic.com/v1/messages"
      method: "POST"
      expected_status: [200, 400]
      
    openrouter:
      url: "https://openrouter.ai/api/v1/chat/completions"
      method: "POST"
      expected_status: [200, 400]
      
    openai:
      url: "https://api.openai.com/v1/chat/completions"
      method: "POST"
      expected_status: [200, 401]

# Circuit breaker configuration
circuit_breaker:
  enabled: true
  failure_threshold: 5
  timeout: 60
  half_open_max_calls: 3

# Analytics and monitoring
analytics:
  enabled: true
  retention_days: 30
  metrics:
    - request_count
    - response_time
    - error_rate
    - cost_tracking
    - failover_count
YAML
    log_debug "Created default routes configuration file"
}

# Load balancing algorithms
route_round_robin() {
    local group_name="$1"
    local available_routes=("$@")
    shift
    
    # Get current index from state
    local current_index
    current_index="$(get_lb_state "${group_name}" "round_robin_index" "0")"
    
    # Calculate next index
    local next_index=$(( (current_index + 1) % ${#available_routes[@]} ))
    
    # Update state
    set_lb_state "${group_name}" "round_robin_index" "${next_index}"
    
    # Return selected route
    echo "${available_routes[$current_index]}"
}

route_weighted() {
    local group_name="$1"
    shift
    local routes=("$@")
    
    # Simple weighted selection (can be enhanced)
    # For now, use first available route with highest weight
    echo "${routes[0]}"
}

route_least_connections() {
    local group_name="$1"
    shift
    local routes=("$@")
    
    # Find route with least active connections
    local min_connections=999999
    local selected_route=""
    
    for route in "${routes[@]}"; do
        local connections
        connections="$(get_route_connections "${route}")"
        if [[ $connections -lt $min_connections ]]; then
            min_connections=$connections
            selected_route="$route"
        fi
    done
    
    echo "${selected_route}"
}

route_cost_optimized() {
    local group_name="$1"
    shift
    local routes=("$@")
    
    # Find cheapest available route
    local min_cost=999999.0
    local selected_route=""
    
    for route in "${routes[@]}"; do
        local cost
        cost="$(get_route_cost "${route}")"
        if (( $(echo "$cost < $min_cost" | bc -l 2>/dev/null || echo "0") )); then
            min_cost="$cost"
            selected_route="$route"
        fi
    done
    
    echo "${selected_route:-${routes[0]}}"
}

route_latency_based() {
    local group_name="$1"
    shift 
    local routes=("$@")
    
    # Find route with lowest latency
    local min_latency=999999
    local selected_route=""
    
    for route in "${routes[@]}"; do
        local latency
        latency="$(get_route_latency "${route}")"
        if [[ $latency -lt $min_latency ]]; then
            min_latency=$latency
            selected_route="$route"
        fi
    done
    
    echo "${selected_route:-${routes[0]}}"
}

# Route selection with failover
select_route() {
    local model_alias="$1"
    local algorithm="${2:-round_robin}"
    
    log_debug "Selecting route for model: ${model_alias} using algorithm: ${algorithm}"
    
    # Get available routes for model
    local -a available_routes
    mapfile -t available_routes < <(get_healthy_routes "${model_alias}")
    
    if [[ ${#available_routes[@]} -eq 0 ]]; then
        log_error "No healthy routes available for model: ${model_alias}"
        return 1
    fi
    
    # Apply load balancing algorithm
    local selected_route
    case "${algorithm}" in
        "${LB_ROUND_ROBIN}")
            selected_route="$(route_round_robin "${model_alias}" "${available_routes[@]}")"
            ;;
        "${LB_WEIGHTED}")
            selected_route="$(route_weighted "${model_alias}" "${available_routes[@]}")"
            ;;
        "${LB_LEAST_CONNECTIONS}")
            selected_route="$(route_least_connections "${model_alias}" "${available_routes[@]}")"
            ;;
        "${LB_COST_OPTIMIZED}")
            selected_route="$(route_cost_optimized "${model_alias}" "${available_routes[@]}")"
            ;;
        "${LB_LATENCY_BASED}")
            selected_route="$(route_latency_based "${model_alias}" "${available_routes[@]}")"
            ;;
        *)
            log_warn "Unknown algorithm: ${algorithm}, falling back to round_robin"
            selected_route="$(route_round_robin "${model_alias}" "${available_routes[@]}")"
            ;;
    esac
    
    log_debug "Selected route: ${selected_route}"
    echo "${selected_route}"
}

# Health monitoring functions
get_healthy_routes() {
    local model_alias="$1"
    
    # Mock implementation - would check actual health status
    # For now, return all configured routes for the model
    if command -v yq >/dev/null 2>&1 && [[ -f "${ROUTES_FILE}" ]]; then
        yq eval ".route_groups.\"${model_alias}\".routes[].name" "${ROUTES_FILE}" 2>/dev/null || echo "default-route"
    else
        echo "default-route"
    fi
}

# Utility functions for state management
get_lb_state() {
    local group="$1"
    local key="$2"
    local default="$3"
    
    if command -v jq >/dev/null 2>&1 && [[ -f "${ROUTING_STATE}" ]]; then
        jq -r ".load_balancer_state.\"${group}\".\"${key}\" // \"${default}\"" "${ROUTING_STATE}" 2>/dev/null || echo "${default}"
    else
        echo "${default}"
    fi
}

set_lb_state() {
    local group="$1"
    local key="$2"
    local value="$3"
    
    if command -v jq >/dev/null 2>&1 && [[ -f "${ROUTING_STATE}" ]]; then
        local temp_file
        temp_file="$(mktemp)"
        jq ".load_balancer_state.\"${group}\".\"${key}\" = \"${value}\"" "${ROUTING_STATE}" > "${temp_file}" 2>/dev/null && mv "${temp_file}" "${ROUTING_STATE}"
    fi
}

get_route_connections() {
    local route="$1"
    echo "0" # Mock implementation
}

get_route_cost() {
    local route="$1"
    echo "1.0" # Mock implementation  
}

get_route_latency() {
    local route="$1"
    echo "100" # Mock implementation
}

# Health check daemon
start_health_monitor() {
    log_info "Starting health monitor daemon..."
    
    # Background health monitoring
    (
        while true; do
            perform_health_checks
            sleep "${HEALTH_CHECK_INTERVAL}"
        done
    ) &
    
    local health_monitor_pid=$!
    echo "${health_monitor_pid}" > "${CFG_DIR}/health_monitor.pid"
    log_info "Health monitor started with PID: ${health_monitor_pid}"
}

perform_health_checks() {
    log_debug "Performing health checks..."
    
    # Mock health check implementation
    # In real implementation, would ping all configured endpoints
    update_routing_timestamp
}

update_routing_timestamp() {
    if command -v jq >/dev/null 2>&1 && [[ -f "${ROUTING_STATE}" ]]; then
        local temp_file
        temp_file="$(mktemp)"
        jq ".last_updated = \"$(date -Iseconds)\"" "${ROUTING_STATE}" > "${temp_file}" 2>/dev/null && mv "${temp_file}" "${ROUTING_STATE}"
    fi
}

# Route management commands
add_route() {
    local group="$1"
    local name="$2"
    local model="$3"
    local provider="$4"
    local priority="${5:-2}"
    local weight="${6:-50}"
    local cost="${7:-1.0}"
    
    log_info "Adding route: ${name} to group: ${group}"
    
    # Implementation would add route to YAML config
    # For now, log the operation
    log_debug "Route details: model=${model}, provider=${provider}, priority=${priority}, weight=${weight}, cost=${cost}"
}

remove_route() {
    local group="$1"
    local name="$2"
    
    log_info "Removing route: ${name} from group: ${group}"
}

list_routes() {
    local group="${1:-}"
    
    if [[ -n "${group}" ]]; then
        log_info "Routes for group: ${group}"
    else
        log_info "All route groups:"
    fi
    
    if [[ -f "${ROUTES_FILE}" ]]; then
        if command -v yq >/dev/null 2>&1; then
            if [[ -n "${group}" ]]; then
                yq eval ".route_groups.\"${group}\"" "${ROUTES_FILE}" 2>/dev/null || log_warn "Group not found: ${group}"
            else
                yq eval ".route_groups" "${ROUTES_FILE}" 2>/dev/null || log_warn "No route groups configured"
            fi
        else
            log_warn "yq not available, cannot parse YAML configuration"
            cat "${ROUTES_FILE}"
        fi
    else
        log_warn "Routes configuration file not found: ${ROUTES_FILE}"
    fi
}

# Export routing functions
export -f init_routing select_route add_route remove_route list_routes
export -f start_health_monitor perform_health_checks