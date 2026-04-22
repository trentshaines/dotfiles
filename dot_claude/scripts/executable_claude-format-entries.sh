#!/bin/bash
# Formats pending Claude notifications for fzf display.
# Output fields (tab-delimited): target | client | display_string
# Sorted by most recent first. Only unvisited entries ($8 == 0).

QUEUE_FILE="/tmp/claude-notifications.queue"
[[ ! -f "$QUEUE_FILE" ]] && exit 0

now=$(date +%s)

while IFS=$'\t' read -r ts target client project session window_name pane_index visited; do
    [[ "$visited" != "0" ]] && continue

    pane_title=$(tmux display-message -t "$target" -p '#{pane_title}' 2>/dev/null || true)

    ago_mins=$(( (now - ts) / 60 ))
    if (( ago_mins < 1 )); then
        finished="just now"
    elif (( ago_mins < 60 )); then
        finished="${ago_mins}m ago"
    else
        hours=$(( ago_mins / 60 ))
        finished="${hours}h ago"
    fi

    display="${project}: ${session} → ${window_name} (pane ${pane_index})"
    [[ -n "$pane_title" ]] && display+=" | ${pane_title}"
    display+=" | ${finished}"

    printf "%s\t%s\t%s\t%s\n" "$ts" "$target" "$client" "$display"
done < <(sort -t$'\t' -k1,1rn "$QUEUE_FILE")
