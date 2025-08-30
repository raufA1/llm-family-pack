class LlmFamilyPack < Formula
  desc "Enterprise-grade LiteLLM Proxy with Advanced Routing & Load Balancing"
  homepage "https://github.com/raufA1/llm-family-pack"
  url "https://github.com/raufA1/llm-family-pack/archive/v4.0.0.tar.gz"
  sha256 "your-sha256-hash-here"  # Replace with actual SHA256
  license "MIT"
  version "4.0.0"

  depends_on "curl"
  depends_on "bash"
  depends_on "python3"
  depends_on "jq"
  depends_on "yq"
  depends_on "bc"

  def install
    # Install main executables
    bin.install "llm"
    bin.install "claude-plus" => "claude+"
    bin.install "smart-plus" => "smart+"
    bin.install "llm-router"
    bin.install "backup.sh" => "litellm-backup"

    # Install library files
    (lib/"llm-family-pack").install Dir["lib/*"]
    
    # Install test framework
    (share/"llm-family-pack").install Dir["tests/*"]
    
    # Install configuration files
    (etc/"llm-family-pack").install "config.yaml"
    (etc/"llm-family-pack").install "env.example"
    
    # Install documentation
    doc.install "README.md"
    doc.install "LICENSE"
  end

  def post_install
    # Create config directory
    (var/"lib/llm-family-pack").mkpath
    
    # Install UV if not present
    unless which("uv")
      system "curl", "-fsSL", "https://astral.sh/uv/install.sh", "|", "sh"
    end
  end

  service do
    run [opt_bin/"llm", "start"]
    environment_variables LITELLM_DISABLE_DB: "true"
    keep_alive true
    log_path var/"log/llm-family-pack.log"
    error_log_path var/"log/llm-family-pack-error.log"
  end

  test do
    # Test basic functionality
    assert_match "LLM Family Pack", shell_output("#{bin}/llm --version")
    assert_match "LLM Router", shell_output("#{bin}/llm-router --version")
    
    # Test configuration
    system bin/"llm-router", "config", "validate"
  end
end