# Claude Code Status Line

A real-time status bar for [Claude Code](https://claude.ai/claude-code) with rate limit tracking, context usage, and dev server monitoring.

```
Opus 4.6 (1M context) | myproject@main | 21% ●○○○○○ | 5h ●●○○○○ 45%(1h42m) | 7d ○○○○○○ 4%(166h42m) | $24.14
svc MW-Back:8080● MW-React:5190● CRM-Back:8085○ MWPF:8090⠙
```

## Install

```bash
npx claude-code-statusline install
```

Or manually:

```bash
git clone https://github.com/DreamingStrawberry/claude-code-statusline.git
cp claude-code-statusline/statusline.sh ~/.claude/statusline.sh
```

Add to `~/.claude/settings.json`:
```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline.sh",
    "refreshInterval": 1
  }
}
```

Restart Claude Code to apply.

## What it shows

| Section | Example | Description |
|---------|---------|-------------|
| Model | `Opus 4.6 (1M context)` | Current model and context window |
| Path | `myproject@main` | Directory + git branch |
| Context | `21% ●○○○○○` | Context window usage |
| 5h limit | `●●○○○○ 45%(1h42m)` | 5-hour rate limit + reset timer |
| 7d limit | `○○○○○○ 4%(166h42m)` | 7-day rate limit + reset timer |
| Cost | `$24.14` | Session cost |
| svc | `MW-Back:8080●` | Dev server status (optional) |

## Service states

| State | Display | Description |
|-------|---------|-------------|
| Running | `MW-Back:8080●` | Green name, green dot |
| Starting | `MW-Back:8080⠙` | Yellow, animated spinner (rotates every 1s) |
| Error | `MW-Back:8080✖` | Red, blinking |
| Stopped | `mw-back:8080○` | Gray, hollow dot |

## Configuration

Edit `~/.claude/statusline.conf`:

```bash
# Sections (true/false)
SHOW_MODEL=true
SHOW_PATH=true
SHOW_GIT_BRANCH=true
SHOW_CONTEXT=true
SHOW_5H_LIMIT=true
SHOW_7D_LIMIT=true
SHOW_COST=true
SHOW_DEVLAUNCHER=true

# DevLauncher path (auto-detected if empty)
# DEVLAUNCHER_PATH="/mnt/c/Users/YourName/DevLauncher.ps1"

# Bar style: "dots" or "blocks"
BAR_STYLE=dots

# Bar width
BAR_WIDTH=6
```

## Color coding

- Green: < 50%
- Yellow: 50-80%
- Red: > 80%

## Dev Server Launcher integration

Automatically detects [Dev Server Launcher](https://github.com/DreamingStrawberry/dev-server-launcher) if installed. Shows live service statuses with animated spinner for starting services and blinking icon for errors.

DevLauncher status is cached for 3 seconds to keep the 1s refresh lightweight.

## Commands

```bash
npx claude-code-statusline install     # Install
npx claude-code-statusline uninstall   # Remove
npx claude-code-statusline update      # Update script
npx claude-code-statusline help        # Help
```

## Requirements

- Claude Code CLI
- bash (WSL or native)
- No external dependencies

## License

[MIT](LICENSE)
