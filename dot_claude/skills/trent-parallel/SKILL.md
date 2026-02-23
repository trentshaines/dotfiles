# Parallel Claude Skill

## Overview

This skill spawns 4 Claude Code instances in parallel tmux panes arranged in a 2x2 grid on the right half of the screen, sends the same prompt to all of them, waits for all to complete, gathers results, summarizes them, and cleans up.

## Trigger

User invokes `/parallel <prompt>` where `<prompt>` is the task to send to all Claude instances.

## Instructions

When the user invokes this skill with a prompt, execute the following steps:

### Step 1: Run the launcher script

Execute this bash script, replacing `<USER_PROMPT_HERE>` with the user's prompt:

```bash
#!/bin/bash
PROMPT="<USER_PROMPT_HERE>"
RESULTS_DIR="/tmp/claude-parallel-results"

# Clean up previous results
rm -rf "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR"

# Get original pane
ORIGINAL_PANE=$(tmux display-message -p '#{pane_id}')
echo "Original pane: $ORIGINAL_PANE"

# Step 1: Split horizontally to create right half
tmux split-window -h -p 50

# Get the new pane
sleep 0.2
PANE_A=$(tmux list-panes -F '#{pane_id}' | grep -v "^${ORIGINAL_PANE}$")

# Step 2: Split PANE_A vertically into top and bottom
tmux split-window -v -p 50 -t "$PANE_A"

sleep 0.2
# Get both right panes
ALL_PANES=$(tmux list-panes -F '#{pane_id}')
RIGHT_PANES=$(echo "$ALL_PANES" | grep -v "^${ORIGINAL_PANE}$")

PANE_TOP=$(echo "$RIGHT_PANES" | head -1)
PANE_BOT=$(echo "$RIGHT_PANES" | tail -1)

# Step 3: Split top and bottom panes horizontally
tmux split-window -h -p 50 -t "$PANE_TOP"
tmux split-window -h -p 50 -t "$PANE_BOT"

sleep 0.3

# Get final 4 new panes
ALL_PANES=$(tmux list-panes -F '#{pane_id}')
NEW_PANES=$(echo "$ALL_PANES" | grep -v "^${ORIGINAL_PANE}$")

# Save pane IDs
echo "$NEW_PANES" > "$RESULTS_DIR/pane-ids.txt"
echo "Created 4 panes: $(echo $NEW_PANES | tr '\n' ' ')"

# Launch claude in each new pane
while IFS= read -r PANE; do
    tmux send-keys -t "$PANE" "claude" Enter
done <<< "$NEW_PANES"

# Wait for claude to start
sleep 3

# Send the prompt to each pane
while IFS= read -r PANE; do
    tmux send-keys -t "$PANE" "$PROMPT" Enter
done <<< "$NEW_PANES"

# Wait a moment then send Enter again to confirm
sleep 1
while IFS= read -r PANE; do
    tmux send-keys -t "$PANE" Enter
done <<< "$NEW_PANES"

echo "Launched 4 Claude instances. Waiting for completion..."

# Poll for completion: check for stability + prompt indicator
# A pane is "done" when content is stable AND shows the > prompt
declare -A PANE_DONE
declare -A PANE_LAST_CONTENT

TIMEOUT=600  # 10 minutes
ELAPSED=0
POLL_INTERVAL=10

while [ $ELAPSED -lt $TIMEOUT ]; do
    DONE_COUNT=0

    while IFS= read -r PANE; do
        if [ "${PANE_DONE[$PANE]}" == "1" ]; then
            ((DONE_COUNT++))
            continue
        fi

        # Capture current pane content
        CURRENT=$(tmux capture-pane -t "$PANE" -p 2>/dev/null)

        # Check if pane shows the > prompt (Claude is waiting for input)
        if echo "$CURRENT" | tail -5 | grep -q "^>"; then
            # Check if content is stable (same as last check)
            if [ "${PANE_LAST_CONTENT[$PANE]}" == "$CURRENT" ]; then
                PANE_DONE[$PANE]="1"
                ((DONE_COUNT++))
                echo "Pane $PANE complete!"
            fi
        fi

        PANE_LAST_CONTENT[$PANE]="$CURRENT"
    done <<< "$NEW_PANES"

    if [ $DONE_COUNT -ge 4 ]; then
        echo "All 4 workers complete!"
        break
    fi

    echo "Waiting... ($DONE_COUNT/4 complete, ${ELAPSED}s elapsed)"
    sleep $POLL_INTERVAL
    ((ELAPSED+=POLL_INTERVAL))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "Warning: Timeout reached, some workers may not have completed"
fi

# Capture final output from each pane
i=1
while IFS= read -r PANE; do
    tmux capture-pane -t "$PANE" -p > "$RESULTS_DIR/worker-$i.txt"
    ((i++))
done <<< "$NEW_PANES"

echo "Results captured to $RESULTS_DIR/"
```

### Step 2: Read and summarize results

After the script completes, read each result file and provide a summary:

```bash
cat /tmp/claude-parallel-results/worker-1.txt
cat /tmp/claude-parallel-results/worker-2.txt
cat /tmp/claude-parallel-results/worker-3.txt
cat /tmp/claude-parallel-results/worker-4.txt
```

For each worker:
1. Summarize the key points of their response
2. Note any unique approaches or insights
3. Highlight consensus or differences across workers
4. Provide a synthesized recommendation if applicable

### Step 3: Clean up panes

After summarizing, close the worker panes:

```bash
#!/bin/bash
ORIGINAL_PANE=$(tmux display-message -p '#{pane_id}')
PANES_TO_KILL=$(tmux list-panes -F '#{pane_id}' | grep -v "^${ORIGINAL_PANE}$")

if [ -n "$PANES_TO_KILL" ]; then
    while IFS= read -r PANE; do
        if [ -n "$PANE" ]; then
            tmux kill-pane -t "$PANE" 2>/dev/null
        fi
    done <<< "$PANES_TO_KILL"
    echo "Worker panes closed."
fi
```

## Important Notes

- This only works inside a tmux session
- Workers are interactive Claude instances (you can watch them work)
- 10 minute timeout, polling every 10 seconds
- Completion detected by: content stability + `>` prompt visible
- Results saved to `/tmp/claude-parallel-results/`

## Example Usage

```
/parallel write a function to parse CSV files in Python
```
