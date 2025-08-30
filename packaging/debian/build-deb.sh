#!/usr/bin/env bash
# Build .deb package for LLM Family Pack
# Version: 4.0.0

set -euo pipefail

PACKAGE_NAME="llm-family-pack"
VERSION="4.0.0"
ARCHITECTURE="all"
MAINTAINER="LLM Family Pack <support@example.com>"
DESCRIPTION="Enterprise-grade LiteLLM Proxy with Advanced Routing & Load Balancing"

# Create package structure
PACKAGE_DIR="packaging/debian/${PACKAGE_NAME}_${VERSION}_${ARCHITECTURE}"
DEBIAN_DIR="${PACKAGE_DIR}/DEBIAN"
INSTALL_DIR="${PACKAGE_DIR}/usr/local/bin"
LIB_DIR="${PACKAGE_DIR}/usr/local/lib/llm-family-pack"
SYSTEMD_DIR="${PACKAGE_DIR}/lib/systemd/user"
DOCS_DIR="${PACKAGE_DIR}/usr/share/doc/${PACKAGE_NAME}"

# Clean previous builds
rm -rf "${PACKAGE_DIR}"

# Create directory structure
mkdir -p "${DEBIAN_DIR}" "${INSTALL_DIR}" "${LIB_DIR}" "${SYSTEMD_DIR}" "${DOCS_DIR}"

# Create control file
cat > "${DEBIAN_DIR}/control" <<EOF
Package: ${PACKAGE_NAME}
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: ${ARCHITECTURE}
Depends: curl, bash, python3, python3-pip, jq, bc
Maintainer: ${MAINTAINER}
Description: ${DESCRIPTION}
 LLM Family Pack is an enterprise-grade LiteLLM Proxy toolkit with advanced
 routing and load balancing capabilities. Features include:
 .
 - Smart routing with 5 load balancing algorithms
 - Intelligent failover and circuit breakers  
 - Cost optimization (99%+ savings possible)
 - Health monitoring and analytics
 - Professional CLI tools (llm, llm-router, claude+, smart+)
 .
 Perfect for production AI deployments requiring reliability and cost control.
Homepage: https://github.com/raufA1/llm-family-pack
EOF

# Create postinst script
cat > "${DEBIAN_DIR}/postinst" <<'EOF'
#!/bin/bash
set -e

# Install UV package manager if not present
if ! command -v uv >/dev/null 2>&1; then
    curl -fsSL https://astral.sh/uv/install.sh | sh
fi

# Create config directory
mkdir -p "$HOME/.config/litellm"

# Set up systemd user service
systemctl --user daemon-reload || true

echo "LLM Family Pack installed successfully!"
echo "Next steps:"
echo "  1. Configure API keys: nano ~/.config/litellm/env"
echo "  2. Start service: llm start"
echo "  3. Run diagnostics: llm doctor"
EOF

# Create prerm script  
cat > "${DEBIAN_DIR}/prerm" <<'EOF'
#!/bin/bash
set -e

# Stop service if running
llm stop 2>/dev/null || true

# Stop health monitor if running
llm-router health stop 2>/dev/null || true
EOF

# Make scripts executable
chmod 755 "${DEBIAN_DIR}/postinst" "${DEBIAN_DIR}/prerm"

# Copy application files
cp llm claude-plus smart-plus llm-router backup.sh "${INSTALL_DIR}/"
cp -r lib/* "${LIB_DIR}/"
cp -r tests "${LIB_DIR}/"

# Copy documentation
cp README.md LICENSE "${DOCS_DIR}/"
cp config.yaml env.example "${DOCS_DIR}/"

# Make executables
chmod +x "${INSTALL_DIR}"/*

# Build the package
dpkg-deb --build "${PACKAGE_DIR}"

echo "✅ Debian package created: ${PACKAGE_DIR}.deb"
echo "📦 Install with: sudo dpkg -i ${PACKAGE_DIR}.deb"