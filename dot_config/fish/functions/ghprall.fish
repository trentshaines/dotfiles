# Commits, pushes, and creates/opens a GitHub PR from the current branch name
# Specifically for JIRA ticket branch names
# Usage: ghprall [optional commit message]
function ghprall
    # Get the current branch name
    set -l branch (git branch --show-current)

    # Check if we are on a branch
    if test -z "$branch"
        echo "❌ Error: Not a git repository or no branch is checked out."
        return 1
    end

    # Use provided commit message or generate from branch name
    set -l commit_message
    if test (count $argv) -gt 0
        set commit_message "$argv"
    else
        # Parse the branch to create the commit message
        set -l ticket (echo "$branch" | sed -E "s/^([A-Z]+-[0-9]+).*/\1/")
        set -l desc (echo "$branch" | sed -E "s/^[A-Z]+-[0-9]+-//" | tr "-" " ")
        set commit_message "$ticket: $desc"
    end

    # Execute the git commands
    git commit -am "$commit_message"
    and git push -u origin HEAD
    and gh pr create --fill --web
end
