#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const home = process.env.HOME || process.env.USERPROFILE;
const claudeDir = path.join(home, '.claude');
const settingsPath = path.join(claudeDir, 'settings.json');
const scriptDest = path.join(claudeDir, 'statusline.sh');
const confDest = path.join(claudeDir, 'statusline.conf');
const scriptSrc = path.join(__dirname, 'statusline.sh');
const scriptPsSrc = path.join(__dirname, 'statusline.ps1');
const scriptPsDest = path.join(claudeDir, 'statusline.ps1');
const confSrc = path.join(__dirname, 'statusline.conf.example');

const cmd = process.argv[2];

function install() {
  if (!fs.existsSync(claudeDir)) fs.mkdirSync(claudeDir, { recursive: true });

  // Copy both statusline.sh and statusline.ps1
  fs.copyFileSync(scriptSrc, scriptDest);
  try { fs.chmodSync(scriptDest, 0o755); } catch (e) {}
  fs.copyFileSync(scriptPsSrc, scriptPsDest);
  console.log(`Copied statusline.sh -> ${scriptDest}`);
  console.log(`Copied statusline.ps1 -> ${scriptPsDest}`);

  // Copy example config if no config exists
  if (!fs.existsSync(confDest)) {
    fs.copyFileSync(confSrc, confDest);
    console.log(`Copied statusline.conf.example -> ${confDest}`);
  }


  // Update settings.json
  let settings = {};
  if (fs.existsSync(settingsPath)) {
    try { settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8')); } catch (e) {}
  }

  const isWSL = process.platform === 'linux' && fs.existsSync('/proc/version') &&
    fs.readFileSync('/proc/version', 'utf8').toLowerCase().includes('microsoft');
  const isWindows = process.platform === 'win32';

  let shellCmd;
  if (isWSL) {
    shellCmd = `bash ${scriptDest}`;
  } else if (isWindows) {
    shellCmd = `powershell -NoProfile -ExecutionPolicy Bypass -File "${scriptPsDest}"`;
  } else {
    shellCmd = `bash ~/.claude/statusline.sh`;
  }

  settings.statusLine = {
    type: 'command',
    command: shellCmd,
    refreshInterval: 3
  };

  fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + '\n');
  console.log(`Updated ${settingsPath}`);
  console.log('\nDone! Restart Claude Code to see the status line.');
  console.log('Edit ~/.claude/statusline.conf to customize.\n');
  console.log('Shows: Model | Path@Branch | Context% | 5h limit | 7d limit | Cost');
  console.log('       + DevLauncher services (if installed)');
}

function uninstall() {
  if (fs.existsSync(scriptDest)) {
    fs.unlinkSync(scriptDest);
    console.log(`Removed ${scriptDest}`);
  }
  if (fs.existsSync(settingsPath)) {
    try {
      const settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
      delete settings.statusLine;
      fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + '\n');
      console.log(`Removed statusLine from ${settingsPath}`);
    } catch (e) {}
  }
  console.log('Uninstalled. Restart Claude Code to apply.');
}

function showHelp() {
  console.log(`claude-code-statusline - Status line for Claude Code

Usage:
  npx claude-code-statusline install     Install status line
  npx claude-code-statusline uninstall   Remove status line
  npx claude-code-statusline update      Update to latest version
  npx claude-code-statusline help        Show this help

Config: ~/.claude/statusline.conf
Repo:   https://github.com/DreamingStrawberry/claude-code-statusline`);
}

switch (cmd) {
  case 'install': case undefined: install(); break;
  case 'uninstall': case 'remove': uninstall(); break;
  case 'update': install(); break;
  case 'help': case '--help': case '-h': showHelp(); break;
  default: console.log(`Unknown command: ${cmd}. Use 'help' for usage.`); process.exit(1);
}
