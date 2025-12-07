# Commits, pushes, and creates/opens a GitHub PR from the current branch name
# Specifically for JIRA ticket branch names
function ghprall
    # Get the current branch name
    set -l branch (git branch --show-current)

    # Check if we are on a branch
    if test -z "$branch"
        echo "❌ Error: Not a git repository or no branch is checked out."
        return 1
    end

    # Parse the branch to create the commit message
    set -l ticket (echo "$branch" | sed -E "s/^([A-Z]+-[0-9]+).*/\1/")
    set -l desc (echo "$branch" | sed -E "s/^[A-Z]+-[0-9]+-//" | tr "-" " ")
    set -l commit_message "$ticket: $desc"

    # Execute the git commands
    git commit -am "$commit_message"
    and git push
    and gh pr create --fill --web
end
