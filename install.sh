#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/clean.sh" || true
BIN="$HOME/bin"
CFG_DIR="$HOME/.config/litellm"
ENVF="$CFG_DIR/env"
CFG="$CFG_DIR/config.yaml"
UNIT_DIR="$HOME/.config/systemd/user"
UNIT="$UNIT_DIR/litellm.service"
mkdir -p "$BIN" "$CFG_DIR" "$UNIT_DIR"
if ! command -v uv >/dev/null 2>&1; then
  curl -fsSL https://astral.sh/uv/install.sh | sh
  hash -r || true
fi
[ -f "$CFG" ] || cp -f "$SCRIPT_DIR/config.yaml" "$CFG"
if [ ! -f "$ENVF" ]; then
  cp -f "$SCRIPT_DIR/env.example" "$ENVF"; chmod 600 "$ENVF"
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
systemctl --user daemon-reload
install -m 755 "$SCRIPT_DIR/llm" "$BIN/llm"
install -m 755 "$SCRIPT_DIR/claude-plus" "$BIN/claude+"
install -m 755 "$SCRIPT_DIR/smart-plus" "$BIN/smart+"
install -m 755 "$SCRIPT_DIR/backup.sh" "$BIN/litellm-backup"
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$HOME/bin"; then
  if [ -f "$HOME/.bashrc" ] && ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
  fi
fi
echo "Install complete. Next:
  1) nano $ENVF   # set OPENROUTER_API_KEY
  2) chmod 600 $ENVF
  3) exec \$SHELL -l
  4) llm start && llm doctor
  5) claude+
  6) litellm-backup   # create a tar.gz backup anytime"
