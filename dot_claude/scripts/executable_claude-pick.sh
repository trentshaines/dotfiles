#!/bin/bash
# Claude notification picker using gum table.
# MODE: switch (default) or dismiss — passed as $1.

TMUX_BIN="/opt/homebrew/bin/tmux"
QUEUE_FILE="/tmp/claude-notifications.queue"
SWITCH_SCRIPT="$HOME/.claude/scripts/claude-switch.sh"
DELETE_SCRIPT="$HOME/.claude/scripts/claude-delete.sh"
MODE="${1:-switch}"

[[ ! -f "$QUEUE_FILE" ]] || [[ ! -s "$QUEUE_FILE" ]] && {
    $TMUX_BIN display-message "No pending Claude notifications"
    exit 0
}

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

if [[ "$MODE" == "switch" ]]; then
    LABEL=" Claude Notifications · enter: switch "
else
    LABEL=" Claude Notifications · enter: dismiss "
fi

SELECTION=$(gum table \
    --separator=$'\t' \
    --columns="Location,Task,Time,Project" \
    --border=rounded \
    --border-label="$LABEL" \
    --border.foreground="240" \
    --header.foreground="212" \
    --selected.foreground="212" \
    < "$TABLE")

[[ -z "$SELECTION" ]] && exit 0

ROW=$(grep -nxF "$SELECTION" "$TABLE" | head -1 | cut -d: -f1)
[[ -z "$ROW" ]] && exit 0

IFS=$'\t' read -r ts TARGET CLIENT < <(sed -n "${ROW}p" "$META")

case "$MODE" in
    switch)  "$SWITCH_SCRIPT" "$TARGET" "$CLIENT" ;;
    dismiss) "$DELETE_SCRIPT" "$ts" ;;
esac
