#!/bin/bash
# Claude notification picker using gum table

TMUX_BIN="/opt/homebrew/bin/tmux"
QUEUE_FILE="/tmp/claude-notifications.queue"
SWITCH_SCRIPT="$HOME/.claude/scripts/claude-switch.sh"
DELETE_SCRIPT="$HOME/.claude/scripts/claude-delete.sh"

[[ ! -f "$QUEUE_FILE" ]] || [[ ! -s "$QUEUE_FILE" ]] && {
    $TMUX_BIN display-message "No pending Claude notifications"
    exit 0
}

now=$(date +%s)
WORK=$(mktemp -d)
TABLE="$WORK/table.tsv"
META="$WORK/meta.tsv"   # parallel file: ts\ttarget\tclient per row

while IFS=$'\t' read -r ts target client project session window_name pane_index visited; do
    [[ "$visited" != "0" ]] && continue
    [[ ! "$ts" =~ ^[0-9]+$ ]] && continue
    [[ -z "$target" ]] && continue

    pane_title=$($TMUX_BIN display-message -t "$target" -p '#{pane_title}' 2>/dev/null || true)
    pane_title="${pane_title#✓ }"
    pane_title="${pane_title#✳ }"

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

if [[ ! -s "$TABLE" ]]; then
    $TMUX_BIN display-message "No pending Claude notifications"
    rm -rf "$WORK"; exit 0
fi

SELECTION=$(gum table \
    --separator=$'\t' \
    --columns="Location,Task,Time,Project" \
    --border=rounded \
    --border.foreground="240" \
    --header.foreground="212" \
    --selected.foreground="212" \
    < "$TABLE")

if [[ -n "$SELECTION" ]]; then
    ROW=$(grep -nxF "$SELECTION" "$TABLE" | head -1 | cut -d: -f1)
    if [[ -n "$ROW" ]]; then
        IFS=$'\t' read -r ts TARGET CLIENT < <(sed -n "${ROW}p" "$META")
        "$SWITCH_SCRIPT" "$TARGET" "$CLIENT"
    fi
fi

rm -rf "$WORK"
