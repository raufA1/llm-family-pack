# LLM Family Pack v4.0.0

A **enterprise-grade LiteLLM Proxy + CLI toolkit** with **Advanced Routing & Load Balancing** for seamless AI model management and developer workflows.

## ✨ Features

### Core Components
- **`llm`** — Comprehensive model and proxy management with advanced diagnostics
- **`llm-router`** — **NEW!** Advanced routing & load balancing management
- **`claude+`** — Enhanced Claude Code CLI wrapper with intelligent local→cloud fallback
- **`smart+`** — Smart CLI wrapper with automatic proxy integration
- **Professional libraries** — Modular, tested utilities with routing support

### Advanced Capabilities
- **🚦 Smart Routing & Load Balancing** — Round robin, weighted, cost-optimized, latency-based algorithms
- **⚡ Intelligent Failover** — Automatic backup routes with circuit breakers
- **💰 Cost Optimization** — Route to cheapest models automatically (99%+ savings possible)
- **📈 Health Monitoring** — Real-time endpoint monitoring with auto-recovery
- **🔄 Automatic alias masking** — Any backend model exposed as `sonnet 4` for Claude compatibility
- **🏥 Self-healing diagnostics** — `llm doctor`, `llm fix`, intelligent error recovery
- **🔐 Enterprise-grade security** — Secure API key handling, proper file permissions
- **📊 Comprehensive logging** — Debug modes, detailed error tracking, audit trails
- **🧪 Testing framework** — Built-in test suite for reliability assurance
- **📦 Backup & restore** — Archive configurations with versioning support

## 🚀 Quick Start

### Installation
```bash
git clone <repository-url> llm-family-pack
cd llm-family-pack
bash install.sh
```

### Configuration
```bash
# Configure your API keys
nano ~/.config/litellm/env

# Example configuration:
OPENROUTER_API_KEY=sk-or-your-key-here
OPENAI_API_KEY=sk-your-openai-key-here
LITELLM_DISABLE_DB=true
```

### First Run
```bash
# Reload your shell to update PATH
exec $SHELL -l

# Start service and run diagnostics
llm start && llm doctor

# Test the enhanced CLI tools
claude+ --help
smart+ --help
```

## 📖 Documentation

### Core Commands

#### LLM Management (`llm`)
```bash
# Service management
llm start                    # Start LiteLLM proxy service
llm stop                     # Stop the service
llm restart                  # Restart the service
llm status                   # Show detailed status
llm logs [lines]             # View service logs

# Model management  
llm add                      # Interactive model addition wizard
llm list                     # List all configured models
llm change                   # Change default model
llm delete                   # Remove a model
llm test [model]             # Test model connectivity

# Maintenance
llm doctor                   # Comprehensive diagnostics
llm fix                      # Auto-fix common issues
llm tidy                     # Clean configuration formatting
llm cache clear              # Clear package cache

# Claude integration
llm auto-claude [backing]    # Auto-configure Claude aliases
llm ensure-claude [backing]  # Ensure Claude compatibility
```

#### Advanced Routing (`llm-router`)
```bash
# Route group management
llm-router list              # List all route groups
llm-router add gpt-4 primary openrouter/openai/gpt-4 openrouter 1 70 30.0
llm-router add gpt-4 fallback openrouter/qwen/qwen2.5-coder openrouter 2 30 0.27

# Load balancing algorithms
llm-router algorithm gpt-4 cost_optimized    # Route to cheapest model
llm-router algorithm claude weighted         # Use weighted distribution
llm-router algorithm coding round_robin      # Fair rotation

# Health monitoring
llm-router health start      # Start health monitoring daemon
llm-router health status     # Check monitoring status
llm-router health check      # Manual health check

# Testing and analytics
llm-router test gpt-4 100    # Test load balancing with 100 requests
llm-router stats gpt-4       # Show routing statistics
llm-router costs             # Cost analysis across routes

# Configuration management
llm-router config show       # Show routing configuration
llm-router config validate   # Validate configuration
llm-router config backup     # Backup routing rules
```

#### Enhanced CLI Wrappers
```bash
# Claude+ (Enhanced Claude CLI)
claude+ --status             # Show wrapper status
claude+ --help               # Show enhanced help
DEBUG=1 claude+ "query"      # Debug mode

# Smart+ (Enhanced Smart CLI)
smart+ --status              # Show wrapper status  
smart+ --help                # Show enhanced help
DEBUG=1 smart+ "query"       # Debug mode
```

### Advanced Features

#### Environment Variables
```bash
# Debug and logging
DEBUG=1                      # Enable debug output
CLAUDE_BACKING_ALIAS=model   # Default model for Claude+
SMART_BACKING_ALIAS=model    # Default model for Smart+

# API configuration
OPENROUTER_API_KEY=key       # OpenRouter API key
OPENAI_API_KEY=key           # OpenAI API key
ANTHROPIC_API_KEY=key        # Anthropic API key
```

#### Testing Framework
```bash
# Run comprehensive tests
~/.local/share/llm-family-pack/tests/test_framework.sh run

# List available tests
~/.local/share/llm-family-pack/tests/test_framework.sh list
```

#### Backup & Recovery
```bash
# Create timestamped backup
litellm-backup

# Backup includes:
# - ~/.config/litellm/env (API keys)
# - ~/.config/litellm/config.yaml (model configurations)
# - ~/.config/litellm/default_model (default selection)
# - systemd service file
```

## 🏗️ Architecture

### Directory Structure
```
llm-family-pack/
├── llm                      # Main CLI tool
├── claude-plus              # Enhanced Claude wrapper
├── smart-plus               # Enhanced Smart wrapper
├── lib/                     # Professional utilities library
│   ├── common.sh           # Core utilities and logging
│   ├── model_manager.sh    # Model configuration management
│   ├── service_manager.sh  # Service lifecycle management
│   └── router.sh           # Advanced routing and load balancing
├── tests/                   # Comprehensive test suite
│   ├── test_framework.sh   # Test runner and assertions
│   ├── test_common.sh      # Common utilities tests
│   └── test_model_manager.sh # Model management tests
├── install.sh              # Enhanced installer
├── backup.sh               # Backup utility
└── config.yaml             # Default configuration
```

### Key Improvements in v4.0.0

#### **🚦 Advanced Routing System (NEW!)**
- **Load Balancing Algorithms** — Round robin, weighted, cost-optimized, latency-based
- **Intelligent Failover** — Automatic backup routing with circuit breakers  
- **Health Monitoring** — Real-time endpoint health checks with auto-recovery
- **Route Analytics** — Detailed statistics and cost analysis
- **Dynamic Configuration** — Hot-reload routing rules without downtime

### Previous Improvements (v3.0.0)

#### Professional Architecture
- **Modular design** — Separated concerns into specialized libraries
- **Comprehensive error handling** — Proper validation and graceful failures
- **Advanced logging** — Color-coded output with debug modes
- **Testing framework** — Built-in test suite with assertions

#### Enhanced Reliability
- **Input validation** — All user inputs are validated and sanitized
- **Configuration management** — Robust YAML parsing and validation
- **Service monitoring** — Health checks and automatic recovery
- **Backup system** — Automated configuration archival

#### Developer Experience
- **Rich help systems** — Context-aware help and examples
- **Debug capabilities** — Detailed logging and troubleshooting
- **Status reporting** — Comprehensive system diagnostics
- **Easy customization** — Environment-based configuration
