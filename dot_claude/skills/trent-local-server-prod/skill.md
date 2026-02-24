---
name: trent-local-server-prod
description: Deploy the duet local development server pointing to production (DECAGON_ENV=prod). Use when the user asks to start the local server against prod, run the dev environment with prod, or test locally against production.
---

# Local Server Deployment (Production)

Deploy the local development server pointing to the production environment by running both backend and frontend in separate tmux panes with `DECAGON_ENV=prod`.

## Instructions

1. Split the current tmux pane horizontally to create a second pane
2. Split again to create a third pane (for the original shell to remain usable)
3. In the first split pane, run the backend with prod env:
   ```bash
   DECAGON_ENV=prod uv pip install -r backend/requirements.in && DECAGON_ENV=prod uvicorn backend.server_cs.server:app --reload
   ```
4. In the second split pane, run the frontend with prod env:
   ```bash
   cd frontend && DECAGON_ENV=prod yarn run dev --webpack
   ```

## Tmux Commands

Use pane IDs for robustness (relative targets like `{right}` fail when other panes exist):

```bash
# Split horizontally for backend, capturing the pane ID
BACKEND_PANE=$(tmux split-window -h -P -F '#{pane_id}')

# Run backend install and server in that pane using its ID
tmux send-keys -t "$BACKEND_PANE" 'DECAGON_ENV=prod uv pip install -r backend/requirements.in && DECAGON_ENV=prod uvicorn backend.server_cs.server:app --reload' Enter

# Split the backend pane vertically for frontend, capturing the pane ID
FRONTEND_PANE=$(tmux split-window -v -t "$BACKEND_PANE" -P -F '#{pane_id}')

# Run frontend in the new pane using its ID
tmux send-keys -t "$FRONTEND_PANE" 'cd frontend && DECAGON_ENV=prod yarn run dev --webpack' Enter
```

## Expected Result

- Backend API running at http://localhost:8000 (with hot reload, pointing to prod)
- Frontend Next.js dev server running at http://localhost:3000 (pointing to prod)
- Original pane remains available for other commands
