FROM ubuntu:22.04

LABEL maintainer="LLM Family Pack"
LABEL description="Enterprise-grade LiteLLM Proxy with Advanced Routing & Load Balancing"
LABEL version="4.0.0"

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    bash \
    python3 \
    python3-pip \
    jq \
    yq \
    bc \
    netcat \
    systemd \
    && rm -rf /var/lib/apt/lists/*

# Install UV for Python package management
RUN curl -fsSL https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# Create application directory
WORKDIR /app

# Copy application files
COPY . /app/

# Make scripts executable
RUN chmod +x /app/llm \
    /app/claude-plus \
    /app/smart-plus \
    /app/llm-router \
    /app/backup.sh \
    /app/install.sh

# Create necessary directories
RUN mkdir -p /root/.config/litellm \
    /root/.local/share/llm-family-pack/tests

# Install application
RUN /app/install.sh

# Expose LiteLLM proxy port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:4000/health || exit 1

# Default command
CMD ["llm", "start", "&&", "tail", "-f", "/dev/null"]

# Environment variables
ENV LITELLM_DISABLE_DB=true
ENV LLM_FAMILY_PACK_VERSION=4.0.0