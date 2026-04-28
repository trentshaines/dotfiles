#!/bin/bash
# Claude notification picker using gum filter.
# enter on single item  → switch to pane
# tab-select group + enter → dismiss all selected

TMUX_BIN="/opt/homebrew/bin/tmux"
QUEUE_FILE="/tmp/claude-notifications.queue"
SWITCH_SCRIPT="$HOME/.claude/scripts/claude-switch.sh"
DELETE_SCRIPT="$HOME/.claude/scripts/claude-delete.sh"
FMT="$HOME/.claude/scripts/claude-format-display.py"

[[ ! -f "$QUEUE_FILE" ]] || [[ ! -s "$QUEUE_FILE" ]] && {
    $TMUX_BIN display-message "No pending Claude notifications"
    exit 0
}

cols=$(( ${TMUX_CLIENT_WIDTH:-100} * 70 / 100 ))
now=$(date +%s)
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

[[ ! -s "$TABLE" ]] && {
    $TMUX_BIN display-message "No pending Claude notifications"
    exit 0
}

python3 "$FMT" "$TABLE" "$cols" > "$WORK/display.txt"

ROW_COUNT=$(wc -l < "$WORK/display.txt")
HEIGHT=$(( ROW_COUNT + 3 ))
(( HEIGHT > 20 )) && HEIGHT=20

SELECTED=$(gum filter \
    --no-limit \
    --height="$HEIGHT" \
    --placeholder="Search..." \
    --prompt="  " \
    --header=" enter: switch  ·  tab+enter: dismiss group" \
    < "$WORK/display.txt")

[[ -z "$SELECTED" ]] && exit 0

COUNT=$(echo "$SELECTED" | wc -l | tr -d ' ')

if [[ "$COUNT" -eq 1 ]]; then
    ROW=$(grep -nxF "$SELECTED" "$WORK/display.txt" | head -1 | cut -d: -f1)
    [[ -z "$ROW" ]] && exit 0
    IFS=$'\t' read -r TARGET CLIENT < <(sed -n "${ROW}p" "$META")
    "$SWITCH_SCRIPT" "$TARGET" "$CLIENT"
else
    while IFS= read -r sel; do
        ROW=$(grep -nxF "$sel" "$WORK/display.txt" | head -1 | cut -d: -f1)
        [[ -z "$ROW" ]] && continue
        IFS=$'\t' read -r TARGET _ < <(sed -n "${ROW}p" "$META")
        "$DELETE_SCRIPT" "$TARGET"
    done <<< "$SELECTED"
fi
