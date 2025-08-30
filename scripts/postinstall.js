#!/usr/bin/env node
// Post-install script for NPM package

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

console.log('🚀 Setting up LLM Family Pack v4.0.0...\n');

try {
  // Create bin directory and make scripts executable
  const binDir = path.join(__dirname, '..', 'bin');
  if (!fs.existsSync(binDir)) {
    fs.mkdirSync(binDir, { recursive: true });
  }

  // Copy and make executable
  const scripts = ['llm', 'claude-plus', 'smart-plus', 'llm-router', 'backup.sh'];
  scripts.forEach(script => {
    const srcPath = path.join(__dirname, '..', script);
    const destPath = path.join(binDir, script);
    
    if (fs.existsSync(srcPath)) {
      fs.copyFileSync(srcPath, destPath);
      try {
        fs.chmodSync(destPath, '755');
      } catch (err) {
        console.warn(`Warning: Could not make ${script} executable:`, err.message);
      }
    }
  });

  // Create config directory
  const configDir = path.join(os.homedir(), '.config', 'litellm');
  if (!fs.existsSync(configDir)) {
    fs.mkdirSync(configDir, { recursive: true });
    console.log('✓ Created configuration directory');
  }

  // Check for UV installation
  try {
    execSync('uv --version', { stdio: 'ignore' });
    console.log('✓ UV package manager found');
  } catch (err) {
    console.log('⚠ UV package manager not found. Installing...');
    try {
      execSync('curl -fsSL https://astral.sh/uv/install.sh | sh', { stdio: 'inherit' });
      console.log('✓ UV package manager installed');
    } catch (installErr) {
      console.warn('Warning: Could not install UV package manager automatically');
      console.warn('Please install manually: https://docs.astral.sh/uv/getting-started/installation/');
    }
  }

  console.log('\n🎉 LLM Family Pack installed successfully!\n');
  console.log('Next steps:');
  console.log('  1. Configure API keys: nano ~/.config/litellm/env');
  console.log('  2. Start service: llm start');
  console.log('  3. Run diagnostics: llm doctor');
  console.log('  4. Explore routing: llm-router --help\n');
  
} catch (err) {
  console.error('❌ Installation failed:', err.message);
  process.exit(1);
}