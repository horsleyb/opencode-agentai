# OpenCode AgentAI

A comprehensive, containerized AI coding assistant powered by [OpenCode](https://opencode.ai) and [oh-my-opencode](https://github.com/modelcontextprotocol/oh-my-opencode), featuring extensive MCP (Model Context Protocol) server integration and local LLM backend connectivity.

## Overview

OpenCode AgentAI provides a production-ready, Docker-based development environment that combines:

- **OpenCode**: Modern AI coding assistant with terminal UI
- **oh-my-opencode**: Enhanced OpenCode configuration with additional capabilities
- **MCP Servers**: 6 pre-configured Model Context Protocol servers for filesystem, Git, GitHub, web fetch, memory, and sequential thinking
- **Multi-Language Support**: Python, TypeScript/JavaScript, Go, Rust, Java with full LSP integration
- **LLM Router Integration**: All LLM requests route through a unified gateway

## Features

- **Complete Development Environment**: Pre-installed toolchains for Python, Node.js, Go, Rust, and Java
- **MCP Server Ecosystem**: Extensible agent capabilities through standardized protocol servers
- **Unified LLM Gateway**: All requests through LLM Router
- **Git Integration**: Full repository operations with GitHub API access
- **Persistent State**: Configuration and cache volumes for consistent behavior
- **Resource Management**: Configurable memory limits and health checks
- **Host Network Mode**: Seamless access to local LLM services

## Prerequisites

### Required
- **Docker**: Version 20.10 or later with Docker Compose
- **LLM Router**: Running on port 8000 (unified LLM gateway)

### Optional
- **GitHub Token**: For repository operations via MCP GitHub server
- **Exa API Key**: For enhanced web search capabilities (oh-my-opencode)

## Quick Start

### 1. Clone and Configure

```bash
# Clone the repository
git clone https://github.com/horsleyb/opencode-agentai.git
cd opencode-agentai

# Copy environment template
cp .env.example .env

# Edit .env with your API keys and settings
nano .env  # or use your preferred editor
```

### 2. Configure Environment Variables

Edit `.env` and configure:

```bash
# LLM Router (required)
LLM_ROUTER_URL=http://localhost:8000

# Optional: GitHub integration
GITHUB_TOKEN=your_github_token_here

# Optional: Exa web search
EXA_API_KEY=your_exa_key_here
```

### 3. Launch Container

```bash
# Build and start the container
docker-compose up -d

# View logs
docker-compose logs -f

# Access the OpenCode TUI
docker exec -it opencode-agentai opencode
```

### 4. First-Time Setup

On first launch, OpenCode will:
1. Initialize configuration from `config/opencode.json`
2. Connect to configured MCP servers
3. Validate LLM backend connectivity
4. Present the interactive terminal UI

## Configuration Options

### OpenCode Configuration (`config/opencode.json`)

Key configuration sections:

#### Model Selection
```json
{
  "model": "claude-sonnet-4-5",
  "small_model": "claude-haiku-4-5"
}
```

Models are served through LLM Router. Configure available models in your LLM Router instance.

#### Provider Configuration

All requests go through LLM Router:
```json
"provider": {
  "openai-compatible": {
    "options": {
      "baseURL": "http://localhost:8000/v1",
      "timeout": 600000
    }
  }
}
```

#### Tool Permissions
```json
"permission": {
  "edit": "ask",    // Require confirmation for file edits
  "bash": "ask"     // Require confirmation for shell commands
}
```

Options: `"always"`, `"ask"`, `"never"`

#### LSP Server Support
```json
"lsp": {
  "typescript": { "disabled": false },
  "python": { "disabled": false },
  "go": { "disabled": false },
  "rust": { "disabled": false },
  "java": { "disabled": false }
}
```

### Environment Variables (`.env`)

#### LLM Router (Required)
```bash
# Unified LLM gateway - all requests go through here
LLM_ROUTER_URL=http://localhost:8000
```

#### MCP Server Keys (Optional)
```bash
# GitHub MCP - repository operations
GITHUB_TOKEN=ghp_...

# Exa Search (oh-my-opencode)
EXA_API_KEY=...
```

#### OpenCode Settings
```bash
# Server configuration
OPENCODE_SERVER_PORT=4096
```

## MCP Servers Included

The container includes 6 pre-configured MCP servers:

| Server | Purpose | Configuration |
|--------|---------|---------------|
| **filesystem** | File operations (read, write, search) | Scoped to `/workspace` |
| **git** | Git repository operations | Full Git CLI access |
| **github** | GitHub API integration | Requires `GITHUB_TOKEN` |
| **fetch** | HTTP requests and web scraping | No auth required |
| **memory** | Persistent conversation memory | Local storage |
| **sequential-thinking** | Multi-step reasoning | Enhanced planning |

### MCP Server Configuration

Edit `config/opencode.json` to enable/disable servers:

```json
"mcp": {
  "github": {
    "enabled": true,  // Set to false to disable
    "environment": {
      "GITHUB_TOKEN": "${GITHUB_TOKEN}"
    }
  }
}
```

### Adding Custom MCP Servers

1. Install the server in the Dockerfile:
```dockerfile
RUN npm install -g your-custom-mcp-server
```

2. Add configuration to `config/opencode.json`:
```json
"mcp": {
  "custom-server": {
    "type": "local",
    "command": ["npx", "-y", "your-custom-mcp-server"],
    "enabled": true
  }
}
```

## LLM Backend Connectivity

All LLM requests are routed through the LLM Router, providing a unified gateway to multiple backends.

### Configuration

```bash
# .env
LLM_ROUTER_URL=http://localhost:8000
```

```json
// config/opencode.json
{
  "model": "claude-sonnet-4-5",
  "provider": {
    "openai-compatible": {
      "options": {
        "baseURL": "http://localhost:8000/v1",
        "timeout": 600000
      }
    }
  }
}
```

### LLM Router Backends

The LLM Router can route to multiple backends:
- **Ollama** (NVIDIA GPU) - Port 11434
- **Lemonade Server** (AMD NPU) - Port 8001
- **Docker Model Runner** (CPU) - Port 12434
- **Cloud APIs** (Anthropic, OpenAI, etc.)

Configure backends in your LLM Router instance. See [llm-router documentation](https://github.com/horsleyb/llm-router).

## Usage Examples

### Basic Code Generation

```bash
# Start OpenCode TUI
docker exec -it opencode-agentai opencode

# In OpenCode prompt:
> Create a Python FastAPI server with health endpoint

> Add TypeScript types for a user authentication system

> Refactor this function to be more efficient [paste code]
```

### Git Operations (via MCP GitHub)

```bash
> Clone repository https://github.com/user/repo into ./projects

> Create a new branch feature/add-auth

> Review recent commits on main branch

> Create a pull request for current branch
```

### Web Research (via MCP Fetch)

```bash
> Fetch the latest documentation from https://docs.example.com

> Search for React best practices and summarize

> Download and analyze the package.json from [URL]
```

### Multi-Step Planning (via MCP Sequential Thinking)

```bash
> Plan and implement a complete user authentication system with:
  - Database models
  - API endpoints
  - Frontend components
  - Tests
```

### Workspace Operations

```bash
# Work on code in the workspace directory
cd workspace
git clone https://github.com/your-username/your-project.git
cd your-project

# Start OpenCode in project context
opencode

# OpenCode will use MCP filesystem server to access project files
```

### Advanced: Model Switching

Switch models at runtime (must be available in LLM Router):

```bash
# Use Haiku for quick tasks (faster)
> /model claude-haiku-4-5

# Use Sonnet for complex reasoning (balanced)
> /model claude-sonnet-4-5

# Use local model
> /model qwen2.5:7b
```

## Project Structure

```
opencode-agentai/
├── config/
│   └── opencode.json          # OpenCode configuration
├── workspace/                 # Your code projects (mounted volume)
├── docker-compose.yml         # Container orchestration
├── Dockerfile                 # Image definition
├── .env.example              # Environment template
└── README.md                 # This file
```

## Docker Volumes

| Volume | Purpose | Persistence |
|--------|---------|-------------|
| `./workspace` | Your code projects | Persistent (local mount) |
| `./config` | OpenCode configuration | Persistent (read-only) |
| `opencode-state` | Cache and session data | Persistent (named volume) |
| `~/.ssh` | SSH keys for Git | Read-only (host mount) |
| `~/.gitconfig` | Git configuration | Read-only (host mount) |

## Resource Management

Configure in `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      memory: 8G      # Maximum memory
    reservations:
      memory: 2G      # Guaranteed memory
```

Adjust based on your system resources and workload.

## Networking

### Host Network Mode (Default)

The container uses host networking to access local LLM services:

```yaml
network_mode: host
```

**Advantages:**
- Direct access to `localhost:8000` (LLM Router)
- No port mapping required
- Simplest configuration

**Limitations:**
- Linux/macOS only (Docker Desktop on Windows may require bridge mode)

### Bridge Network Mode (Alternative)

For Windows or isolated networking, use bridge mode:

```yaml
# Uncomment in docker-compose.yml
ports:
  - "4096:4096"

extra_hosts:
  - "host.docker.internal:host-gateway"
```

Then update `.env`:
```bash
LLM_ROUTER_URL=http://host.docker.internal:8000
```

## Troubleshooting

### Container Health Check Failing

```bash
# Check container status
docker-compose ps

# View detailed logs
docker-compose logs opencode

# Restart container
docker-compose restart
```

### Cannot Connect to Local LLM

**Symptom:** "Connection refused" when using local backends

**Solutions:**
1. Verify LLM service is running: `curl http://localhost:8000/health`
2. Check network mode in `docker-compose.yml`
3. On Windows, use `host.docker.internal` instead of `localhost`

### MCP Server Not Loading

**Symptom:** Server shows as disabled in OpenCode

**Solutions:**
1. Check environment variables: `docker-compose config`
2. Verify API keys in `.env`
3. Review logs: `docker exec opencode-agentai cat /root/.opencode/mcp.log`

### File Permission Issues

**Symptom:** Cannot save files in workspace

**Solutions:**
```bash
# Fix workspace permissions
sudo chown -R $(id -u):$(id -g) workspace/

# Or use root inside container
docker exec -it -u root opencode-agentai bash
```

### Out of Memory Errors

**Symptom:** Container killed or OOM errors

**Solutions:**
1. Increase memory limits in `docker-compose.yml`
2. Use smaller models (Haiku instead of Sonnet)
3. Monitor usage: `docker stats opencode-agentai`

## Performance Optimization

### For Local LLMs

1. **Use Quantized Models**: Q4_K_M provides good quality/speed balance
2. **GPU Offload**: Ensure Ollama/LLM Router uses GPU acceleration
3. **Context Window**: Reduce max tokens for faster responses
4. **Caching**: Enable prompt caching in LLM Router

### For Cloud LLMs

1. **Use Haiku**: For simple tasks, use Claude Haiku 4.5
2. **Prompt Caching**: Anthropic offers automatic caching
3. **Timeouts**: Adjust in `config/opencode.json` based on network

## Security Considerations

- **API Keys**: Never commit `.env` to version control
- **SSH Keys**: Mounted read-only by default
- **GitHub Token**: Use fine-grained tokens with minimal scopes
- **Network Isolation**: Consider bridge mode for production
- **Resource Limits**: Prevent resource exhaustion with deploy limits

## Development Workflow

### Recommended Setup

```bash
# Terminal 1: Run services
cd llm-router && docker-compose up

# Terminal 2: Run OpenCode container
cd opencode-agentai && docker-compose up

# Terminal 3: Work in workspace
cd opencode-agentai/workspace
opencode  # or connect via IDE to port 4096
```

### IDE Integration

OpenCode Server runs on port `4096` and can be accessed by:
- **VS Code**: Use OpenCode extension
- **Cursor**: Configure as OpenAI-compatible endpoint
- **Neovim**: Use OpenCode.nvim plugin
- **Terminal**: Direct TUI access via `docker exec`

## Advanced Configuration

### Custom Entrypoint

Create `scripts/entrypoint.sh` for initialization logic:

```bash
#!/bin/bash
set -e

# Custom setup
echo "Initializing OpenCode AgentAI..."

# Start OpenCode
exec "$@"
```

### Multi-Model Configuration

```json
{
  "model": "claude-sonnet-4-5",
  "small_model": "claude-haiku-4-5"
}
```

Switch at runtime: `/model claude-haiku-4-5`

Available models depend on your LLM Router configuration.

## Contributing

Contributions welcome! Areas for improvement:
- Additional MCP server integrations
- Performance optimizations
- Documentation enhancements
- Example workflows and tutorials

## License

This project combines:
- **OpenCode**: [License](https://github.com/sst/opencode)
- **oh-my-opencode**: [License](https://github.com/modelcontextprotocol/oh-my-opencode)
- **MCP Servers**: Various (see individual repositories)

Check individual component licenses for details.

## Resources

- [OpenCode Documentation](https://opencode.ai/docs)
- [Model Context Protocol](https://modelcontextprotocol.io)
- [oh-my-opencode Guide](https://github.com/code-yeongyu/oh-my-opencode)
- [LLM Router](https://github.com/horsleyb/llm-router)

## Support

- **Issues**: Open GitHub issue in this repository
- **Discussions**: Use GitHub Discussions for questions
- **OpenCode**: [OpenCode Discord](https://discord.gg/opencode)
- **MCP**: [MCP Community](https://github.com/modelcontextprotocol)

---

**Version**: 1.0.0
**Last Updated**: 2026-01-01
