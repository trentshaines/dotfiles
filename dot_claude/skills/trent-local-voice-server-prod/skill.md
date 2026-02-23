---
name: trent-local-voice-server-prod
description: Deploy the local voice development server with ngrok for outbound calling. Use when the user asks to test voice locally, start the voice server, or debug voice calls.
---

# Local Voice Server Deployment (Production)

Deploy the local voice development server with ngrok tunnel for outbound calling. This runs:
1. ngrok (to expose voice server to internet)
2. Voice server (port 8080, with ngrok URL)
3. Backend server (port 8000)
4. Frontend (port 3000)

## Manual Steps (if running without tmux automation)

1. Start ngrok: `ngrok http 8080`
2. Get URL: `curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url'`
3. Voice server: `DECAGON_ENV=prod VOICE_OUTBOUND_BASE_URL=<ngrok-url> uvicorn backend.server_cs.voice_server:app --reload --port 8080`
4. Backend: `DECAGON_ENV=prod uvicorn backend.server_cs.server:app --reload --port 8000`
5. Frontend: `cd frontend && DECAGON_ENV=prod yarn run dev`

## Full Script (Automated 2x2 Layout)

Creates 4 NEW panes (leaves Claude Code pane untouched):
```
[Claude] | [ngrok]   | [backend]
         | [voice]   | [frontend]
```

```bash
# Create 4 NEW panes - don't touch the original Claude Code pane
# 1. Split right for ngrok
NGROK_PANE=$(tmux split-window -h -P -F '#{pane_id}')

# 2. Split ngrok down for voice
VOICE_PANE=$(tmux split-window -v -t "$NGROK_PANE" -P -F '#{pane_id}')

# 3. Split ngrok right for backend
BACKEND_PANE=$(tmux split-window -h -t "$NGROK_PANE" -P -F '#{pane_id}')

# 4. Split voice right for frontend
FRONTEND_PANE=$(tmux split-window -h -t "$VOICE_PANE" -P -F '#{pane_id}')

# Layout is now:
# [Claude] | [ngrok]   | [backend]
#          | [voice]   | [frontend]

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

# 8. Start voice server (with ngrok URL) - use 'env' for fish shell compatibility
tmux send-keys -t "$VOICE_PANE" "env DECAGON_ENV=prod VOICE_OUTBOUND_BASE_URL=$NGROK_URL uvicorn backend.server_cs.voice_server:app --reload --port 8080" Enter

# 9. Start backend - use 'env' for fish shell compatibility
tmux send-keys -t "$BACKEND_PANE" 'env DECAGON_ENV=prod uvicorn backend.server_cs.server:app --reload --port 8000' Enter

# 10. Start frontend - use 'env' for fish shell compatibility
tmux send-keys -t "$FRONTEND_PANE" 'cd frontend && env DECAGON_ENV=prod yarn run dev' Enter

echo "Voice development environment started!"
echo "ngrok URL: $NGROK_URL"
echo ""
echo "Layout:"
echo "  [Claude] | [ngrok]   | [backend]"
echo "           | [voice]   | [frontend]"
echo ""
echo "To test: Go to http://localhost:3000 -> Preview -> Voice -> Enter phone # and select agent"
```

## Prerequisites

- ngrok installed and authenticated (`ngrok config add-authtoken <token>`)
- tmux running
- jq installed (for parsing ngrok API response)

## Expected Result

- ngrok tunnel running, exposing port 8080
- Voice server at http://localhost:8080 (with VOICE_OUTBOUND_BASE_URL set)
- Backend at http://localhost:8000
- Frontend at http://localhost:3000
- Test via: Preview -> Voice -> Enter phone # & select voice agent

## Notes

- This is for **outbound calling** without Twilio webhook setup
- For inbound calling, you need to update the webhook URL in Twilio
- The ngrok URL changes each time unless you have a paid ngrok plan with reserved domains
