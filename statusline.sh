#!/usr/bin/env bash
# cc-statusbar - Claude Code Status Bar
# https://github.com/DreamingStrawberry/cc-statusbar
#
# Line 1: Model | Path@Branch | Context | 5h limit | 7d limit | Cost | /commands
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
SHOW_COST=false
SHOW_COMMANDS=true
SHOW_COMMANDS=true
LANGUAGE=en
BAR_STYLE=blocks
BAR_WIDTH=10
BAR_FILL="▓"
BAR_EMPTY="░"

# Load config: Windows side first (TUI saves here), then WSL home as fallback
CONF=""
for wconf in /mnt/c/Users/*/.claude/statusline.conf; do
    [ -f "$wconf" ] && CONF="$wconf" && break
done
[ -z "$CONF" ] && CONF="$HOME/.claude/statusline.conf"
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
exceeds_200k=$(_e "exceeds_200k_tokens")
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
# Colors
# ===================================================
R='\033[0m'; B='\033[1m'; BK='\033[5m'; D='\033[2m'
CY='\033[36m'; GN='\033[32m'; YL='\033[33m'; RD='\033[31m'
GR='\033[90m'; MG='\033[35m'; BL='\033[34m'; OR='\033[38;5;208m'

_c() { local p=$1; [ "$p" -ge 80 ] 2>/dev/null && echo "$RD" && return; [ "$p" -ge 50 ] 2>/dev/null && echo "$YL" && return; echo "$GN"; }

# ===================================================
# Block bar with 1/8 precision
# ===================================================
_bar() {
    local pct=$1 w=${2:-$BAR_WIDTH}

    local fc="" ec=""
    case "$BAR_STYLE" in
        dots)      fc="●"; ec="○" ;;
        squares)   fc="■"; ec="□" ;;
        lines)     fc="━"; ec="─" ;;
        triangles) fc="▰"; ec="▱" ;;
        ascii)     fc="#"; ec="." ;;
        *)         fc="$BAR_FILL"; ec="$BAR_EMPTY" ;;
    esac

    local n=$(( pct * w / 100 ))
    [ "$n" -gt "$w" ] && n=$w
    local m=$(( w - n ))
    local bar=""
    for ((i=0;i<n;i++)); do bar+="$fc"; done
    for ((i=0;i<m;i++)); do bar+="$ec"; done
    echo "$bar"
}

_fmt_time() {
    local s=$1 fmt=$2
    [ "$s" -le 0 ] 2>/dev/null && echo "now" && return
    if [ "$fmt" = "hm" ]; then
        echo "$(( s/3600 ))h $(( s%3600/60 ))m"
    else
        echo "$(( s/86400 ))d $(( s%86400/3600 ))h $(( s%3600/60 ))m"
    fi
}

# Estimate remaining time: how long until limit is exhausted at current rate
# Uses reset timestamp to derive elapsed time within the window
_remain() {
    local reset_ts=$1 pct=$2 fmt=$3
    [ -z "$pct" ] || [ "$pct" -le 0 ] 2>/dev/null && return
    [ -z "$reset_ts" ] || [ "$reset_ts" -le 0 ] 2>/dev/null && return
    local now=$(date +%s)
    local remain_pct=$(( 100 - pct ))
    # elapsed within window = window_size - time_until_reset
    # For 5h window: window = 18000s, for 7d: 604800s
    # But simpler: remaining = elapsed * remain% / used%
    # elapsed from reset: we don't know window start, use session duration as fallback
    local total_dur
    total_dur=$(_e "total_duration_ms")
    [ -z "$total_dur" ] || [ "$total_dur" -le 0 ] 2>/dev/null && return
    local elapsed=$(( total_dur / 1000 ))
    local remain_sec=$(( elapsed * remain_pct / pct ))
    _fmt_time "$remain_sec" "$fmt"
}

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
# Language labels
case "$LANGUAGE" in
    ko) L_CTX="컨텍스트"; L_5H="5시간"; L_7D="7일"; L_SVC="서비스"; L_SET="설정" ;;
    ja) L_CTX="ctx"; L_5H="5h"; L_7D="7d"; L_SVC="svc"; L_SET="設定" ;;
    zh) L_CTX="上下文"; L_5H="5小时"; L_7D="7天"; L_SVC="服务"; L_SET="设置" ;;
    fr) L_CTX="ctx"; L_5H="5h"; L_7D="7j"; L_SVC="svc"; L_SET="config" ;;
    de) L_CTX="ctx"; L_5H="5h"; L_7D="7T"; L_SVC="svc"; L_SET="Einst." ;;
    ru) L_CTX="ctx"; L_5H="5ч"; L_7D="7д"; L_SVC="svc"; L_SET="настр." ;;
    *)  L_CTX="ctx"; L_5H="5h"; L_7D="7d"; L_SVC="svc"; L_SET="settings" ;;
esac

ctx_color=$(_c $ui); five_color=$(_c $fi); seven_color=$(_c $si)

sep=""
if [ "$SHOW_MODEL" = "true" ]; then
    printf "${CY}${B}%s${R}" "$model"
    if [ "$exceeds_200k" = "true" ]; then
        printf " ${GN}thinking:on${R}"
    else
        printf " ${GR}thinking:off${R}"
    fi
    sep=" ${GR}|${R} "
fi
if [ "$SHOW_PATH" = "true" ]; then
    printf "%b${BL}%s${R}" "$sep" "$sp"
    [ "$SHOW_GIT_BRANCH" = "true" ] && [ -n "$gb" ] && printf "${GR}@${R}${MG}%s${R}" "$gb"
    sep=" ${GR}|${R} "
fi
if [ "$SHOW_CONTEXT" = "true" ]; then
    ctx_size=$(_e "context_window_size")
    ctx_used=$(( ctx_size * ui / 100 ))
    ctx_left=$(( ctx_size - ctx_used ))
    # Format as k or M
    if [ "$ctx_left" -ge 1000000 ] 2>/dev/null; then
        ctx_left_fmt="$(( ctx_left / 1000000 )).$(( ctx_left % 1000000 / 100000 ))M"
    elif [ "$ctx_left" -ge 1000 ] 2>/dev/null; then
        ctx_left_fmt="$(( ctx_left / 1000 ))k"
    else
        ctx_left_fmt="$ctx_left"
    fi
    if [ "$ctx_size" -ge 1000000 ] 2>/dev/null; then
        ctx_total_fmt="$(( ctx_size / 1000000 )).$(( ctx_size % 1000000 / 100000 ))M"
    else
        ctx_total_fmt="$(( ctx_size / 1000 ))k"
    fi
    printf "%b${L_CTX} ${ctx_color}%s${R} ${ctx_color}%d%%${R} ${GR}%s/%s${R}" "$sep" "$(_bar $ui)" "$ui" "$ctx_left_fmt" "$ctx_total_fmt"
    sep=" ${GR}|${R} "
fi
if [ "$SHOW_5H_LIMIT" = "true" ]; then
    printf "%b${L_5H} ${five_color}%s${R} ${five_color}%d%%${R}" "$sep" "$(_bar $fi)" "$fi"
    if [ -n "$five_h_reset" ] && [ "$five_h_reset" -gt 0 ] 2>/dev/null; then
        d5=$(( five_h_reset - $(date +%s) ))
        [ "$d5" -gt 0 ] && printf " ${GR}%s${R}" "$(_fmt_time $d5 hm)" || printf " ${GR}now${R}"
    fi
    sep=" ${GR}|${R} "
fi
if [ "$SHOW_7D_LIMIT" = "true" ]; then
    printf "%b${L_7D} ${seven_color}%s${R} ${seven_color}%d%%${R}" "$sep" "$(_bar $si)" "$si"
    if [ -n "$seven_d_reset" ] && [ "$seven_d_reset" -gt 0 ] 2>/dev/null; then
        d7=$(( seven_d_reset - $(date +%s) ))
        [ "$d7" -gt 0 ] && printf " ${GR}%s${R}" "$(_fmt_time $d7 dhm)" || printf " ${GR}now${R}"
    fi
    sep=" ${GR}|${R} "
fi
# Cost: only shown for API key users (not Claude Max subscription)
[ "$SHOW_COST" = "true" ] && [ -n "$total_cost" ] && [ "$total_cost" != "null" ] && [ "$total_cost" != "0" ] && printf "%b${GR}\$%.2f${R}" "$sep" "$total_cost" 2>/dev/null && sep=" ${GR}|${R} "
[ "$SHOW_COMMANDS" = "true" ] && printf "%b${D}${GR}${L_SET}: npx cc-statusbar${R}" "$sep"
printf "\n"

# ===================================================
# Line 2: DevLauncher (fully async, cache only)
# ===================================================
CACHE="/tmp/.devlauncher-status-cache"
LOCK="/tmp/.devlauncher-refresh.lock"

# Background refresh (never blocks main output)
if [ ! -f "$LOCK" ]; then
    now=$(date +%s)
    need_refresh=true
    [ -f "$CACHE" ] && cached_at=$(head -1 "$CACHE") && [ $(( now - cached_at )) -lt 10 ] && need_refresh=false
    if [ "$need_refresh" = "true" ]; then
        touch "$LOCK"
        ( DL=""; for c in "/mnt/c/Users/$USER/DevLauncher.ps1" "$HOME/DevLauncher.ps1"; do [ -f "$c" ] && DL="$c" && break; done
          if [ -n "$DL" ]; then
            ws=$(echo "$DL" | sed 's|^/mnt/\(.\)|\U\1:|; s|/|\\|g')
            r=$(timeout 5 powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$ws" status 2>/dev/null | tr -d '\r')
            { echo "$(date +%s)"; echo "$r"; } > "$CACHE"
          fi
          rm -f "$LOCK"
        ) &
        disown
    fi
fi

# Read from cache (instant)
raw=""
[ -f "$CACHE" ] && raw=$(tail -n +2 "$CACHE")

# Render
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
[ -n "$parts" ] && printf "${GR}${L_SVC}${R} $parts\n"
