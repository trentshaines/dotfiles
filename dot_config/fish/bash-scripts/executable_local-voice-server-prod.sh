#!/bin/bash
# Local Voice Server (Production) - Deploys voice dev environment with ngrok
# Layout:
#   [current] | [ngrok]   | [backend]
#             | [voice]   | [frontend]

set -e

# Create 4 NEW panes - don't touch the original pane
# 1. Split right for ngrok
NGROK_PANE=$(tmux split-window -h -P -F '#{pane_id}')

# 2. Split ngrok down for voice
VOICE_PANE=$(tmux split-window -v -t "$NGROK_PANE" -P -F '#{pane_id}')

# 3. Split ngrok right for backend
BACKEND_PANE=$(tmux split-window -h -t "$NGROK_PANE" -P -F '#{pane_id}')

# 4. Split voice right for frontend
FRONTEND_PANE=$(tmux split-window -h -t "$VOICE_PANE" -P -F '#{pane_id}')

# 5. Start ngrok
tmux send-keys -t "$NGROK_PANE" 'ngrok http 8080' Enter

# 6. Wait for ngrok to initialize
sleep 4

# 7. Get ngrok URL (retry if needed)
for i in 1 2 3 4 5; do
  NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | jq -r '.tunnels[0].public_url' 2>/dev/null)
  if [ -n "$NGROK_URL" ] && [ "$NGROK_URL" != "null" ]; then
    break
  fi
  sleep 2
done

if [ -z "$NGROK_URL" ] || [ "$NGROK_URL" = "null" ]; then
  echo "ERROR: Could not get ngrok URL. Check if ngrok is running."
  exit 1
fi

echo "ngrok URL: $NGROK_URL"

# 8. Start voice server (with ngrok URL)
tmux send-keys -t "$VOICE_PANE" "DECAGON_ENV=prod VOICE_OUTBOUND_BASE_URL=$NGROK_URL uvicorn backend.server_cs.voice_server:app --reload --port 8080" Enter

# 9. Start backend
tmux send-keys -t "$BACKEND_PANE" 'DECAGON_ENV=prod uvicorn backend.server_cs.server:app --reload --port 8000' Enter

# 10. Start frontend
tmux send-keys -t "$FRONTEND_PANE" 'cd frontend && DECAGON_ENV=prod yarn run dev' Enter

echo ""
echo "Voice development environment started!"
echo "ngrok URL: $NGROK_URL"
echo ""
echo "Layout:"
echo "  [current] | [ngrok]   | [backend]"
echo "            | [voice]   | [frontend]"
echo ""
echo "To test: Go to http://localhost:3000 -> Preview -> Voice -> Enter phone # and select agent"
