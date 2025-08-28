#!/usr/bin/env bash
set -euo pipefail
bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/clean.sh" "${1:-}"
echo "[+] Uninstall complete."
