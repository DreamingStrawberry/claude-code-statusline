#!/usr/bin/env node
// cc-statusbar entry point
// No args + TTY → open config TUI
// No args + pipe (statusline calling us) → exit 0 silently
// With args → run CLI (install/uninstall/help)

const cmd = process.argv[2];

if (!cmd) {
  if (!process.stdin.isTTY) {
    // Called as statusline command by mistake - exit gracefully
    process.exit(0);
  }
  require('./config-ui.js');
} else {
  require('./cli.js');
}
