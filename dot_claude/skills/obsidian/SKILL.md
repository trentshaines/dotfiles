---
name: obsidian
description: Help with Obsidian Zettelkasten vault management - search, create, edit, and organize notes in the user's personal knowledge base with 1200+ notes. Use when the user asks about their Zettelkasten, vault, notes, knowledge management, or wants to create/modify markdown notes in ~/Documents/Zettelkasten. (project, gitignored)
---

# Obsidian Zettelkasten Skill

## Overview

Help user interact with their personal Zettelkasten vault — a knowledge management system with 1200+ notes covering learning, projects, and ideas.

## Vault Location

**Path**: `~/Documents/Zettelkasten/`

## Vault Structure

```
Zettelkasten/
├── copilot/          # AI copilot files
├── Files/            # Attachments, images, PDFs
├── Reference/        # Reference materials
├── Templates/        # Note templates
└── Zettelkasten/     # Main notes directory
    ├── Life/         # Personal planning, tasks, projects
    ├── Notes/        # Main knowledge notes
    └── Writings/     # Essays, diary entries
```

## Obsidian CLI (Primary Interface)

**The official Obsidian CLI is installed and enabled.** Requires Obsidian to be running. Always prefer CLI over direct file operations — it respects Obsidian's index, links, templates, and plugins.

**Binary**: `/opt/homebrew/bin/obsidian`
**Syntax**: `obsidian <command> [options]`
**Targeting**: `file=<name>` (resolves like wikilinks), `path=<exact/path.md>`, `vault=<name>`

### When to Use CLI vs Direct File Tools

| Use CLI (`obsidian`) | Use File Tools (Read/Write/Grep) |
|---|---|
| Creating notes (respects templates) | Bulk text search across many files |
| Appending/prepending to notes | Reading note content for analysis |
| Querying backlinks, orphans, deadends | Complex regex searches |
| Managing properties/frontmatter | Editing note body content |
| Searching with Obsidian's index | When Obsidian is not running |
| Working with daily notes | |
| Managing tasks | |
| Link graph analysis | |

### Key CLI Commands

#### Note Operations

```bash
# Create a note (use template= to apply templates)
obsidian create name="My Note" path="Zettelkasten/Notes/My Note.md" content="..." template="Note Template"

# Read a note
obsidian read file="Aristotle"

# Append/prepend to a note
obsidian append file="Coffee Log" content="New entry here"
obsidian prepend file="Task Log" content="- [ ] New task"

# Open a note in Obsidian GUI
obsidian open file="Aristotle" newtab

# Delete a note
obsidian delete file="Old Note"

# Move/rename
obsidian move file="Old Name" to="Zettelkasten/Notes/New Name.md"
obsidian rename file="Old Name" name="New Name"
```

#### Daily Notes

```bash
obsidian daily              # Open today's daily note
obsidian daily:path         # Get daily note path
obsidian daily:read         # Read today's daily note
obsidian daily:append content="- [ ] New task"
obsidian daily:prepend content="## Morning thoughts\n..."
```

#### Search

```bash
# Basic search (returns file paths)
obsidian search query="fish shell" limit=5

# Search with line context (returns matching lines with line numbers)
obsidian search:context query="climbing training" limit=3

# Open search in Obsidian GUI
obsidian search:open query="philosophy"
```

#### Link Graph Analysis (CLI-exclusive power)

```bash
# Backlinks — what links TO a note
obsidian backlinks file="Aristotle" counts

# Outgoing links FROM a note
obsidian links file="Aristotle" total

# Orphan notes (no incoming links) — vault maintenance
obsidian orphans total

# Dead-end notes (no outgoing links) — vault maintenance
obsidian deadends total

# Unresolved links (broken wikilinks) — vault maintenance
obsidian unresolved total
obsidian unresolved counts verbose
```

#### Properties / Frontmatter

```bash
# List all properties in vault (with counts)
obsidian properties counts sort=count

# Read a property from a file
obsidian property:read name="tags" file="Aristotle"

# Set a property
obsidian property:set name="type" value="note" file="My Note"
obsidian property:set name="tags" value="philosophy,greek" type=list file="Aristotle"

# Remove a property
obsidian property:remove name="oldfield" file="My Note"
```

#### Tags

```bash
obsidian tags counts sort=count          # All tags with counts
obsidian tags file="Aristotle"           # Tags for a specific note
obsidian tag name="philosophy" verbose   # Files with a specific tag
```

#### Tasks

```bash
obsidian tasks todo                      # All incomplete tasks
obsidian tasks done                      # All completed tasks
obsidian tasks todo file="Task Log"      # Tasks in a specific file
obsidian tasks daily todo                # Today's incomplete tasks
obsidian task file="Task Log" line=5 toggle  # Toggle a task
```

#### Templates

```bash
obsidian templates                       # List available templates
obsidian template:read name="Note Template"  # Read template content
obsidian template:read name="Note Template" resolve title="My Note"  # Resolve variables
```

#### Vault Health & Info

```bash
obsidian vault                           # Vault name, path, file/folder count, size
obsidian files total                     # Total file count
obsidian files folder="Zettelkasten/Notes"  # Files in a folder
obsidian folders                         # List all folders
obsidian recents                         # Recently opened files
obsidian wordcount file="Being and Time" # Word/char count
obsidian outline file="Aristotle"        # Heading structure
```

#### Plugins & Themes

```bash
obsidian plugins filter=community versions  # List community plugins
obsidian plugins:enabled                    # Enabled plugins
obsidian plugin:enable id="dataview"
obsidian plugin:disable id="dataview"
obsidian plugin:install id="some-plugin" enable
```

### Output Formats

Many commands support `format=json|tsv|csv|text`. Use `format=json` when parsing output programmatically.

### Tips

- `file=` resolves names like wikilinks (case-insensitive, no extension needed)
- `path=` is exact (e.g., `Zettelkasten/Notes/Aristotle.md`)
- Quote values with spaces: `name="My Note"`
- Use `\n` for newline, `\t` for tab in content values
- Add `total` to most list commands to get just the count

## Creating Notes

When creating notes via CLI, use the `template=` option to apply the user's Note Template. If creating manually:

**CRITICAL**: Always add frontmatter:

```yaml
---
created: YYYY-MM-DD
type: note
tags: []
aliases: []
related: []
---
```

**Frontmatter format rules**:

| Field | Format | Example |
|-------|--------|---------|
| `tags` | Empty array or list of lowercase strings | `tags: []` or `tags: [python, networking]` |
| `aliases` | Empty array or list of strings | `aliases: []` or `aliases: [Alt Name]` |
| `related` | Empty array or multi-line wikilinks | See below |
| `type` | One of: `note`, `daily`, `diary`, `weekly`, `quarterly` | `type: note` |

**Related field format** (multi-line, quoted wikilinks):
```yaml
related:
  - "[[Note One]]"
  - "[[Note Two]]"
```

**Key rules**:
- `tags:` are **plain lowercase text**, NOT wikilinks
- `related:` uses **quoted wikilinks** in multi-line format

## Obsidian Plugins Installed

- **dataview**: Query notes with SQL-like syntax
- **templater**: Dynamic templates
- **obsidian-vimrc-support**: Vim keybindings
- **quickadd**: Quick note creation
- **calendar**: Calendar view
- **excalibrain**: Visual knowledge graph
- And 17+ more plugins

## When to Use This Skill

- User asks to search their Zettelkasten
- Wants to create a new note
- References existing notes
- Asks about their knowledge base
- Wants to query/analyze notes
- Vault maintenance (orphans, deadends, unresolved links)
- Daily note operations
- Task management within notes

## Best Practices

1. **Always ask before creating notes** — Don't assume structure
2. **Use search first** — Check if similar notes exist
3. **Respect user's organization** — Follow existing patterns
4. **Suggest connections** — Link related notes when relevant
5. **Use templates** — Always use `template="Note Template"` when creating
6. **Use CLI for link-aware operations** — Backlinks, orphans, properties
7. **Use file tools for heavy text operations** — Bulk reads, complex regex, content analysis

## Important Notes

- This is the user's **personal knowledge base** — treat with care
- Don't make assumptions about structure without asking
- The vault is their long-term memory, not Claude's

## Integration with Other Skills

- **This vault**: User's personal knowledge
- **Memory skill**: Claude's context about the user
- **Different purposes**: Don't confuse the two!
