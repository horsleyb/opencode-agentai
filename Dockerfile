# OpenCode AgentAI Docker Image
# Comprehensive AI coding assistant with oh-my-opencode and MCP servers
# Base image is Alpine Linux

FROM ghcr.io/sst/opencode:latest AS base

# Set environment variables
ENV GO_VERSION=1.22.5
ENV JAVA_VERSION=21

# Install glibc compatibility for bun-pty (Alpine uses musl, bun-pty needs glibc)
RUN apk add --no-cache gcompat libc6-compat

# Install system dependencies (Alpine uses apk)
RUN apk add --no-cache \
    build-base \
    gcc \
    g++ \
    make \
    cmake \
    pkgconfig \
    git \
    curl \
    wget \
    ca-certificates \
    gnupg \
    jq \
    ripgrep \
    fd \
    tree \
    htop \
    vim \
    bash \
    openssh-client \
    openssl-dev \
    libffi-dev \
    python3-dev \
    py3-pip \
    nodejs \
    npm \
    nginx \
    libstdc++

# Install Bun (required for oh-my-opencode)
RUN if ! command -v bun > /dev/null 2>&1; then \
    curl -fsSL https://bun.sh/install | bash && \
    mkdir -p /etc/profile.d && \
    echo 'export BUN_INSTALL="$HOME/.bun"' >> /etc/profile.d/bun.sh && \
    echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> /etc/profile.d/bun.sh; \
    fi

ENV BUN_INSTALL="/root/.bun"
ENV PATH="${BUN_INSTALL}/bin:${PATH}"

# Install Go
RUN curl -fsSL https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz | tar -C /usr/local -xzf -
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/root/go"
ENV PATH="${GOPATH}/bin:${PATH}"

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Install OpenJDK (Alpine package)
RUN apk add --no-cache openjdk${JAVA_VERSION}-jdk
ENV JAVA_HOME="/usr/lib/jvm/java-${JAVA_VERSION}-openjdk"
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# Install MCP servers and AI SDK packages globally
RUN npm install -g \
    @modelcontextprotocol/server-filesystem \
    @modelcontextprotocol/server-github \
    @modelcontextprotocol/server-memory \
    @modelcontextprotocol/server-sequential-thinking \
    @ai-sdk/openai-compatible

# Install oh-my-opencode
RUN bunx oh-my-opencode install --yes 2>/dev/null || npm exec -y oh-my-opencode install --yes 2>/dev/null || true

# Create workspace and config directories
RUN mkdir -p /workspace /root/.config/opencode /root/.opencode /run/nginx

# Copy configuration files
COPY config/opencode.json /root/.config/opencode/opencode.json
COPY config/nginx.conf /etc/nginx/http.d/opencode.conf
COPY scripts/entrypoint.sh /entrypoint.sh

# Make entrypoint executable
RUN chmod +x /entrypoint.sh

# Set working directory
WORKDIR /workspace

# Expose ports (4097 = nginx proxy, 4096 = opencode internal)
EXPOSE 4097

# Health check through nginx proxy
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:4097/health || exit 1

# Labels
LABEL org.opencontainers.image.title="OpenCode AgentAI"
LABEL org.opencontainers.image.description="AI coding assistant with oh-my-opencode and MCP servers"
LABEL org.opencontainers.image.source="https://github.com/sst/opencode"

# Entrypoint
ENTRYPOINT ["/entrypoint.sh"]
CMD ["opencode", "serve", "--hostname", "127.0.0.1", "--port", "4096"]
