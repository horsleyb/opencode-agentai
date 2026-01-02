# CLAUDE.md - OpenCode AgentAI

Project guidance for Claude Code when working with this Docker container project.

**Last Updated**: 2026-01-01

## Project Overview

OpenCode AgentAI is a containerized AI coding assistant based on [SST OpenCode](https://opencode.ai) with:
- **oh-my-opencode** plugin for enhanced capabilities
- **6 MCP servers** (filesystem, git, github, fetch, memory, sequential-thinking)
- **Multi-language runtimes**: Node.js 20, Python 3.11, Go 1.22.5, Rust, Java 21

## Quick Reference

### Build & Run

```bash
# Build and start container
docker-compose up -d --build

# View logs
docker-compose logs -f opencode

# Access TUI interactively
docker exec -it opencode-agentai opencode

# Shell into container
docker exec -it opencode-agentai bash

# Stop and remove
docker-compose down
```

### Project Structure

```
opencode-agentai/
├── Dockerfile              # Multi-stage image (base: ghcr.io/sst/opencode:latest)
├── docker-compose.yml      # Container orchestration (host network mode)
├── .env.example            # Environment template → copy to .env
├── config/
│   └── opencode.json       # OpenCode config (models, MCP servers, LSP)
├── scripts/
│   └── entrypoint.sh       # Container initialization script
├── workspace/              # Mounted code projects (persistent)
└── README.md               # Full documentation
```

### Key Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Image definition with language runtimes and MCP servers |
| `docker-compose.yml` | Service config, volumes, networking |
| `config/opencode.json` | Model selection, providers, MCP servers, tools |
| `scripts/entrypoint.sh` | Startup: MCP install, config updates, server launch |
| `.env` | API keys and LLM backend URLs |

## Development Guidelines

### Docker/DevOps Patterns

1. **Image Layers**: Dockerfile uses single `apt-get` command to minimize layers
2. **Network Mode**: Uses `network_mode: host` for localhost LLM access
3. **Volumes**:
   - `./workspace` → `/workspace` (code projects)
   - `./config` → `/root/.config/opencode:ro` (read-only config)
   - `opencode-state` → named volume for cache/state
4. **Health Check**: `curl -f http://localhost:4097/health`
5. **Resource Limits**: 8GB max, 2GB reserved memory

### Configuration Updates

When modifying `config/opencode.json`:

```bash
# Validate JSON syntax
cat config/opencode.json | jq .

# Restart to apply changes
docker-compose restart opencode
```

### Environment Variables

Required in `.env`:
```bash
# At least one LLM backend
ANTHROPIC_API_KEY=sk-ant-...    # Cloud: Claude
LLM_ROUTER_URL=http://localhost:8000  # Local: LLM Router
OLLAMA_URL=http://localhost:11434     # Local: Ollama

# Optional
GITHUB_TOKEN=ghp_...            # MCP GitHub server
EXA_API_KEY=...                 # oh-my-opencode search
```

### MCP Server Management

Pre-installed servers via npm global:
- `@modelcontextprotocol/server-filesystem` → scoped to `/workspace`
- `@modelcontextprotocol/server-git`
- `@modelcontextprotocol/server-github` → requires `GITHUB_TOKEN`
- `@modelcontextprotocol/server-fetch`
- `@modelcontextprotocol/server-memory`
- `@modelcontextprotocol/server-sequential-thinking`

Add new MCP server:
1. Add to `Dockerfile`: `RUN npm install -g @your/mcp-server`
2. Add to `config/opencode.json` under `mcp` section
3. Rebuild: `docker-compose build --no-cache`

### LSP Support

Enabled for all runtimes in `config/opencode.json`:
```json
"lsp": {
  "typescript": { "disabled": false },
  "python": { "disabled": false },
  "go": { "disabled": false },
  "rust": { "disabled": false },
  "java": { "disabled": false }
}
```

## Common Tasks

### Rebuild After Dockerfile Changes

```bash
docker-compose build --no-cache
docker-compose up -d
```

### Debug Container Startup

```bash
# Run entrypoint manually
docker run -it --rm \
  -v $(pwd)/config:/root/.config/opencode:ro \
  opencode-agentai:latest \
  /bin/bash -c "/entrypoint.sh"
```

### Test LLM Connectivity

```bash
# Inside container
curl http://localhost:8000/v1/models      # LLM Router
curl http://localhost:11434/api/tags      # Ollama
```

### Validate MCP Servers

```bash
# Check MCP server processes
docker exec opencode-agentai ps aux | grep mcp

# View MCP logs
docker exec opencode-agentai cat /root/.opencode/mcp.log
```

### Switch Models

Edit `config/opencode.json`:
```json
{
  "model": "anthropic/claude-sonnet-4-5",      // Main model
  "small_model": "anthropic/claude-haiku-4-5"  // Fast model
}
```

For local models via LLM Router:
```json
{
  "model": "openai-compatible/qwen2.5:7b",
  "provider": {
    "openai-compatible": {
      "options": { "baseURL": "http://localhost:8000/v1" }
    }
  }
}
```

## Troubleshooting

### Container Won't Start

```bash
# Check build logs
docker-compose build 2>&1 | tee build.log

# Check container logs
docker-compose logs opencode

# Verify port availability
netstat -an | grep 4096
```

### LLM Connection Refused

1. Verify host services are running
2. Check network mode in `docker-compose.yml`
3. On Windows: use `host.docker.internal` instead of `localhost`

### Permission Denied on Workspace

```bash
# Fix ownership
sudo chown -R $(id -u):$(id -g) workspace/
```

### MCP Server Errors

```bash
# Reinstall MCP servers
docker exec opencode-agentai npm install -g @modelcontextprotocol/server-filesystem

# Check environment variables
docker exec opencode-agentai env | grep -E "(GITHUB|EXA)"
```

## Integration with Local LLM Infrastructure

This project connects to local LLM services defined in workspace CLAUDE.md:

| Service | Port | Purpose |
|---------|------|---------|
| LLM Router | 8000 | Unified gateway |
| Ollama | 11434 | NVIDIA GPU inference |
| Lemonade Server | 8001 | AMD NPU inference |
| Docker Model Runner | 12434 | CPU fallback |

## Testing

```bash
# Health check
curl http://localhost:4096/health

# Full integration test
docker exec opencode-agentai opencode --version
```

## Build Arguments

The Dockerfile supports these environment variables:
- `NODE_VERSION=20`
- `GO_VERSION=1.22.5`
- `PYTHON_VERSION=3.11`

To override:
```bash
docker build --build-arg GO_VERSION=1.23.0 -t opencode-agentai .
```

## Exposed Ports

| Port | Service |
|------|---------|
| 4097 | OpenCode server (nginx proxy) |

## Labels

```
org.opencontainers.image.title=OpenCode AgentAI
org.opencontainers.image.description=AI coding assistant with oh-my-opencode and MCP servers
org.opencontainers.image.source=https://github.com/sst/opencode
```

## Claude 007 Agents Integration

**Bootstrapped**: 2026-01-01 | **Complexity**: 7/10 | **Agents**: Symlinked from `C:\projects\claude-007-agents`

### Recommended Agents for This Project

#### Core (Always Active)
| Agent | Purpose |
|-------|---------|
| `@orchestrator` | Multi-dimensional analysis and coordination |
| `@software-engineering-expert` | Code quality and architecture |
| `@code-reviewer` | Quality assurance and review |
| `@documentation-specialist` | Technical documentation |
| `@git-expert` | Version control and collaboration |

#### DevOps/Infrastructure
| Agent | Purpose |
|-------|---------|
| `@deployment-specialist` | CI/CD pipelines, deployment automation |
| `@cloud-architect` | Container orchestration, infrastructure design |
| `@devops-troubleshooter` | Container debugging, service issues |
| `@site-reliability-engineer` | Health checks, monitoring, reliability |
| `@terraform-specialist` | Infrastructure as code |

#### Backend/Multi-Language
| Agent | Purpose |
|-------|---------|
| `@nodejs-expert` | Node.js/npm packages, MCP servers |
| `@fastapi-expert` | Python async services |
| `@go-resilience-engineer` | Go services, fault tolerance |

#### Security
| Agent | Purpose |
|-------|---------|
| `@security-specialist` | Container security, secret management |
| `@devsecops-engineer` | Security automation, vulnerability scanning |

#### Context Orchestrators
| Agent | Purpose |
|-------|---------|
| `@vibe-coding-coordinator` | Autonomous development with 15-20 min prep |
| `@session-manager` | Context preservation across sessions |
| `@parallel-coordinator` | Multi-agent execution |

### Commit Attribution

All commits must include agent attribution:
```
🤖 Generated with [Claude Code](https://claude.ai/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
Agents: @deployment-specialist, @security-specialist
```

### Usage Examples

```bash
# Docker/Container work
claude "Use @deployment-specialist to optimize the Dockerfile build layers"
claude "Use @devops-troubleshooter to debug container networking issues"

# MCP server development
claude "Use @nodejs-expert to add a new MCP server to the configuration"

# Security review
claude "Use @security-specialist to audit the container security posture"

# Autonomous development
claude "Use @vibe-coding-coordinator to implement health check improvements"
```
