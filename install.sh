#!/usr/bin/env bash
# LLM Family Pack Installer
# Version: 3.0.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/bin"
CFG_DIR="$HOME/.config/litellm"
ENVF="$CFG_DIR/env"
CFG="$CFG_DIR/config.yaml"
UNIT_DIR="$HOME/.config/systemd/user"
UNIT="$UNIT_DIR/litellm.service"
LIB_DIR="$BIN/lib"

echo "LLM Family Pack v3.0.0 Installer"
echo "================================="
echo

# Clean up any previous installation
bash "$SCRIPT_DIR/clean.sh" 2>/dev/null || true

# Create necessary directories
echo "Creating directories..."
mkdir -p "$BIN" "$CFG_DIR" "$UNIT_DIR" "$LIB_DIR"
# Install UV if not present
echo "Checking dependencies..."
if ! command -v uv >/dev/null 2>&1; then
  echo "Installing UV package manager..."
  curl -fsSL https://astral.sh/uv/install.sh | sh
  hash -r || true
else
  echo "UV package manager: Already installed"
fi

# Install library files
echo "Installing library files..."
if [ -d "$SCRIPT_DIR/lib" ]; then
  cp -r "$SCRIPT_DIR/lib/"* "$LIB_DIR/"
  chmod 644 "$LIB_DIR/"*.sh
  echo "Library files installed to $LIB_DIR"
else
  echo "Warning: lib directory not found in $SCRIPT_DIR"
fi

# Install configuration files
echo "Installing configuration files..."
[ -f "$CFG" ] || cp -f "$SCRIPT_DIR/config.yaml" "$CFG"

if [ ! -f "$ENVF" ]; then
  cp -f "$SCRIPT_DIR/env.example" "$ENVF"
  chmod 600 "$ENVF"
else
  grep -q '^LITELLM_DISABLE_DB=' "$ENVF" || echo 'LITELLM_DISABLE_DB=true' >> "$ENVF"
  chmod 600 "$ENVF" || true
fi
cat > "$UNIT" <<'SERVICE'
[Unit]
Description=LiteLLM Proxy (User)
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
EnvironmentFile=%h/.config/litellm/env
Environment=LITELLM_DISABLE_DB=true
ExecStart=%h/.local/bin/uv tool uvx --from "litellm[proxy]" --with "openai<1.100.0" litellm --port 4000 --host 127.0.0.1 --config %h/.config/litellm/config.yaml
Restart=always
RestartSec=2
SuccessExitStatus=143
WorkingDirectory=%h
[Install]
WantedBy=default.target
SERVICE
# Create systemd service
echo "Creating systemd service..."
systemctl --user daemon-reload

# Install executable files
echo "Installing executable files..."
install -m 755 "$SCRIPT_DIR/llm" "$BIN/llm"
install -m 755 "$SCRIPT_DIR/claude-plus" "$BIN/claude+"
install -m 755 "$SCRIPT_DIR/smart-plus" "$BIN/smart+"
install -m 755 "$SCRIPT_DIR/backup.sh" "$BIN/litellm-backup"
install -m 755 "$SCRIPT_DIR/llm-router" "$BIN/llm-router"

# Install test framework if available
if [ -d "$SCRIPT_DIR/tests" ]; then
  TEST_DIR="$HOME/.local/share/llm-family-pack/tests"
  mkdir -p "$TEST_DIR"
  cp -r "$SCRIPT_DIR/tests/"* "$TEST_DIR/"
  chmod +x "$TEST_DIR/"*.sh
  echo "Test framework installed to $TEST_DIR"
fi

# Update PATH if needed
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$HOME/bin"; then
  if [ -f "$HOME/.bashrc" ] && ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
    echo "Added $HOME/bin to PATH in ~/.bashrc"
  fi
fi

echo
echo "✓ Installation completed successfully!"
echo
echo "Next steps:"
echo "  1) Configure your API keys:"
echo "     nano $ENVF"
echo "  2) Reload your shell:"
echo "     exec \$SHELL -l"
echo "  3) Start the service and run diagnostics:"
echo "     llm start && llm doctor"
echo "  4) Test the CLI tools:"
echo "     claude+ --help"
echo "     smart+ --help"
echo "  5) Create a backup:"
echo "     litellm-backup"
echo
echo "For help: llm --help"
echo "For testing: $HOME/.local/share/llm-family-pack/tests/test_framework.sh run"
