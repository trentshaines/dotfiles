#!/bin/bash
# Outputs: target\tclient\tdisplay_line for fzf picker.
# Called for initial load and fzf reload after dismiss.

QUEUE_FILE="/tmp/claude-notifications.queue"
TMUX_BIN="/opt/homebrew/bin/tmux"
FMT="$HOME/.claude/scripts/claude-format-display.py"

[[ ! -f "$QUEUE_FILE" ]] && exit 0

now=$(date +%s)
cols=$(( ${TMUX_CLIENT_WIDTH:-100} * 70 / 100 ))

WORK=$(mktemp -d)
trap "rm -rf $WORK" EXIT
TABLE="$WORK/table.tsv"
META="$WORK/meta.tsv"

while IFS=$'\t' read -r ts target client project session window_name pane_index visited; do
    [[ "$visited" != "0" ]] && continue
    [[ ! "$ts" =~ ^[0-9]+$ ]] && continue
    [[ -z "$target" ]] && continue

    pane_title=$($TMUX_BIN display-message -t "$target" -p '#{pane_title}' 2>/dev/null || true)
    pane_title="${pane_title#✓ }"; pane_title="${pane_title#✳ }"

    ago=$(( (now - ts) / 60 ))
    if   (( ago < 1  )); then finished="just now"
    elif (( ago < 60 )); then finished="${ago}m ago"
    else                       finished="$(( ago / 60 ))h ago"
    fi

    printf '%s\t%s\t%s\t%s\n' \
        "${session} → ${window_name} (pane ${pane_index})" \
        "$pane_title" "$finished" "$project" >> "$TABLE"
    printf '%s\t%s\n' "$target" "$client" >> "$META"

done < <(sort -t$'\t' -k1,1rn "$QUEUE_FILE")

[[ ! -s "$TABLE" ]] && exit 0

python3 "$FMT" "$TABLE" "$cols" > "$WORK/display.txt"

paste "$META" "$WORK/display.txt"
