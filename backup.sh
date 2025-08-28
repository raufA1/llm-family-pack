#!/usr/bin/env bash
set -euo pipefail
TS="$(date +%Y%m%d-%H%M%S)"
OUT="$HOME/litellm-backup-$TS.tar.gz"
tar -czf "$OUT" \
  -C "$HOME" \
  ".config/litellm/env" \
  ".config/litellm/config.yaml" \
  ".config/litellm/default_model" 2>/dev/null || true
if [ -f "$HOME/.config/systemd/user/litellm.service" ]; then
  tar -rzf "$OUT" -C "$HOME" ".config/systemd/user/litellm.service"
fi
echo "[+] Wrote backup to: $OUT"
