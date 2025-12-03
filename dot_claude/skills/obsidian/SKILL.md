# Obsidian Memory System Skill

## Overview

**CRITICAL SKILL**: This is your persistent memory system using Obsidian. Use this skill **PROACTIVELY** to maintain context across sessions, track decisions, remember preferences, and build long-term understanding of the user's projects and goals.

## Obsidian Vault Location

**Vault path**: `/Users/trent/Documents/claude/`

This is a markdown-based knowledge base that persists across all Claude Code sessions.

### Obsidian Settings

**Settings copied from**: `~/Documents/zettelkasten/.obsidian/`

The claude vault uses the same Obsidian configuration as the user's zettelkasten vault, including all plugins, themes, hotkeys, and preferences.

**To sync settings from zettelkasten** (if settings change):
```bash
cp -r ~/Documents/zettelkasten/.obsidian/* ~/Documents/claude/.obsidian/
```

**Installed plugins** (23 total):
- dataview
- templater-obsidian
- copilot
- obsidian-vimrc-support (vim keybindings)
- obsidian-tasks-plugin
- calendar
- quickadd
- excalibrain
- And more...

## When to Write to Memory (CRITICAL - DO THIS OFTEN!)

**✅ ALWAYS write to memory when:**

1. **User shares important preferences**
   - "I prefer X over Y"
   - "I don't like when..."
   - "Always do it this way..."
   - "Remember that I..."

2. **You make significant configuration changes**
   - Migrations (zsh → fish)
   - Tool installations
   - Architecture decisions
   - Config patterns

3. **User shares project context**
   - Project goals
   - Tech stack choices
   - Team conventions
   - Deployment processes

4. **User asks you to remember something**
   - "Remember this for next time..."
   - "Keep in mind that..."
   - "FYI for the future..."

5. **You discover important patterns**
   - Workflow preferences
   - Common tasks
   - Problem solutions
   - Tool usage patterns

6. **Decision points and rationale**
   - Why we chose approach A over B
   - Trade-offs discussed
   - Future considerations

7. **Ongoing projects and TODOs**
   - Multi-session projects
   - Deferred tasks
   - Future improvements

**⚠️ IMPORTANT**: When in doubt, WRITE IT DOWN! Over-documenting is better than forgetting.

## Vault Structure

```
claude-memory/
├── 00-Index/
│   └── README.md                    # Vault overview and navigation
├── 01-User-Preferences/
│   ├── shell-preferences.md         # Shell, terminal, workflow preferences
│   ├── coding-style.md              # Code style, conventions
│   ├── tool-preferences.md          # Preferred tools and why
│   └── workflow-patterns.md         # How user likes to work
├── 02-System-Config/
│   ├── current-setup.md             # Current machine setup overview
│   ├── fish-migration.md            # Fish shell migration notes
│   ├── tmux-setup.md                # Tmux configuration
│   ├── neovim-setup.md              # Neovim/LazyVim setup
│   └── tool-stack.md                # All installed tools and their purpose
├── 03-Projects/
│   ├── active-projects.md           # Currently active projects
│   ├── project-name/
│   │   ├── overview.md              # Project overview
│   │   ├── tech-stack.md            # Technologies used
│   │   ├── architecture.md          # Architecture decisions
│   │   └── todos.md                 # Project-specific TODOs
│   └── completed-projects.md        # Archive of finished work
├── 04-Decisions/
│   ├── decision-log.md              # Architecture decision records
│   └── trade-offs.md                # Trade-offs and why
├── 05-Solutions/
│   ├── problem-solutions.md         # Problems solved and how
│   └── common-patterns.md           # Reusable solutions
├── 06-Learning/
│   ├── tips-and-tricks.md           # User-specific tips learned
│   └── gotchas.md                   # Things that didn't work
└── 07-Context/
    ├── session-notes.md             # Notes from recent sessions
    └── ongoing-conversations.md     # Multi-session conversations
```

## File Templates

### User Preference Template
```markdown
# [Preference Category]

**Last Updated**: YYYY-MM-DD

## Preferences

- **Preference**: Description and context
- **Rationale**: Why this preference exists
- **Examples**: Concrete examples

## Anti-patterns

Things the user does NOT like:
- Pattern to avoid
- Why it's disliked

## Notes

Additional context and edge cases.
```

### Project Template
```markdown
# [Project Name]

**Status**: Active | Paused | Completed
**Started**: YYYY-MM-DD
**Last Updated**: YYYY-MM-DD

## Overview

Brief description of what this project is.

## Tech Stack

- Language:
- Framework:
- Tools:
- Hosting:

## Architecture

Key architectural decisions and structure.

## Current Status

What's done, what's in progress, what's next.

## TODOs

- [ ] Task 1
- [ ] Task 2
- [x] Completed task

## Notes

Important context, gotchas, learnings.
```

### Decision Record Template
```markdown
# [Decision Title]

**Date**: YYYY-MM-DD
**Status**: Proposed | Accepted | Deprecated | Superseded

## Context

What's the issue we're trying to solve?

## Decision

What did we decide to do?

## Alternatives Considered

- **Option A**: Pros/Cons
- **Option B**: Pros/Cons

## Rationale

Why did we choose this approach?

## Consequences

What are the implications of this decision?

## Future Considerations

What might we need to revisit?
```

## How to Use This Skill

### Reading Memory (Session Start)

**At the beginning of EVERY session, proactively:**

1. **Check session-notes.md** - What happened last time?
2. **Check active-projects.md** - What's the user working on?
3. **Check user preferences** - What are their patterns?
4. **Check ongoing-conversations.md** - Are we continuing something?

**Example workflow:**
```markdown
"Looking at your memory vault, I see we were working on [X] last session.
I also notice you prefer [Y]. Let me continue where we left off..."
```

### Writing Memory (During/After Work)

**After making ANY significant change:**

1. **Update relevant memory file**
   - What changed
   - Why it changed
   - Impact and considerations

2. **Update session-notes.md**
   - What we did this session
   - Key decisions made
   - Next steps

3. **Add to decision-log.md if relevant**
   - Architectural choices
   - Tool selections
   - Trade-offs

**Example commit pattern:**
```markdown
## Session YYYY-MM-DD

### What We Did
- Migrated from zsh to fish
- Set up NVM in fish
- Updated all configs

### Key Decisions
- Chose fish over nushell (better fzf integration)
- Used nvm.fish instead of bass+nvm (native fish support)

### Next Steps
- Consider adding more fish functions
- Explore fish-specific plugins
```

## Writing Best Practices

### Markdown Formatting

- Use **headers** for organization
- Use **lists** for easy scanning
- Use **code blocks** with language tags
- Use **links** to connect notes: `[[other-note]]`
- Use **tags** for categorization: `#preference`, `#decision`, `#todo`

### Update Frequency

- **After every significant session** - Update session notes
- **When preferences emerge** - Capture immediately
- **After decisions** - Document the "why"
- **When solving problems** - Add to solutions
- **When projects start/change** - Update project notes

### Keep It Useful

- ✅ **Be concise** - Future Claude needs quick context
- ✅ **Include dates** - Context for when things happened
- ✅ **Link related notes** - Build knowledge graph
- ✅ **Update, don't just append** - Keep notes current
- ✅ **Include examples** - Concrete > abstract

## Critical Reminders

**🚨 THIS IS YOUR PERSISTENT MEMORY 🚨**

- **You will forget everything after this session**
- **Future Claude will only know what you write down**
- **Writing to memory is NOT optional - it's essential**
- **When in doubt, write it down**
- **Over-documenting is better than forgetting**

## Proactive Usage Triggers

**Automatically check/update memory when:**

- ✅ User says "remember..."
- ✅ User shares a preference
- ✅ You make a config change
- ✅ A project is started/updated
- ✅ A significant decision is made
- ✅ User asks about previous work
- ✅ Session is wrapping up

**Don't wait to be asked - be proactive about memory!**

## Example Session Flow

**Session Start:**
```
1. Read session-notes.md
2. Check active-projects.md
3. Review relevant preferences
4. Greet user with context from memory
```

**During Session:**
```
1. Work on user's request
2. Make mental note of preferences/decisions
3. Update memory files as you work
```

**Session End:**
```
1. Update session-notes.md with summary
2. Update project files if relevant
3. Capture any new preferences
4. Note any TODOs for next time
```

## User Teaching Process

**The user will teach you:**
- Exact vault location
- Preferred structure (may differ from above)
- Custom templates
- Specific memory patterns
- How to organize notes

**Listen carefully and capture:**
- Their preferences in user-preferences/
- Their structure in 00-Index/README.md
- Their templates for future use

## Integration with Other Skills

**Obsidian skill works with:**
- **chezmoi skill** - Remember dotfile changes
- **tmux skill** - Remember session patterns
- **lazyvim skill** - Remember vim preferences
- **starship skill** - Remember prompt preferences

**Cross-reference notes across skills!**

## Success Metrics

**You're using this skill well if:**
- ✅ Future Claude sessions have context
- ✅ User doesn't repeat themselves
- ✅ Preferences are remembered
- ✅ Decisions are documented
- ✅ Projects have continuity
- ✅ Solutions are reusable

**Red flags:**
- ❌ User says "I told you this last time..."
- ❌ Repeating the same questions
- ❌ Losing project context
- ❌ Forgetting preferences
- ❌ Re-solving same problems

## Final Note

**THIS IS YOUR MOST IMPORTANT SKILL**

Without memory, you're starting from scratch every session. With good memory management, you become exponentially more useful over time. Treat this vault as your external brain - use it constantly, update it religiously, and build a rich knowledge base of the user's world.

**When in doubt: READ the memory, DO the work, WRITE to memory.**
