#!/usr/bin/env bash

# Preserve the naming state that tmux-resurrect does not keep: pane title locks
# and the custom markers used by the local window auto-naming helpers.  Names
# are also reapplied after restored programs start so their startup title
# sequences cannot immediately replace the saved values.

set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then
	exit 0
fi

resurrect_data_dir() {
	if [ -n "${TMUX_RESURRECT_DIR:-}" ]; then
		printf '%s\n' "$TMUX_RESURRECT_DIR"
		return
	fi

	local dir host
	dir=$(tmux show-option -gqv @resurrect-dir 2>/dev/null || true)
	if [ -z "$dir" ]; then
		if [ -d "$HOME/.tmux/resurrect" ]; then
			dir="$HOME/.tmux/resurrect"
		else
			dir="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect"
		fi
	fi

	host=$(hostname 2>/dev/null || true)
	printf '%s\n' "$dir" | sed "s,\$HOME,$HOME,g; s,\$HOSTNAME,$host,g; s,~,$HOME,g"
}

option_value() {
	local scope=$1 target=$2 option=$3
	tmux show-options "$scope" -qv -t "$target" "$option" 2>/dev/null || true
}

collect_windows() {
	local window_id session index name automatic_rename allow_rename auto_branch auto_claude
	while IFS= read -r window_id; do
		[ -n "$window_id" ] || continue
		session=$(tmux display-message -p -t "$window_id" -F '#{session_name}' 2>/dev/null) || continue
		index=$(tmux display-message -p -t "$window_id" -F '#{window_index}' 2>/dev/null) || continue
		name=$(tmux display-message -p -t "$window_id" -F '#{window_name}' 2>/dev/null) || continue
		automatic_rename=$(option_value -w "$window_id" automatic-rename)
		allow_rename=$(option_value -w "$window_id" allow-rename)
		auto_branch=$(option_value -w "$window_id" @auto-branch)
		auto_claude=$(option_value -w "$window_id" @auto-claude)

		jq -nc \
			--arg session "$session" \
			--arg index "$index" \
			--arg name "$name" \
			--arg automaticRename "$automatic_rename" \
			--arg allowRename "$allow_rename" \
			--arg autoBranch "$auto_branch" \
			--arg autoClaude "$auto_claude" \
			'{session: $session, index: $index, name: $name,
			  automaticRename: $automaticRename, allowRename: $allowRename,
			  autoBranch: $autoBranch, autoClaude: $autoClaude}'
	done < <(tmux list-windows -a -F '#{window_id}' 2>/dev/null)
}

collect_panes() {
	local pane_id session window_index pane_index title allow_set_title manual_title
	while IFS= read -r pane_id; do
		[ -n "$pane_id" ] || continue
		session=$(tmux display-message -p -t "$pane_id" -F '#{session_name}' 2>/dev/null) || continue
		window_index=$(tmux display-message -p -t "$pane_id" -F '#{window_index}' 2>/dev/null) || continue
		pane_index=$(tmux display-message -p -t "$pane_id" -F '#{pane_index}' 2>/dev/null) || continue
		title=$(tmux display-message -p -t "$pane_id" -F '#{pane_title}' 2>/dev/null) || continue
		allow_set_title=$(option_value -p "$pane_id" allow-set-title)
		manual_title=$(option_value -p "$pane_id" @manual-pane-title)

		jq -nc \
			--arg session "$session" \
			--arg windowIndex "$window_index" \
			--arg paneIndex "$pane_index" \
			--arg title "$title" \
			--arg allowSetTitle "$allow_set_title" \
			--arg manualTitle "$manual_title" \
			'{session: $session, windowIndex: $windowIndex, paneIndex: $paneIndex,
			  title: $title, allowSetTitle: $allowSetTitle, manualTitle: $manualTitle}'
	done < <(tmux list-panes -a -F '#{pane_id}' 2>/dev/null)
}

save_names() {
	local data_dir names_file temp_file windows panes
	data_dir=$(resurrect_data_dir)
	mkdir -p "$data_dir"
	names_file="$data_dir/names.json"
	temp_file=$(mktemp "$data_dir/.names.json.XXXXXX") || return 1

	windows=$(collect_windows | jq -s '.') || return 1
	panes=$(collect_panes | jq -s '.') || return 1
	if jq -n --argjson windows "$windows" --argjson panes "$panes" \
		'{version: 1, windows: $windows, panes: $panes}' >"$temp_file"; then
		mv "$temp_file" "$names_file"
	else
		rm -f "$temp_file"
		return 1
	fi
}

restore_local_option() {
	local scope=$1 target=$2 option=$3 value=$4 unset_flag
	case "$scope" in
	-w) unset_flag=-wu ;;
	-p) unset_flag=-pu ;;
	*) return 1 ;;
	esac

	if [ -n "$value" ]; then
		tmux set-option "$scope" -q -t "$target" "$option" "$value" 2>/dev/null || true
	else
		tmux set-option "$unset_flag" -q -t "$target" "$option" 2>/dev/null || true
	fi
}

restore_names() {
	local names_file row session index target value
	names_file="$(resurrect_data_dir)/names.json"
	[ -r "$names_file" ] || return 0

	# The assistant restore hook runs first. Give the final resumed process a
	# moment to emit any startup title sequence before restoring the saved name.
	sleep 2

	while IFS= read -r row; do
		session=$(jq -r '.session' <<<"$row")
		index=$(jq -r '.index' <<<"$row")
		target="${session}:${index}"
		tmux list-windows -t "$target" >/dev/null 2>&1 || continue

		tmux rename-window -t "$target" "$(jq -r '.name' <<<"$row")" 2>/dev/null || true
		value=$(jq -r '.automaticRename' <<<"$row")
		restore_local_option -w "$target" automatic-rename "$value"
		value=$(jq -r '.allowRename' <<<"$row")
		restore_local_option -w "$target" allow-rename "$value"
		value=$(jq -r '.autoBranch' <<<"$row")
		restore_local_option -w "$target" @auto-branch "$value"
		value=$(jq -r '.autoClaude' <<<"$row")
		restore_local_option -w "$target" @auto-claude "$value"
	done < <(jq -c '.windows[]?' "$names_file")

	while IFS= read -r row; do
		session=$(jq -r '.session' <<<"$row")
		index=$(jq -r '.windowIndex' <<<"$row")
		target="${session}:${index}.$(jq -r '.paneIndex' <<<"$row")"
		tmux display-message -p -t "$target" '#{pane_id}' >/dev/null 2>&1 || continue

		tmux select-pane -t "$target" -T "$(jq -r '.title' <<<"$row")" 2>/dev/null || true
		value=$(jq -r '.allowSetTitle' <<<"$row")
		restore_local_option -p "$target" allow-set-title "$value"
		value=$(jq -r '.manualTitle' <<<"$row")
		restore_local_option -p "$target" @manual-pane-title "$value"
	done < <(jq -c '.panes[]?' "$names_file")
}

case "${1:-}" in
save) save_names ;;
restore) restore_names ;;
*) exit 2 ;;
esac
