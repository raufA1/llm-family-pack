#!/usr/bin/env bash
set -euo pipefail
FULL="${1:-}"
systemctl --user stop litellm.service 2>/dev/null || true
systemctl --user disable litellm.service 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/litellm.service" || true
systemctl --user daemon-reload 2>/dev/null || true
rm -f "$HOME/bin/llm" "$HOME/bin/claude+" "$HOME/bin/smart+" || true
if [ -x "$HOME/.local/bin/llm" ]; then
  ts=$(date +%s); mv "$HOME/.local/bin/llm" "$HOME/.local/bin/llm.bak.$ts" || true
fi
if [ "$FULL" = "--full" ]; then rm -rf "$HOME/.config/litellm"; else echo "[=] Kept ~/.config/litellm (use --full to remove)"; fi
echo "[+] Clean complete."
