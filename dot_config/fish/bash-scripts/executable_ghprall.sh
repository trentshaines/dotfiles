#!/bin/bash
# Commits, pushes, and creates/opens a GitHub PR from the current branch name
# Specifically for JIRA ticket branch names
# Usage: ghprall [optional commit message]

# Get the current branch name
branch=$(git branch --show-current)

# Check if we are on a branch
if [ -z "$branch" ]; then
    echo "❌ Error: Not a git repository or no branch is checked out."
    exit 1
fi

# Use provided commit message or generate from branch name
if [ $# -gt 0 ]; then
    commit_message="$*"
else
    # Parse the branch to create the commit message
    ticket=$(echo "$branch" | sed -E "s/^([A-Z]+-[0-9]+).*/\1/")
    desc=$(echo "$branch" | sed -E "s/^[A-Z]+-[0-9]+-//" | tr "-" " ")
    commit_message="$ticket: $desc"
fi

# Execute the git commands
git commit -am "$commit_message" && \
git push -u origin HEAD && \
gh pr create --fill --web
