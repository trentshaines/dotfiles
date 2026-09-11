#!/bin/bash
# Sets tmux pane title and window name based on Claude Code task.
# Priority: user-set name > branch/worktree > Claude task
# Called from UserPromptSubmit and Stop hooks.

TMUX_BIN="/opt/homebrew/bin/tmux"
PANE_ID="$TMUX_PANE"

[[ -z "$PANE_ID" ]] && exit 0

# Codex continuously writes OSC title escapes like "⠋ .config", which
# otherwise overwrite the title this hook sets. Keep this scoped to Codex
# panes so Claude Code's own title behavior is left alone.
if [[ -n "${CODEX_THREAD_ID:-}${CODEX_MANAGED_PACKAGE_ROOT:-}${CODEX_CI:-}" ]]; then
    $TMUX_BIN set-option -p -t "$PANE_ID" allow-set-title off 2>/dev/null
fi

EVENT=$(python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    event = data.get('hook_event_name', '')
    prompt = data.get('prompt', '')
    print(event)
    print(prompt)
except:
    pass
" 2>/dev/null)

HOOK_EVENT=$(echo "$EVENT" | head -1)
PROMPT=$(echo "$EVENT" | tail -n +2)

# --- Window naming ---
win_get()   { $TMUX_BIN show-options -wqv -t "$PANE_ID" "$1" 2>/dev/null; }
win_set()   { $TMUX_BIN set-option -w -t "$PANE_ID" "$1" "$2" 2>/dev/null; }
win_unset() { $TMUX_BIN set-option -wu -t "$PANE_ID" "$1" 2>/dev/null; }
win_name()  { $TMUX_BIN display-message -t "$PANE_ID" -p '#W' 2>/dev/null; }

truncate_prompt() {
    local limit="$1"
    python3 -c 'import sys; limit = int(sys.argv[1]); text = sys.stdin.read().replace("\n", " "); suffix = "…" if len(text) > limit else ""; print(text[:limit] + suffix, end="")' "$limit"
}

# Returns 0 if Claude is allowed to set the window name
claude_can_rename() {
    local current auto_branch auto_claude
    current=$(win_name)
    auto_branch=$(win_get @auto-branch)
    auto_claude=$(win_get @auto-claude)

    # Branch/worktree takes precedence — don't touch it
    [[ -n "$auto_branch" ]] && return 1

    # User manually renamed: current name doesn't match any auto-set value
    if [[ -n "$auto_claude" && "$current" != "$auto_claude" ]]; then
        return 1
    fi

    return 0
}

# --- Events ---
if [[ "$HOOK_EVENT" == "UserPromptSubmit" && -n "$PROMPT" ]]; then
    # A manually pinned pane title takes precedence over agent tasks.
    if [[ "$($TMUX_BIN show-options -pqv -t "$PANE_ID" @manual-pane-title)" != "1" ]]; then
        PANE_TITLE=$(printf '%s' "$PROMPT" | truncate_prompt 40)
        $TMUX_BIN select-pane -t "$PANE_ID" -T "$PANE_TITLE"
    fi

    # Window name: shorter, only if branch isn't showing and user hasn't renamed
    if claude_can_rename; then
        WIN_TITLE=$(printf '%s' "$PROMPT" | truncate_prompt 28)
        $TMUX_BIN rename-window -t "$PANE_ID" "$WIN_TITLE"
        win_set @auto-claude "$WIN_TITLE"
    fi

elif [[ "$HOOK_EVENT" == "Stop" && "$($TMUX_BIN show-options -pqv -t "$PANE_ID" @manual-pane-title)" != "1" ]]; then
    # Pane title: mark done
    CURRENT=$($TMUX_BIN display-message -t "$PANE_ID" -p '#{pane_title}')
    if [[ -n "$CURRENT" && "$CURRENT" != *"✓"* ]]; then
        $TMUX_BIN select-pane -t "$PANE_ID" -T "✓ $CURRENT"
    fi
    # Window name: leave it — next prompt will update it
fi
