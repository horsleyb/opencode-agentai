#!/bin/bash
# OpenCode AgentAI Docker Entrypoint with nginx
set -e; set -u; set -o pipefail

# Set terminal environment for TUI support
export TERM="${TERM:-xterm-256color}"
export COLORTERM="${COLORTERM:-truecolor}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP $1]${NC} $2"; }

print_banner() {
    echo -e "${CYAN}OpenCode AgentAI Container v1.0.0${NC}"
    echo ""
}

check_environment() {
    log_step "1/8" "Checking environment..."
    [[ -n "${ANTHROPIC_API_KEY:-}" ]] && log_success "Anthropic API key"
    [[ -n "${OPENAI_API_KEY:-}" ]] && log_success "OpenAI API key"
    [[ -n "${LLM_ROUTER_URL:-}" ]] && log_success "LLM Router URL"
    [[ -n "${GITHUB_TOKEN:-}" ]] && log_success "GitHub token"
    echo ""
}

check_dependencies() {
    log_step "2/8" "Verifying dependencies..."
    for cmd in node npm python3 go rustc java git curl jq nginx; do
        command -v "$cmd" &>/dev/null && log_success "$cmd" || log_warn "$cmd missing"
    done
    echo ""
}

install_mcp_servers() {
    log_step "3/8" "Checking MCP servers..."
    log_info "MCP servers pre-installed"
    echo ""
}

init_oh_my_opencode() {
    log_step "4/8" "Checking oh-my-opencode..."
    [[ -f /root/.opencode/oh-my-opencode.json ]] && log_success "Configured" || log_info "Skipped"
    echo ""
}

configure_opencode() {
    log_step "5/8" "Configuring OpenCode..."
    mkdir -p /root/.config/opencode /root/.opencode
    [[ -f /root/.config/opencode/opencode.json ]] && log_success "Config found" || log_warn "Config missing"
    echo ""
}

setup_workspace() {
    log_step "6/8" "Setting up workspace..."
    mkdir -p /workspace && cd /workspace
    git config --global user.name "OpenCode AgentAI" 2>/dev/null || true
    git config --global user.email "opencode@container.local" 2>/dev/null || true
    log_success "Workspace ready"
    echo ""
}

test_llm_connectivity() {
    log_step "7/8" "Testing LLM connectivity..."
    [[ -n "${LLM_ROUTER_URL:-}" ]] && curl -sf --max-time 5 "${LLM_ROUTER_URL}/health" >/dev/null && log_success "LLM Router OK" || log_info "LLM Router check skipped"
    echo ""
}

start_nginx() {
    # Copy custom nginx config if exists
    if [[ -f /root/.config/opencode/nginx.conf ]]; then
        cp /root/.config/opencode/nginx.conf /etc/nginx/http.d/opencode.conf
    fi
    log_step "8/8" "Starting nginx proxy..."
    mkdir -p /run/nginx
    nginx && log_success "nginx on :4097 -> OpenCode :4096" || log_error "nginx failed"
    echo ""
}

print_summary() {
    echo "===================================="
    echo -e "${GREEN}Configuration Summary${NC}"
    echo "  Web UI:    http://localhost:4097"
    echo "  OpenCode:  127.0.0.1:4096"
    echo "  Workspace: /workspace"
    echo "===================================="
    echo ""
}

shutdown() {
    log_info "Shutting down..."
    nginx -s quit 2>/dev/null || true
    pkill -P $$ 2>/dev/null || true
    exit 0
}
trap shutdown SIGTERM SIGINT SIGQUIT

main() {
    print_banner
    check_environment
    check_dependencies
    install_mcp_servers
    init_oh_my_opencode
    configure_opencode
    setup_workspace
    test_llm_connectivity
    start_nginx
    print_summary
    log_success "Starting OpenCode server..."
    [[ $# -eq 0 ]] && exec opencode serve --hostname 127.0.0.1 --port 4096 || exec "$@"
}
main "$@"
