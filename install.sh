#!/usr/bin/env bash
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.claude"
[ ! -d "$DEST" ] && mkdir -p "$DEST"
cp "$DIR/statusline.sh" "$DEST/statusline.sh"
chmod +x "$DEST/statusline.sh"
[ ! -f "$DEST/statusline.conf" ] && cp "$DIR/statusline.conf.example" "$DEST/statusline.conf"
echo "Installed to $DEST/statusline.sh"
echo "Edit $DEST/statusline.conf to customize."
echo "Add to $DEST/settings.json:"
echo '  { "statusLine": { "type": "command", "command": "bash ~/.claude/statusline.sh", "refreshInterval": 1 } }'
