function gh-pr-linear --description "Create a GitHub PR with Linear ticket info pre-filled"
    # Get current branch name
    set branch (git branch --show-current)

    # Extract ticket ID from branch name (e.g., TECH-17926 from various formats)
    # Handles: TECH-17926, trenthaines/tech-17926-..., tech-17926-...
    set ticket_id (echo $branch | grep -oiE 'TECH-[0-9]+' | head -1 | tr '[:lower:]' '[:upper:]')

    if test -z "$ticket_id"
        echo "❌ Could not extract Linear ticket ID from branch: $branch"
        echo "   Expected format: TECH-XXXXX somewhere in branch name"
        return 1
    end

    echo "🔍 Found ticket: $ticket_id"
    echo "📡 Fetching Linear ticket info..."

    # Fetch ticket info from Linear
    set ticket_json (linearis issues read $ticket_id 2>&1)

    if echo $ticket_json | grep -q '"error"'
        echo "❌ Failed to fetch Linear ticket: $ticket_json"
        return 1
    end

    # Extract fields from JSON
    set title (echo $ticket_json | jq -r '.title // empty')
    set description (echo $ticket_json | jq -r '.description // empty')
    set ticket_url "https://linear.app/decagon/issue/$ticket_id"

    if test -z "$title"
        echo "❌ Could not parse ticket title"
        return 1
    end

    echo "📝 Title: $title"

    # Build PR body from template
    set pr_body "## Description

$description

## Testing

<!-- Describe the testing you've performed. If you have frontend changes, you must include screenshots and/or screen recordings. -->

## Linear Ticket

Fixes [$ticket_id]($ticket_url)

## Risks

<!-- Describe potential risks and how we can monitor them -->

- [ ] Existing monitoring covers these changes
- [ ] New monitoring added (link below)
- [ ] N/A

### Observability

<!-- Describe potential risks and how we can monitor them -->

- [ ] Existing alerting covers these changes
- [ ] New alerting added (link below)
- [ ] N/A

### Deployment and Rollback Plan

<!-- Describe how to deploy and rollback these changes if non-standard deployment steps are needed -->

- [ ] Special deployment (describe below)
- [ ] Special rollback strategy (describe below)
- [ ] Normal deployment and rollback

## Security

<!-- Detail any security implications and mitigations -->

- [ ] Contains security-sensitive changes (describe below)
- [ ] N/A"

    echo "🚀 Creating PR..."

    # Create PR - pass through any additional args (like --web, --draft, etc.)
    gh pr create --title "$ticket_id: $title" --body "$pr_body" $argv
end
