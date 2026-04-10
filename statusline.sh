#!/usr/bin/env bash
# Claude Code Status Line
# https://github.com/DreamingStrawberry/claude-code-statusline
#
# Line 1: Model | Path@Branch | Context% | 5h limit | 7d limit | Cost
# Line 2: DevLauncher services (auto-detected, optional)

input=$(cat)

# ===================================================
# Config (override via ~/.claude/statusline.conf)
# ===================================================
SHOW_MODEL=true
SHOW_PATH=true
SHOW_GIT_BRANCH=true
SHOW_CONTEXT=true
SHOW_5H_LIMIT=true
SHOW_7D_LIMIT=true
SHOW_COST=true
SHOW_DEVLAUNCHER=true
DEVLAUNCHER_PATH=""
BAR_STYLE=dots
BAR_WIDTH=6

CONF="$HOME/.claude/statusline.conf"
[ -f "$CONF" ] && source "$CONF"

# ===================================================
# JSON parser (no jq)
# ===================================================
_e()  { echo "$input" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*[^,}]*" | head -1 | sed 's/.*:[[:space:]]*//' | tr -d '"' | tr -d ' '; }
_es() { echo "$input" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*:[[:space:]]*//' | tr -d '"'; }
_ea() { echo "$input" | grep -o "$1[^}]*\"$2\"[[:space:]]*:[[:space:]]*[^,}]*" | head -1 | grep -o "\"$2\"[[:space:]]*:[[:space:]]*[^,}]*" | sed 's/.*:[[:space:]]*//' | tr -d '"' | tr -d ' '; }

# ===================================================
# Data
# ===================================================
model=$(_es "display_name")
cwd=$(_es "current_dir"); [ -z "$cwd" ] && cwd=$(_es "cwd")
used_pct=$(_e "used_percentage")
five_h_pct=$(_ea "five_hour" "used_percentage")
five_h_reset=$(_ea "five_hour" "resets_at")
seven_d_pct=$(_ea "seven_day" "used_percentage")
seven_d_reset=$(_ea "seven_day" "resets_at")
total_cost=$(_e "total_cost_usd")

[ -z "$five_h_pct" ] && five_h_pct=0; [ -z "$seven_d_pct" ] && seven_d_pct=0
ui=$(printf "%.0f" "$used_pct" 2>/dev/null || echo 0)
fi=$(printf "%.0f" "$five_h_pct" 2>/dev/null || echo 0)
si=$(printf "%.0f" "$seven_d_pct" 2>/dev/null || echo 0)

# ===================================================
# Colors & ANSI
# ===================================================
R='\033[0m'; B='\033[1m'; BK='\033[5m'
CY='\033[36m'; GN='\033[32m'; YL='\033[33m'; RD='\033[31m'
GR='\033[90m'; MG='\033[35m'; BL='\033[34m'; OR='\033[38;5;208m'

_c() { local p=$1; [ "$p" -ge 80 ] 2>/dev/null && echo "$RD" && return; [ "$p" -ge 50 ] 2>/dev/null && echo "$YL" && return; echo "$GN"; }

_bar() {
    local p=$1 w=${2:-$BAR_WIDTH} f="" e="" fc="" ec=""
    local n=$(( p * w / 100 )); [ "$n" -gt "$w" ] && n=$w; local m=$(( w - n ))
    if [ "$BAR_STYLE" = "blocks" ]; then fc="█"; ec="░"; else fc="●"; ec="○"; fi
    for ((i=0;i<n;i++)); do f+="$fc"; done; for ((i=0;i<m;i++)); do e+="$ec"; done
    echo "$f$e"
}

_reset() {
    local ts=$1; [ -z "$ts" ] || [ "$ts" -le 0 ] 2>/dev/null && return
    local d=$(( ts - $(date +%s) ))
    [ "$d" -le 0 ] && echo "now" && return
    [ "$d" -lt 3600 ] && echo "$(( d/60 ))m" && return
    echo "$(( d/3600 ))h$(( d%3600/60 ))m"
}

# Spinner: 8 frames, rotates every 1s
_spin() {
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠇")
    echo "${frames[$(( $(date +%s) % 8 ))]}"
}

# Git
gb=""; command -v git >/dev/null 2>&1 && [ -d "$cwd" ] && gb=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
sp=$(echo "$cwd" | sed 's|\\|/|g' | awk -F/ '{if(NF>2) print $(NF-1)"/"$NF; else print $0}')

# ===================================================
# Line 1
# ===================================================
sep=""
[ "$SHOW_MODEL" = "true" ] && printf "${CY}${B}%s${R}" "$model" && sep=" ${GR}|${R} "
if [ "$SHOW_PATH" = "true" ]; then
    printf "%b${BL}%s${R}" "$sep" "$sp"
    [ "$SHOW_GIT_BRANCH" = "true" ] && [ -n "$gb" ] && printf "${GR}@${R}${MG}%s${R}" "$gb"
    sep=" ${GR}|${R} "
fi
[ "$SHOW_CONTEXT" = "true" ] && printf "%b$(_c $ui)%d%% %s${R}" "$sep" "$ui" "$(_bar $ui)" && sep=" ${GR}|${R} "
if [ "$SHOW_5H_LIMIT" = "true" ]; then
    printf "%b5h $(_c $fi)%s %d%%${R}" "$sep" "$(_bar $fi)" "$fi"
    r=$(_reset "$five_h_reset"); [ -n "$r" ] && printf "${GR}(%s)${R}" "$r"
    sep=" ${GR}|${R} "
fi
if [ "$SHOW_7D_LIMIT" = "true" ]; then
    printf "%b7d $(_c $si)%s %d%%${R}" "$sep" "$(_bar $si)" "$si"
    r=$(_reset "$seven_d_reset"); [ -n "$r" ] && printf "${GR}(%s)${R}" "$r"
    sep=" ${GR}|${R} "
fi
[ "$SHOW_COST" = "true" ] && [ -n "$total_cost" ] && [ "$total_cost" != "null" ] && printf "%b${GR}\$%.2f${R}" "$sep" "$total_cost" 2>/dev/null
printf "\n"

# ===================================================
# Line 2: DevLauncher (cached 3s, spinner every 1s)
# ===================================================
[ "$SHOW_DEVLAUNCHER" != "true" ] && exit 0

# Find DevLauncher
DL="$DEVLAUNCHER_PATH"
if [ -z "$DL" ] || [ ! -f "$DL" ]; then
    DL=""
    for c in "/mnt/c/Users/$USER/DevLauncher.ps1" /mnt/c/Users/*/DevLauncher.ps1 "$HOME/DevLauncher.ps1"; do
        for f in $c; do [ -f "$f" ] && DL="$f" && break 2; done
    done
fi
[ -z "$DL" ] && [ -n "$USERPROFILE" ] && {
    wp=$(echo "$USERPROFILE" | sed 's|\\|/|g; s|^\([A-Z]\):|/mnt/\L\1|')
    [ -f "$wp/DevLauncher.ps1" ] && DL="$wp/DevLauncher.ps1"
}
[ -z "$DL" ] && exit 0

# Cache: call powershell every 3s, reuse cache otherwise
CACHE="/tmp/.devlauncher-status-cache"
CACHE_AGE=3
now=$(date +%s)
refresh=false
if [ -f "$CACHE" ]; then
    cached_at=$(head -1 "$CACHE")
    [ $(( now - cached_at )) -ge $CACHE_AGE ] && refresh=true
else
    refresh=true
fi

if [ "$refresh" = "true" ]; then
    ws=$(echo "$DL" | sed 's|^/mnt/\(.\)|\U\1:|; s|/|\\|g')
    raw=$(powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$ws" status 2>/dev/null | tr -d '\r')
    { echo "$now"; echo "$raw"; } > "$CACHE"
else
    raw=$(tail -n +2 "$CACHE")
fi

# Render services
parts=""
spin=$(_spin)
while IFS= read -r line; do
    [ -z "$line" ] && continue
    nm=$(echo "$line" | awk '{print $2}')
    pt=$(echo "$line" | awk '{print $4}')
    st=$(echo "$line" | awk '{print $5}')
    case "$st" in
        Running)  parts="${parts:+$parts }${GN}${B}${nm}${pt}${R}${GN}●${R}" ;;
        Starting) parts="${parts:+$parts }${YL}${B}${nm}${pt}${spin}${R}" ;;
        Error)    parts="${parts:+$parts }${BK}${RD}${B}${nm}${pt}✖${R}" ;;
        *)        parts="${parts:+$parts }${GR}${nm}${pt}●${R}" ;;
    esac
done <<< "$raw"
[ -n "$parts" ] && printf "${GR}svc${R} $parts\n"
