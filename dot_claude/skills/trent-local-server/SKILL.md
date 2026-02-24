---
name: trent-local-server
description: Deploy the duet local development server (backend + frontend) in tmux panes. Use when the user asks to start the local server, run the dev environment, or start backend/frontend.
---

# Local Server Deployment

Deploy the local development server by running both backend and frontend in separate tmux panes.

## Instructions

1. Split the current tmux pane horizontally to create a second pane
2. Split again to create a third pane (for the original shell to remain usable)
3. In the first split pane, run the backend:
   ```bash
   uv pip install -r backend/requirements.in && uvicorn backend.server_cs.server:app --reload
   ```
4. In the second split pane, run the frontend:
   ```bash
   cd frontend && yarn run dev --webpack
   ```

## Tmux Commands

Use pane IDs for robustness (relative targets like `{right}` fail when other panes exist):

```bash
# Split horizontally for backend, capturing the pane ID
BACKEND_PANE=$(tmux split-window -h -P -F '#{pane_id}')

# Run backend install and server in that pane using its ID
tmux send-keys -t "$BACKEND_PANE" 'uv pip install -r backend/requirements.in && uvicorn backend.server_cs.server:app --reload' Enter

# Split the backend pane vertically for frontend, capturing the pane ID
FRONTEND_PANE=$(tmux split-window -v -t "$BACKEND_PANE" -P -F '#{pane_id}')

# Run frontend in the new pane using its ID
tmux send-keys -t "$FRONTEND_PANE" 'cd frontend && yarn run dev --webpack' Enter
```

## Expected Result

- Backend API running at http://localhost:8000 (with hot reload)
- Frontend Next.js dev server running at http://localhost:3000
- Original pane remains available for other commands
