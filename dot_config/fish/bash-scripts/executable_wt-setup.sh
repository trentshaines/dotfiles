#!/bin/bash
# Set up a new git worktree with envrc and dependencies

echo "🔧 Starting worktree setup..."

MAIN_REPO=$(git worktree list | head -1 | awk '{print $1}')
echo "📁 Main repo: $MAIN_REPO"
echo "📂 Worktree: $(pwd)"

if [ -f "$MAIN_REPO/.envrc" ]; then
    echo "📋 Copying .envrc..."
    cp "$MAIN_REPO/.envrc" .envrc
    echo "✅ Copied .envrc"
    echo "🔓 Running direnv allow..."
    direnv allow .
    echo "✅ direnv allowed"
else
    echo "⚠️  No .envrc found in main repo"
fi

if [ -f "$MAIN_REPO/frontend/.env" ]; then
    echo "📋 Copying frontend/.env..."
    cp "$MAIN_REPO/frontend/.env" frontend/.env
    echo "✅ Copied frontend/.env"
else
    echo "⚠️  No frontend/.env found in main repo"
fi

if [ -f "$MAIN_REPO/.mcp.json" ]; then
    echo "📋 Copying .mcp.json..."
    cp "$MAIN_REPO/.mcp.json" .mcp.json
    echo "✅ Copied .mcp.json"
else
    echo "⚠️  No .mcp.json found in main repo"
fi

if [ -d "$MAIN_REPO/.claude/skills" ]; then
    echo "📋 Copying .claude/skills/..."
    mkdir -p .claude
    cp -r "$MAIN_REPO/.claude/skills" .claude/
    echo "✅ Copied .claude/skills/"
fi

if [ -f "$MAIN_REPO/.claude/settings.local.json" ]; then
    echo "📋 Copying .claude/settings.local.json..."
    mkdir -p .claude
    cp "$MAIN_REPO/.claude/settings.local.json" .claude/settings.local.json
    echo "✅ Copied .claude/settings.local.json"
fi

if [ ! -d frontend/node_modules ]; then
    echo "📦 Installing frontend dependencies..."
    cd frontend && yarn install && cd ..
    # Yarn sometimes modifies package.json formatting, restore it
    git checkout frontend/package.json 2>/dev/null || true
    echo "✅ Frontend dependencies installed"
else
    echo "⏭️  frontend/node_modules exists, skipping yarn install"
fi

echo "🔒 Setting skip-worktree for baseline.json..."
git update-index --skip-worktree .basedpyright/baseline.json 2>/dev/null || true

# Unset upstream so push.autoSetupRemote works correctly on first push
echo "🔗 Unsetting upstream (autoSetupRemote will set it on first push)..."
git branch --unset-upstream 2>/dev/null || true

echo "🎉 Worktree setup complete!"
