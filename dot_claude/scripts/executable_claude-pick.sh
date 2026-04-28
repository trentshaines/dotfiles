#!/bin/bash
# Claude notification picker.
# MODE switch (default): gum filter, enter = switch to pane.
# MODE dismiss:          gum filter, tab multi-select, enter = dismiss all selected.

TMUX_BIN="/opt/homebrew/bin/tmux"
QUEUE_FILE="/tmp/claude-notifications.queue"
SWITCH_SCRIPT="$HOME/.claude/scripts/claude-switch.sh"
DELETE_SCRIPT="$HOME/.claude/scripts/claude-delete.sh"
FMT="$HOME/.claude/scripts/claude-format-display.py"
MODE="${1:-switch}"

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
    printf '%s\t%s\t%s\n' "$ts" "$target" "$client" >> "$META"

done < <(sort -t$'\t' -k1,1rn "$QUEUE_FILE")

[[ ! -s "$TABLE" ]] && {
    $TMUX_BIN display-message "No pending Claude notifications"
    exit 0
}

python3 "$FMT" "$TABLE" "$cols" > "$WORK/display.txt"

ROW_COUNT=$(wc -l < "$WORK/display.txt")
HEIGHT=$(( ROW_COUNT + 3 ))
(( HEIGHT > 20 )) && HEIGHT=20

if [[ "$MODE" == "switch" ]]; then
    HEADER=" enter: switch"
    LIMIT="--limit=1"
else
    HEADER=" tab: multi-select  ·  enter: dismiss"
    LIMIT="--no-limit"
fi

SELECTED=$(gum filter $LIMIT \
    --height="$HEIGHT" \
    --placeholder="Search..." \
    --prompt="  " \
    --header="$HEADER" \
    < "$WORK/display.txt")

[[ -z "$SELECTED" ]] && exit 0

while IFS= read -r sel; do
    ROW=$(grep -nxF "$sel" "$WORK/display.txt" | head -1 | cut -d: -f1)
    [[ -z "$ROW" ]] && continue
    IFS=$'\t' read -r ts TARGET CLIENT < <(sed -n "${ROW}p" "$META")
    case "$MODE" in
        switch)  "$SWITCH_SCRIPT" "$TARGET" "$CLIENT" ;;
        dismiss) "$DELETE_SCRIPT" "$ts" ;;
    esac
done <<< "$SELECTED"
