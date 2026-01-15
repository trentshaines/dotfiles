function wt-setup --description "Set up a new git worktree with envrc and dependencies"
    echo "🔧 Starting worktree setup..."

    set MAIN_REPO (git worktree list | head -1 | awk '{print $1}')
    echo "📁 Main repo: $MAIN_REPO"
    echo "📂 Worktree: "(pwd)

    if test -f "$MAIN_REPO/.envrc"
        echo "📋 Copying .envrc..."
        cp "$MAIN_REPO/.envrc" .envrc
        echo "✅ Copied .envrc"
        echo "🔓 Running direnv allow..."
        direnv allow .
        echo "✅ direnv allowed"
    else
        echo "⚠️  No .envrc found in main repo"
    end

    if test -f "$MAIN_REPO/frontend/.env"
        echo "📋 Copying frontend/.env..."
        cp "$MAIN_REPO/frontend/.env" frontend/.env
        echo "✅ Copied frontend/.env"
    else
        echo "⚠️  No frontend/.env found in main repo"
    end

    if not test -d frontend/node_modules
        echo "📦 Installing frontend dependencies..."
        cd frontend; and yarn install; and cd ..
        echo "✅ Frontend dependencies installed"
    else
        echo "⏭️  frontend/node_modules exists, skipping yarn install"
    end

    echo "🔒 Setting skip-worktree for baseline.json..."
    git update-index --skip-worktree .basedpyright/baseline.json 2>/dev/null; or true

    echo "🎉 Worktree setup complete!"
end
