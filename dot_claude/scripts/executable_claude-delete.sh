#!/bin/bash
# Delete targets from queue file
QUEUE_FILE="/tmp/claude-notifications.queue"

for target in "$@"; do
    if [[ -f "$QUEUE_FILE" ]]; then
        awk -F'\t' -v t="$target" '$2 != t' "$QUEUE_FILE" > "$QUEUE_FILE.tmp" && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"
    fi
done
