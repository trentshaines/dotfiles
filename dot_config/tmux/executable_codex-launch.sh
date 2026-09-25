#!/usr/bin/env bash
# A shared daemon loses the terminal→thread association used by tmux restore.
# Probe the selected Codex binary: mise can select different versions per repo.
# Older versions already own their thread locally and do not support this flag.
set -e
for arg in "$@"; do
    if [ "$arg" = '--no-daemon' ]; then
        exec codex "$@"
    fi
done
if [ -n "${TMUX_PANE:-}" ] && command codex --help 2>/dev/null | grep -q -- '--no-daemon'; then
    exec codex --no-daemon "$@"
fi
exec codex "$@"
