#!/usr/bin/env bash
# Build all package formats for LLM Family Pack
# Version: 4.0.0

set -euo pipefail

VERSION="4.0.0"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/dist"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo -e "${BLUE}[SECTION]${NC} $1"
    echo -e "${BLUE}================================${NC}"
}

# Clean previous builds
clean_build_dir() {
    log_info "Cleaning build directory..."
    rm -rf "${BUILD_DIR}"
    mkdir -p "${BUILD_DIR}"
}

# Build Docker image
build_docker() {
    log_section "Building Docker Image"
    
    if command -v docker >/dev/null 2>&1; then
        cd "${PROJECT_DIR}"
        
        # Build image
        docker build -t "llm-family-pack:${VERSION}" -t "llm-family-pack:latest" .
        
        # Save as tar
        docker save "llm-family-pack:${VERSION}" | gzip > "${BUILD_DIR}/llm-family-pack-${VERSION}-docker.tar.gz"
        
        log_info "Docker image built and saved to ${BUILD_DIR}/llm-family-pack-${VERSION}-docker.tar.gz"
    else
        log_warn "Docker not found, skipping Docker build"
    fi
}

# Build Debian package
build_debian() {
    log_section "Building Debian Package"
    
    if command -v dpkg-deb >/dev/null 2>&1; then
        cd "${PROJECT_DIR}"
        chmod +x packaging/debian/build-deb.sh
        ./packaging/debian/build-deb.sh
        
        # Move to dist directory
        mv packaging/debian/llm-family-pack_${VERSION}_all.deb "${BUILD_DIR}/"
        
        log_info "Debian package built: ${BUILD_DIR}/llm-family-pack_${VERSION}_all.deb"
    else
        log_warn "dpkg-deb not found, skipping Debian package build"
    fi
}

# Build Snap package
build_snap() {
    log_section "Building Snap Package"
    
    if command -v snapcraft >/dev/null 2>&1; then
        cd "${PROJECT_DIR}"
        snapcraft
        
        # Move to dist directory
        mv "llm-family-pack_${VERSION}_amd64.snap" "${BUILD_DIR}/"
        
        log_info "Snap package built: ${BUILD_DIR}/llm-family-pack_${VERSION}_amd64.snap"
    else
        log_warn "snapcraft not found, skipping Snap package build"
    fi
}

# Prepare NPM package
build_npm() {
    log_section "Preparing NPM Package"
    
    if command -v npm >/dev/null 2>&1; then
        cd "${PROJECT_DIR}"
        
        # Create bin directory
        mkdir -p bin
        cp llm claude-plus smart-plus llm-router backup.sh bin/
        
        # Pack the package
        npm pack
        
        # Move to dist directory
        mv "llm-family-pack-${VERSION}.tgz" "${BUILD_DIR}/"
        
        log_info "NPM package built: ${BUILD_DIR}/llm-family-pack-${VERSION}.tgz"
        
        # Cleanup
        rm -rf bin/
    else
        log_warn "npm not found, skipping NPM package build"
    fi
}

# Create source archive
build_source() {
    log_section "Creating Source Archive"
    
    cd "${PROJECT_DIR}"
    
    # Create source tarball
    git archive --format=tar.gz --prefix="llm-family-pack-${VERSION}/" HEAD > "${BUILD_DIR}/llm-family-pack-${VERSION}-source.tar.gz"
    
    # Create zip archive
    git archive --format=zip --prefix="llm-family-pack-${VERSION}/" HEAD > "${BUILD_DIR}/llm-family-pack-${VERSION}-source.zip"
    
    log_info "Source archives created"
}

# Generate SHA256 checksums
generate_checksums() {
    log_section "Generating Checksums"
    
    cd "${BUILD_DIR}"
    
    # Generate SHA256 checksums
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum * > SHA256SUMS
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 * > SHA256SUMS
    else
        log_warn "No SHA256 utility found, skipping checksums"
        return
    fi
    
    log_info "SHA256 checksums generated: SHA256SUMS"
}

# Create release notes
create_release_notes() {
    log_section "Creating Release Notes"
    
    cat > "${BUILD_DIR}/RELEASE_NOTES.md" <<EOF
# LLM Family Pack v${VERSION} Release

## 🚦 Advanced Routing & Load Balancing System

This major release introduces enterprise-grade routing capabilities with intelligent load balancing, failover mechanisms, and cost optimization.

### ✨ New Features

- **5 Load Balancing Algorithms**: Round robin, weighted, least connections, cost-optimized, latency-based
- **Intelligent Failover**: Automatic backup routing with circuit breakers  
- **Cost Optimization**: Route to cheapest models (99%+ savings possible)
- **Health Monitoring**: Real-time endpoint monitoring with auto-recovery
- **Route Analytics**: Detailed statistics and cost analysis
- **Dynamic Configuration**: Hot-reload routing rules without downtime

### 📦 Installation Options

#### Docker
\`\`\`bash
docker load < llm-family-pack-${VERSION}-docker.tar.gz
docker run -d -p 4000:4000 llm-family-pack:${VERSION}
\`\`\`

#### Debian/Ubuntu
\`\`\`bash
sudo dpkg -i llm-family-pack_${VERSION}_all.deb
\`\`\`

#### Snap (Universal Linux)
\`\`\`bash
sudo snap install llm-family-pack_${VERSION}_amd64.snap --dangerous
\`\`\`

#### NPM
\`\`\`bash
npm install -g llm-family-pack-${VERSION}.tgz
\`\`\`

#### Source
\`\`\`bash
tar -xzf llm-family-pack-${VERSION}-source.tar.gz
cd llm-family-pack-${VERSION}
bash install.sh
\`\`\`

### 🎯 Quick Start

1. Install using preferred method above
2. Configure API keys: \`nano ~/.config/litellm/env\`
3. Start service: \`llm start\`
4. Explore routing: \`llm-router --help\`

### 💰 Cost Optimization Example

\`\`\`bash
# Route GPT-4 requests to 99% cheaper alternatives
llm-router add gpt-4 primary openrouter/openai/gpt-4 openrouter 1 20 30.0
llm-router add gpt-4 cheap openrouter/qwen/qwen2.5-coder openrouter 2 80 0.27
llm-router algorithm gpt-4 cost_optimized
\`\`\`

### 🔧 Technical Details

- New CLI tool: \`llm-router\` with comprehensive route management
- YAML-based configuration system with validation
- JSON state management for runtime analytics  
- Background health monitoring daemon
- Circuit breaker pattern for failover protection

For full documentation, see: https://github.com/raufA1/llm-family-pack
EOF

    log_info "Release notes created: RELEASE_NOTES.md"
}

# Main build process
main() {
    log_section "Building LLM Family Pack v${VERSION} - All Packages"
    
    clean_build_dir
    
    # Build all package formats
    build_docker
    build_debian  
    build_snap
    build_npm
    build_source
    
    # Generate checksums and release notes
    generate_checksums
    create_release_notes
    
    log_section "Build Summary"
    log_info "All packages built successfully in: ${BUILD_DIR}"
    
    # List all built packages
    echo
    echo "📦 Built Packages:"
    ls -la "${BUILD_DIR}"
    
    echo
    log_info "Ready for distribution! 🚀"
}

# Run main function
main "$@"