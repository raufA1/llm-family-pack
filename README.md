# LLM Family Pack v3

A local **LiteLLM Proxy + CLI toolkit** designed for seamless model management and developer workflows.

## ✨ Features
- `llm` — manage models & control the proxy (start/stop/status, add/remove models, diagnostics).
- `claude+` — Claude Code CLI wrapper (with local→cloud fallback).
- `smart+` — Smart CLI wrapper for extended workflows.
- **Automatic alias masking** (`llm auto-claude`) → any backend model is exposed as `sonnet 4` for Claude compatibility.
- **Self-healing tools** (`llm doctor`, `llm fix`, `llm tidy`).
- **Secure API key handling** (env file with chmod 600).
- **Backup utility** — archive configs into `.tar.gz` with a single command.

## 🚀 Quick Start
```bash
cd llm-family-pack
bash install.sh

nano ~/.config/litellm/env   # Add your API key
chmod 600 ~/.config/litellm/env
llm start && llm doctor
claude+
