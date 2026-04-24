#!/bin/bash
# Formats pending Claude notifications for fzf display.
# Output fields (tab-delimited): ts | target | client | display_string
# Two-pass: first collect all rows + find max column widths, then format aligned.

QUEUE_FILE="/tmp/claude-notifications.queue"
[[ ! -f "$QUEUE_FILE" ]] && exit 0

now=$(date +%s)
popup_width=$(tput cols 2>/dev/null || echo 70)
usable=$(( popup_width - 4 ))

# --- Pass 1: collect rows, compute max column widths ---
declare -a R_ts R_target R_client R_loc R_title R_finished R_project

max_loc=0
max_title=0
max_finished=0
max_project=0
count=0

while IFS=$'\t' read -r ts target client project session window_name pane_index visited; do
    [[ "$visited" != "0" ]] && continue

    pane_title=$(tmux display-message -t "$target" -p '#{pane_title}' 2>/dev/null || true)
    # Strip leading ✓ from pane title if present
    pane_title="${pane_title#✓ }"

    ago_mins=$(( (now - ts) / 60 ))
    if   (( ago_mins < 1  )); then finished="just now"
    elif (( ago_mins < 60 )); then finished="${ago_mins}m ago"
    else finished="$(( ago_mins / 60 ))h ago"
    fi

    loc="${session} → ${window_name} (pane ${pane_index})"

    R_ts[$count]="$ts";           R_target[$count]="$target"
    R_client[$count]="$client";   R_loc[$count]="$loc"
    R_title[$count]="$pane_title" R_finished[$count]="$finished"
    R_project[$count]="$project"

    (( ${#loc}        > max_loc      )) && max_loc=${#loc}
    (( ${#pane_title} > max_title    )) && max_title=${#pane_title}
    (( ${#finished}   > max_finished )) && max_finished=${#finished}
    (( ${#project}    > max_project  )) && max_project=${#project}

    (( count++ ))
done < <(sort -t$'\t' -k1,1rn "$QUEUE_FILE")

(( count == 0 )) && exit 0

# --- Pass 2: emit aligned rows ---
for (( i=0; i<count; i++ )); do
    col_loc=$(     printf "%-${max_loc}s"      "${R_loc[$i]}")
    col_finished=$(printf "%-${max_finished}s" "${R_finished[$i]}")
    col_project="${R_project[$i]}"

    if [[ -n "${R_title[$i]}" ]]; then
        col_title=$(printf "%-${max_title}s" "${R_title[$i]}")
        left="${col_loc} | ${col_title} | ${col_finished}"
    else
        empty=$(printf "%-${max_title}s" "")
        left="${col_loc} | ${empty} | ${col_finished}"
    fi

    pad=$(( usable - ${#left} - ${#col_project} ))
    (( pad < 2 )) && pad=2
    display="${left}$(printf '%*s' $pad '')${col_project}"

    printf "%s\t%s\t%s\t%s\n" "${R_ts[$i]}" "${R_target[$i]}" "${R_client[$i]}" "$display"
done
