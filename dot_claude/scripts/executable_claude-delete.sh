#!/bin/bash
# Delete targets from queue file
QUEUE_FILE="${AGENT_NOTIFICATION_FILE:-/tmp/claude-notifications.queue}"

[[ "$#" -eq 0 ]] && exit 0

(
    /usr/bin/lockf -s -t 2 9 || exit 0
    [[ ! -f "$QUEUE_FILE" ]] && exit 0
    TMP=$(mktemp "${QUEUE_FILE}.tmp.XXXXXX") || exit 0
    trap 'rm -f "$TMP"' EXIT

    cp "$QUEUE_FILE" "$TMP"
    for target in "$@"; do
        NEXT=$(mktemp "${QUEUE_FILE}.tmp.XXXXXX") || exit 0
        awk -F'\t' -v t="$target" '$2 != t' "$TMP" > "$NEXT" || {
            rm -f "$NEXT"
            exit 0
        }
        mv "$NEXT" "$TMP"
    done
    mv "$TMP" "$QUEUE_FILE"
) 9>"${QUEUE_FILE}.lock"
