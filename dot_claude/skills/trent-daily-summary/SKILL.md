---
name: trent-daily-summary
description: Generate daily activity summaries from Claude Code logs. Use when the user asks for a daily summary, work log, what they did today/yesterday, or activity report.
---

# Daily Summary Generator

## Overview
Generates concise bullet-point summaries of daily Claude Code activity from hook logs.

## Data Locations
- **Raw logs**: `~/.claude/logs/daily/YYYY-MM-DD/SESSION_ID.jsonl`
- **Summaries**: `~/.claude/logs/summaries/YYYY-MM-DD.md`

## Log Format
Each JSONL file contains entries like:
```json
{"ts": "2026-03-06T...", "event": "prompt", "project": "chezmoi", "prompt": "fix the login bug"}
{"ts": "2026-03-06T...", "event": "stop", "project": "chezmoi"}
```

## How to Generate Summaries

### Step 1: Determine which days need summaries
- If user asks for a specific day, use that day
- If user says "catch up" or "all", find all date directories in `~/.claude/logs/daily/` that don't have a corresponding file in `~/.claude/logs/summaries/`
- If user says "today", use today's date

### Step 2: Read the raw logs
- Read all `*.jsonl` files in `~/.claude/logs/daily/YYYY-MM-DD/`
- Extract only `"event": "prompt"` entries
- Group by project

### Step 3: Generate the summary
- Group prompts by project
- Deduplicate and consolidate similar prompts into single bullet points
- Write concise, action-oriented bullets (e.g., "Added tmux keybinding for last-window")
- Merge trivial follow-ups into the parent task (e.g., "fix typo" after "add feature" = one bullet)
- Ignore conversational prompts that aren't real work (e.g., "yes", "ok", "thanks")

### Step 4: Show the summary and save
- Display each day's summary
- Save the summary file immediately (no need to ask for confirmation)
- If a summary file already exists for that day, show it and ask if the user wants to overwrite before saving

Write to `~/.claude/logs/summaries/YYYY-MM-DD.md` in this format:

```markdown
# YYYY-MM-DD

## project-name
- Bullet point describing what was done
- Another bullet point

## another-project
- What was done here
```

### Step 5: Ask to send to Slack
- After ALL summaries are saved, ask the user if they want to send them to Slack
- Only send after user confirms
- Use the Slack MCP tools to send each summary to the `#trent-compaction` channel (channel ID: C0AJS2NCENP)

## Important Notes
- Keep bullets concise — one line each, action-oriented
- Group related prompts into a single bullet (don't list every prompt separately)
- If a session has only 1-2 trivial prompts, summarize in one bullet
- Skip empty days (no logs = no summary)
