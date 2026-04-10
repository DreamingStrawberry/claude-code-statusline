#!/usr/bin/env node
// cc-status-bar entry point
// No args → open config TUI
// With args → run CLI (install/uninstall/help)

const cmd = process.argv[2];

if (!cmd) {
  // Default: open config TUI
  require('./config-ui.js');
} else {
  require('./cli.js');
}
