#!/bin/bash
# Sets tmux pane title and window name based on Claude Code task.
# Priority: user-set name > branch/worktree > Claude task
# Called from UserPromptSubmit and Stop hooks.

TMUX_BIN="/opt/homebrew/bin/tmux"
PANE_ID="$TMUX_PANE"

[[ -z "$PANE_ID" ]] && exit 0

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
win_get()   { $TMUX_BIN show-options -wv "$1" 2>/dev/null; }
win_set()   { $TMUX_BIN set-option -w "$1" "$2" 2>/dev/null; }
win_unset() { $TMUX_BIN set-option -wu "$1" 2>/dev/null; }
win_name()  { $TMUX_BIN display-message -p '#W' 2>/dev/null; }

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
    # Pane title: full 40-char prompt
    PANE_TITLE=$(echo "$PROMPT" | tr '\n' ' ' | head -c 40)
    [[ ${#PROMPT} -gt 40 ]] && PANE_TITLE="${PANE_TITLE}…"
    $TMUX_BIN select-pane -t "$PANE_ID" -T "$PANE_TITLE"

    # Window name: shorter, only if branch isn't showing and user hasn't renamed
    if claude_can_rename; then
        WIN_TITLE=$(echo "$PROMPT" | tr '\n' ' ' | head -c 28)
        [[ ${#PROMPT} -gt 28 ]] && WIN_TITLE="${WIN_TITLE}…"
        $TMUX_BIN rename-window "$WIN_TITLE"
        win_set @auto-claude "$WIN_TITLE"
    fi

elif [[ "$HOOK_EVENT" == "Stop" ]]; then
    # Pane title: mark done
    CURRENT=$($TMUX_BIN display-message -t "$PANE_ID" -p '#{pane_title}')
    if [[ -n "$CURRENT" && "$CURRENT" != *"✓"* ]]; then
        $TMUX_BIN select-pane -t "$PANE_ID" -T "✓ $CURRENT"
    fi
    # Window name: leave it — next prompt will update it
fi
