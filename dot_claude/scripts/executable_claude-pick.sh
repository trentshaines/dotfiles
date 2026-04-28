#!/bin/bash
# Claude notification picker: gum table + gum filter + gum choose

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

# Step 1: gum filter — fuzzy search, tab for multi-select
DISPLAY_FILE="$WORK/display.txt"
awk -F'\t' '{printf "%-40s %-35s %-10s %s\n", $1, $2, $3, $4}' "$TABLE" > "$DISPLAY_FILE"

ROW_COUNT=$(wc -l < "$DISPLAY_FILE")
HEIGHT=$(( ROW_COUNT + 3 ))  # +3 for input line, header, padding
(( HEIGHT > 20 )) && HEIGHT=20

FILTERED=$(gum filter \
    --no-limit \
    --height="$HEIGHT" \
    --placeholder="Search..." \
    --prompt="  " \
    --header=" enter: confirm · tab: multi-select" \
    < "$DISPLAY_FILE")

[[ -z "$FILTERED" ]] && exit 0

SEL_COUNT=$(echo "$FILTERED" | wc -l | tr -d ' ')

# Step 2: gum choose — pick action
if [[ "$SEL_COUNT" -eq 1 ]]; then
    ACTION=$(gum choose \
        --header=" What do you want to do?" \
        "→  Switch to pane" \
        "✕  Dismiss" \
        "←  Cancel")
else
    ACTION=$(gum choose \
        --header=" $SEL_COUNT notifications selected" \
        "✕  Dismiss all" \
        "←  Cancel")
fi

[[ -z "$ACTION" || "$ACTION" == *Cancel* ]] && exit 0

# Step 3: execute
while IFS= read -r sel; do
    ROW=$(grep -nxF "$sel" "$DISPLAY_FILE" | head -1 | cut -d: -f1)
    [[ -z "$ROW" ]] && continue
    IFS=$'\t' read -r ts TARGET CLIENT < <(sed -n "${ROW}p" "$META")
    case "$ACTION" in
        *Switch*) "$SWITCH_SCRIPT" "$TARGET" "$CLIENT" ;;
        *Dismiss*) "$DELETE_SCRIPT" "$ts" ;;
    esac
done <<< "$FILTERED"
