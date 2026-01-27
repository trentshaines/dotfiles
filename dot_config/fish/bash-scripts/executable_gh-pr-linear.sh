#!/bin/bash
# Create a GitHub PR with Linear ticket info pre-filled
# Usage: gh-pr-linear [-d|--description "desc"] [-t|--testing "notes"] [gh pr create args...]

# Parse arguments
DESCRIPTION=""
TESTING=""
PASSTHROUGH_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--description)
            DESCRIPTION="$2"
            shift 2
            ;;
        -t|--testing)
            TESTING="$2"
            shift 2
            ;;
        *)
            PASSTHROUGH_ARGS+=("$1")
            shift
            ;;
    esac
done

# Get current branch name
branch=$(git branch --show-current)

# Extract ticket ID from branch name (e.g., TECH-17926 from various formats)
# Handles: TECH-17926, trenthaines/tech-17926-..., tech-17926-...
ticket_id=$(echo "$branch" | grep -oiE 'TECH-[0-9]+' | head -1 | tr '[:lower:]' '[:upper:]')

if [ -z "$ticket_id" ]; then
    echo "❌ Could not extract Linear ticket ID from branch: $branch"
    echo "   Expected format: TECH-XXXXX somewhere in branch name"
    exit 1
fi

echo "🔍 Found ticket: $ticket_id"
echo "📡 Fetching Linear ticket info..."

# Fetch ticket info from Linear
ticket_json=$(linearis issues read "$ticket_id" 2>&1)

# Extract fields from JSON (handle linearis debug output)
title=$(echo "$ticket_json" | grep -o '"title": "[^"]*"' | head -1 | cut -d'"' -f4)
ticket_url="https://linear.app/decagon/issue/$(echo "$ticket_id" | tr '[:upper:]' '[:lower:]')"

if [ -z "$title" ]; then
    echo "❌ Could not parse ticket title"
    exit 1
fi

echo "📝 Title: $title"

# Use provided description or fall back to Linear description
if [ -n "$DESCRIPTION" ]; then
    description="$DESCRIPTION"
    echo "📄 Using provided description"
else
    description=$(echo "$ticket_json" | jq -r '.description // empty' 2>/dev/null)
    if [ -z "$description" ]; then
        description="See Linear ticket for details."
    fi
fi

# Use provided testing notes or placeholder
if [ -n "$TESTING" ]; then
    testing="$TESTING"
else
    testing="<!-- Describe the testing you've performed. If you have frontend changes, you must include screenshots and/or screen recordings. -->"
fi

# Build PR body from template
pr_body="## Description

$description

## Testing

$testing

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
gh pr create --title "$ticket_id: $title" --body "$pr_body" "${PASSTHROUGH_ARGS[@]}"
