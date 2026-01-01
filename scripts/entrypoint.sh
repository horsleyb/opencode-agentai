#!/bin/bash
# ==============================================================================
# OpenCode AgentAI Docker Entrypoint
# ==============================================================================
#
# This script initializes the OpenCode AgentAI container and starts the server.
#
# Initialization Steps:
#   1. Check environment variables (API keys, URLs)
#   2. Verify runtime dependencies (Node, Python, Go, Rust, Java)
#   3. Install/update MCP servers
#   4. Initialize oh-my-opencode (if not configured)
#   5. Configure OpenCode from environment variables
#   6. Set up workspace and Git configuration
#   7. Test LLM backend connectivity
#   8. Start OpenCode server
#
# Environment Variables:
#   - ANTHROPIC_API_KEY: Anthropic Claude API key
#   - OPENAI_API_KEY: OpenAI GPT API key
#   - GOOGLE_API_KEY: Google Gemini API key
#   - GITHUB_TOKEN: GitHub API token for MCP GitHub server
#   - EXA_API_KEY: Exa search API key
#   - LLM_ROUTER_URL: Local LLM Router URL
#   - OLLAMA_URL: Local Ollama URL
#   - LEMONADE_URL: Local Lemonade Server URL
#   - OPENCODE_SERVER_PORT: OpenCode server port (default: 4096)
#   - OPENCODE_MODEL: Default model to use
#
# Usage:
#   docker-compose up            # Start with default command
#   docker exec -it opencode-agentai opencode  # Access TUI
#
# ==============================================================================

set -e  # Exit on error
set -u  # Exit on undefined variable
set -o pipefail  # Pipe failures propagate

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[STEP $1]${NC} $2"
}

# Banner
print_banner() {
    echo -e "${CYAN}"
    cat << 'BANNER'
    ____                   ____          __        ___                    __  _____
   / __ \____  ___  ____  / __ \____  __/ /__     /   |  ____ ____  ____  / /_/  _/
  / / / / __ \/ _ \/ __ \/ / / / __ \/ __  / _ \  / /| | / __ `/ _ \/ __ \/ __// /
 / /_/ / /_/ /  __/ / / / /_/ / /_/ / /_/ /  __/ / ___ |/ /_/ /  __/ / / / /____/
 \____/ .___/\___/_/ /_/\____/\____/\__,_/\___/ /_/  |_|\__, /\___/_/ /_/\__/___/
     /_/                                                /____/

BANNER
    echo -e "${NC}"
    log_info "OpenCode AgentAI Container"
    log_info "Version: 1.0.0"
    echo ""
}

# Check environment variables
check_environment() {
    log_step "1/7" "Checking environment configuration..."

    # Check for at least one LLM provider
    local has_provider=false

    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        log_success "Anthropic API key detected"
        has_provider=true
    fi

    if [[ -n "${OPENAI_API_KEY:-}" ]]; then
        log_success "OpenAI API key detected"
        has_provider=true
    fi

    if [[ -n "${GOOGLE_API_KEY:-}" ]]; then
        log_success "Google API key detected"
        has_provider=true
    fi

    # Check for local LLM backends
    if [[ -n "${LLM_ROUTER_URL:-}" ]] || [[ -n "${OLLAMA_URL:-}" ]]; then
        log_success "Local LLM backend URL configured"
        has_provider=true
    fi

    if [[ "$has_provider" == false ]]; then
        log_warn "No LLM provider configured!"
        log_warn "Set ANTHROPIC_API_KEY, OPENAI_API_KEY, or LLM_ROUTER_URL"
        log_warn "Container will start but OpenCode may not function correctly"
    fi

    # Check optional services
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        log_success "GitHub token detected - MCP GitHub server enabled"
    else
        log_info "No GitHub token - MCP GitHub server will have limited functionality"
    fi

    if [[ -n "${EXA_API_KEY:-}" ]]; then
        log_success "Exa API key detected - Enhanced search enabled"
    fi

    echo ""
}

# Verify runtime dependencies
check_dependencies() {
    log_step "2/7" "Verifying runtime dependencies..."

    local all_ok=true

    # Core tools with version display
    for cmd in node npm npx bun python3 go rustc java git curl jq; do
        if command -v "$cmd" &> /dev/null; then
            case "$cmd" in
                node) log_success "Node.js $(node --version)" ;;
                npm) log_success "npm v$(npm --version)" ;;
                bun) log_success "Bun v$(bun --version 2>/dev/null || echo 'installed')" ;;
                python3) log_success "Python $(python3 --version 2>&1 | awk '{print $2}')" ;;
                go) log_success "$(go version | awk '{print $3, $4}')" ;;
                rustc) log_success "Rust $(rustc --version | awk '{print $2}')" ;;
                java) log_success "Java $(java -version 2>&1 | head -n1 | awk -F'"' '{print $2}')" ;;
                git) log_success "Git $(git --version | awk '{print $3}')" ;;
                *) log_success "$cmd: installed" ;;
            esac
        else
            log_error "$cmd not found"
            all_ok=false
        fi
    done

    if [[ "$all_ok" == false ]]; then
        log_error "Missing required dependencies"
        exit 1
    fi

    echo ""
}

# Install/Update MCP Servers
install_mcp_servers() {
    log_step "3/7" "Installing/Updating MCP servers..."

    local mcp_servers=(
        "@modelcontextprotocol/server-filesystem"
        
        "@modelcontextprotocol/server-github"
        
        "@modelcontextprotocol/server-memory"
        "@modelcontextprotocol/server-sequential-thinking"
    )

    for server in "${mcp_servers[@]}"; do
        if npm list -g "$server" &> /dev/null; then
            log_info "MCP: $server (already installed)"
        else
            log_info "Installing: $server"
            if npm install -g "$server" --silent 2>/dev/null; then
                log_success "Installed: $server"
            else
                log_warn "Failed to install: $server (will load on-demand)"
            fi
        fi
    done

    log_success "MCP servers ready"
    echo ""
}

# Initialize oh-my-opencode
init_oh_my_opencode() {
    log_step "4/7" "Checking oh-my-opencode installation..."

    local config_file="/root/.opencode/oh-my-opencode.json"

    if [[ -f "$config_file" ]]; then
        log_success "oh-my-opencode already configured"
    else
        log_info "oh-my-opencode not configured, running installation..."

        # Try bunx first, fallback to npx
        if command -v bunx &> /dev/null; then
            if bunx oh-my-opencode install --yes 2>/dev/null; then
                log_success "oh-my-opencode installed via bunx"
            else
                log_warn "bunx installation had issues (optional feature)"
            fi
        elif command -v npx &> /dev/null; then
            if npx -y oh-my-opencode install --yes 2>/dev/null; then
                log_success "oh-my-opencode installed via npx"
            else
                log_warn "npx installation had issues (optional feature)"
            fi
        else
            log_warn "Neither bunx nor npx found for oh-my-opencode (optional)"
        fi
    fi

    echo ""
}

# Configure OpenCode from environment variables
configure_opencode() {
    log_step "5/7" "Configuring OpenCode..."

    local config_file="/root/.config/opencode/opencode.json"

    # Ensure config directory exists
    mkdir -p "$(dirname "$config_file")"
    mkdir -p /root/.opencode

    # Check if config file exists
    if [[ -f "$config_file" ]]; then
        log_info "Configuration file found"

        # Validate JSON syntax
        if ! jq empty "$config_file" 2>/dev/null; then
            log_error "Invalid JSON in opencode.json"
            exit 1
        fi

        # Update configuration with environment variables
        local config_updated=false

        # Update server port
        if [[ -n "${OPENCODE_SERVER_PORT:-}" ]]; then
            log_info "Setting server port: $OPENCODE_SERVER_PORT"
            jq --arg port "$OPENCODE_SERVER_PORT" \
                '.server.port = ($port | tonumber)' \
                "$config_file" > "${config_file}.tmp" && \
                mv "${config_file}.tmp" "$config_file"
            config_updated=true
        fi

        # Update model
        if [[ -n "${OPENCODE_MODEL:-}" ]]; then
            log_info "Setting model: $OPENCODE_MODEL"
            jq --arg model "$OPENCODE_MODEL" \
                '.model = $model' \
                "$config_file" > "${config_file}.tmp" && \
                mv "${config_file}.tmp" "$config_file"
            config_updated=true
        fi

        # Update LLM Router URL
        if [[ -n "${LLM_ROUTER_URL:-}" ]]; then
            log_info "Setting LLM Router: ${LLM_ROUTER_URL}/v1"
            jq --arg url "${LLM_ROUTER_URL}/v1" \
                '.provider."openai-compatible".options.baseURL = $url' \
                "$config_file" > "${config_file}.tmp" && \
                mv "${config_file}.tmp" "$config_file"
            config_updated=true
        fi

        # Update GitHub token
        if [[ -n "${GITHUB_TOKEN:-}" ]]; then
            log_info "Configuring GitHub token for MCP server"
            jq '.mcp.github.environment.GITHUB_TOKEN = "${GITHUB_TOKEN}"' \
                "$config_file" > "${config_file}.tmp" && \
                mv "${config_file}.tmp" "$config_file"
            config_updated=true
        fi

        if [[ "$config_updated" == true ]]; then
            log_success "Configuration updated from environment"
        else
            log_success "Using existing configuration"
        fi
    else
        log_warn "Configuration file not found at $config_file"
        log_warn "Container may not have config volume mounted correctly"
    fi

    # Set OpenCode server port
    export OPENCODE_PORT="${OPENCODE_SERVER_PORT:-4096}"

    echo ""
}

# Set up workspace
setup_workspace() {
    log_step "6/7" "Setting up workspace..."

    # Ensure workspace directory exists
    mkdir -p /workspace
    cd /workspace

    # Display workspace info
    local workspace_size=$(du -sh /workspace 2>/dev/null | awk '{print $1}' || echo "0")
    log_info "Workspace: /workspace (${workspace_size})"

    # Initialize Git config if not present
    if [[ ! -f /root/.gitconfig ]] && [[ -z "$(git config --global user.name 2>/dev/null || true)" ]]; then
        log_info "Initializing Git configuration..."
        git config --global user.name "OpenCode AgentAI"
        git config --global user.email "opencode@container.local"
        git config --global init.defaultBranch main
        git config --global core.editor "vim"
        log_success "Git configuration initialized"
    else
        log_success "Git configuration present"
    fi

    echo ""
}

# Test LLM backend connectivity
test_llm_connectivity() {
    log_step "7/7" "Testing LLM backend connectivity..."

    local tested=false

    # Test LLM Router
    if [[ -n "${LLM_ROUTER_URL:-}" ]]; then
        local router_health="${LLM_ROUTER_URL}/health"
        if curl -sf --max-time 5 "$router_health" > /dev/null 2>&1; then
            log_success "LLM Router: ${LLM_ROUTER_URL} ✓"
        else
            log_warn "LLM Router: ${LLM_ROUTER_URL} (not reachable)"
        fi
        tested=true
    fi

    # Test Ollama
    if [[ -n "${OLLAMA_URL:-}" ]]; then
        local ollama_api="${OLLAMA_URL}/api/tags"
        if curl -sf --max-time 5 "$ollama_api" > /dev/null 2>&1; then
            log_success "Ollama: ${OLLAMA_URL} ✓"
        else
            log_warn "Ollama: ${OLLAMA_URL} (not reachable)"
        fi
        tested=true
    fi

    # Test Lemonade Server
    if [[ -n "${LEMONADE_URL:-}" ]]; then
        if curl -sf --max-time 5 "${LEMONADE_URL}/v1/models" > /dev/null 2>&1; then
            log_success "Lemonade Server: ${LEMONADE_URL} ✓"
        else
            log_warn "Lemonade Server: ${LEMONADE_URL} (not reachable)"
        fi
        tested=true
    fi

    if [[ "$tested" == false ]]; then
        log_info "No local LLM backends configured (using cloud APIs)"
    fi

    echo ""
}

# Display configuration summary
print_summary() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}Configuration Summary${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "  ${CYAN}Server:${NC}      0.0.0.0:${OPENCODE_SERVER_PORT:-4096}"
    echo -e "  ${CYAN}Model:${NC}       ${OPENCODE_MODEL:-anthropic/claude-sonnet-4-5}"
    echo -e "  ${CYAN}Workspace:${NC}   /workspace"

    if [[ -n "${LLM_ROUTER_URL:-}" ]]; then
        echo -e "  ${CYAN}LLM Router:${NC}  ${LLM_ROUTER_URL}"
    fi

    if [[ -n "${OLLAMA_URL:-}" ]]; then
        echo -e "  ${CYAN}Ollama:${NC}      ${OLLAMA_URL}"
    fi

    echo ""
    echo -e "  ${BLUE}Health Check:${NC} http://localhost:${OPENCODE_SERVER_PORT:-4096}/health"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Signal handlers for graceful shutdown
shutdown() {
    echo ""
    log_info "Received shutdown signal..."
    log_info "Stopping OpenCode gracefully..."

    # Kill child processes
    pkill -P $$ 2>/dev/null || true

    log_success "Shutdown complete"
    exit 0
}

# Trap signals
trap shutdown SIGTERM SIGINT SIGQUIT

# Main initialization
main() {
    print_banner

    # Run initialization steps
    check_environment
    check_dependencies
    install_mcp_servers
    init_oh_my_opencode
    configure_opencode
    setup_workspace
    test_llm_connectivity

    # Display summary
    print_summary

    # Export environment variables
    export OPENCODE_SERVER_PORT="${OPENCODE_SERVER_PORT:-4096}"

    log_success "Initialization complete!"
    log_info "Starting OpenCode server..."
    echo ""

    # Execute command
    if [[ $# -eq 0 ]]; then
        exec opencode serve --hostname 0.0.0.0 --port "${OPENCODE_SERVER_PORT}"
    else
        exec "$@"
    fi
}

# Run main function
main "$@"
