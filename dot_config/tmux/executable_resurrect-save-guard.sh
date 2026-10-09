#!/usr/bin/env bash
# Continuum autosave entry point. A fresh server must not publish a new `last`
# snapshot until the boot restore has finished: an autosave seconds into the
# restore once captured 16 of 79 panes and 0 of 55 assistants, and the restore
# hook then resumed and renamed from that partial snapshot.
# assistant-state.py sets @assistant-restore-done when its restore ends; the
# timeout covers servers where no restore runs (another server, restore off).
start=$(tmux display-message -p '#{start_time}')
if [ "$(tmux show-option -gqv @assistant-restore-done)" != 1 ] &&
	[ $(($(date +%s) - start)) -lt 1800 ]; then
	exit 0
fi
exec "$HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh" "$@"
