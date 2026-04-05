---
name: obsidian-annotator
description: Create and manage PDF annotations in Obsidian using the Annotator plugin. Use when user asks to annotate, highlight, or comment on a PDF in their vault. Sub-skill of obsidian.
---

# Obsidian Annotator Sub-Skill

## Overview

Create PDF annotations programmatically that render correctly in the Obsidian Annotator plugin (elias-sundqvist/obsidian-annotator). Annotations are stored as markdown in the note file, not embedded in the PDF.

## How Annotator Works

- The plugin uses **PDF.js** + **Hypothesis client** in an iframe
- Annotations are stored as markdown blockquotes with embedded JSON
- Each annotation has two anchoring mechanisms:
  - `TextPositionSelector` — character offsets (fast, but fragile across extractors)
  - `TextQuoteSelector` — exact text + prefix/suffix context (fuzzy fallback, **more reliable**)
- The `TextQuoteSelector` is the **primary reliable anchor** — even if position offsets are approximate, the quote matching will find the correct text

## Setup Requirements for a Note

The note must have `annotation-target` in frontmatter pointing to the PDF:

```yaml
---
annotation-target: "Files/My Paper.pdf"
---
```

The path is relative to the vault root.

## Creating an Annotation

### Step 1: Get the Document Fingerprint

Reuse the fingerprint from an existing annotation in the same note. If none exists, it's derived from the PDF's `/ID` trailer entry (or MD5 of first 1024 bytes as fallback). The fingerprint is a 32-char hex string.

If you need to extract it fresh:
```bash
# The fingerprint from the existing annotation JSON → document.documentFingerprint
# Or extract from PDF: it's the PDF /ID field, or MD5 of first 1024 bytes
python3 -c "
import hashlib
with open('path/to/file.pdf', 'rb') as f:
    print(hashlib.md5(f.read(1024)).hexdigest())
"
```

**Note**: This fallback method may not match the PDF /ID method. Always prefer reusing the fingerprint from an existing annotation.

### Step 2: Find the Target Text

Use `pdftotext` to extract text and find the passage to highlight:

```bash
pdftotext "Files/My Paper.pdf" - | grep -n "target phrase"
```

You need:
- `exact`: The exact text to highlight
- `prefix`: ~30-50 chars before the highlight (for anchoring)
- `suffix`: ~30-50 chars after the highlight (for anchoring)

**Important**: The prefix/suffix help Hypothesis fuzzy-match the location. Be generous with context. The text should match what appears in the PDF, though whitespace differences are tolerated.

### Step 3: Write the Annotation Block

Append this to the note file (after the `## Annotations` section):

```markdown

>%%
>```annotation-json
>{"created":"TIMESTAMP","text":"YOUR COMMENT HERE","updated":"TIMESTAMP","document":{"title":"FILENAME","link":[{"href":"urn:x-pdf:FINGERPRINT"},{"href":"vault:/PATH/TO/PDF"}],"documentFingerprint":"FINGERPRINT"},"uri":"vault:/PATH/TO/PDF","target":[{"source":"vault:/PATH/TO/PDF","selector":[{"type":"TextPositionSelector","start":START,"end":END},{"type":"TextQuoteSelector","exact":"HIGHLIGHTED TEXT","prefix":"TEXT BEFORE ","suffix":" TEXT AFTER"}]}]}
>```
>%%
>*%%PREFIX%%TEXT BEFORE%%HIGHLIGHT%% ==HIGHLIGHTED TEXT== %%POSTFIX%%TEXT AFTER*
>%%LINK%%[[#^ANNOTATION_ID|show annotation]]
>%%COMMENT%%
>YOUR COMMENT HERE
>
>%%TAGS%%
>
^ANNOTATION_ID
```

### Field Reference

| Field | Description | Example |
|-------|-------------|---------|
| `created`/`updated` | ISO 8601 timestamp | `2026-04-05T01:30:00.000Z` |
| `text` | Your comment/note | `Key insight about control` |
| `documentFingerprint` | 32-char hex from PDF | `c2cc5ee7532df5f679608a9935615dd3` |
| `uri` | Vault path to PDF | `vault:/Files/My Paper.pdf` |
| `start`/`end` | Character offsets (approximate OK) | `350`, `500` |
| `exact` | The highlighted text verbatim | `the exact passage` |
| `prefix` | ~30-50 chars before highlight | `context before ` |
| `suffix` | ~30-50 chars after highlight | ` context after` |
| `ANNOTATION_ID` | Unique ID (alphanumeric) | `abc123xyz` |

### Generating the Annotation ID

Use a random alphanumeric string, 8-12 chars. Must be unique within the file.

### Position Offsets (start/end)

These are character offsets into the full concatenated PDF text as extracted by PDF.js. Since `pdftotext` output differs slightly from PDF.js, these will be approximate. **This is fine** — the `TextQuoteSelector` (exact/prefix/suffix) is the reliable fallback anchor.

For approximate offsets, use pdftotext and count characters:
```bash
pdftotext "file.pdf" - | head -c 1000 | wc -c  # rough offset estimation
```

Or just use reasonable estimates. The quote selector does the heavy lifting.

## Example: Creating an Annotation

To annotate "it will be increasingly important to prevent them from causing harmful outcomes" in a paper:

```markdown
>%%
>```annotation-json
>{"created":"2026-04-05T01:30:00.000Z","text":"Core motivation for the paper.","updated":"2026-04-05T01:30:00.000Z","document":{"title":"My%20Paper.pdf","link":[{"href":"urn:x-pdf:c2cc5ee7532df5f679608a9935615dd3"},{"href":"vault:/Files/My%20Paper.pdf"}],"documentFingerprint":"c2cc5ee7532df5f679608a9935615dd3"},"uri":"vault:/Files/My%20Paper.pdf","target":[{"source":"vault:/Files/My%20Paper.pdf","selector":[{"type":"TextPositionSelector","start":350,"end":430},{"type":"TextQuoteSelector","exact":"it will be increasingly important to prevent them from causing harmful outcomes.","prefix":"more powerful and are deployed more autonomously, ","suffix":" Researchers have investigated a"}]}]}
>```
>%%
>*%%PREFIX%%more powerful and are deployed more autonomously,%%HIGHLIGHT%% ==it will be increasingly important to prevent them from causing harmful outcomes.== %%POSTFIX%%Researchers have investigated a*
>%%LINK%%[[#^ann001|show annotation]]
>%%COMMENT%%
>Core motivation for the paper.
>
>%%TAGS%%
>
^ann001
```

## Workflow for Adding Annotations

1. Read the note to get the fingerprint and vault PDF path from existing annotations or frontmatter
2. Use `pdftotext` to extract text around the target passage
3. Pick the exact text, prefix, and suffix
4. Generate a unique annotation ID
5. Append the annotation block to the note
6. **User hits Ctrl+R twice** in Obsidian to refresh the annotator view (toggles annotation mode)

## Multiple Annotations

Just append multiple annotation blocks sequentially. Each needs a unique `^ID`.

## Tags

To add tags, include them in the JSON `"tags":["tag1","tag2"]` and in the markdown:
```
>%%TAGS%%
>#tag1, #tag2
```

## Research Companion Workflow

When the user wants to use Claude for deep reading, comprehension, and annotation of a PDF:

### First-Time Setup for a Paper

1. Copy PDF to vault: `Files/<Paper Name>.pdf`
2. Convert to text for fast reading: `pdftotext "Files/<Paper Name>.pdf" "Files/<Paper Name>.txt"`
3. Create annotation note with `annotation-target` frontmatter
4. The `.txt` file enables instant `Read` access without re-converting each time

### During Research Sessions

- **Read sections**: Use `Read` on the `.txt` file with offset/limit for specific sections
- **Answer questions**: Reference the text directly to explain concepts, summarize arguments, connect ideas
- **Create annotations**: When the user wants to mark important passages, create annotation blocks pointing to the exact text
- **Cross-reference**: Search the vault for related notes and suggest `[[wikilinks]]` to connect ideas
- **Refresh view**: User hits Ctrl+R twice in Obsidian to see new annotations

### File Naming Convention

For each paper, there are up to 3 files:
- `Files/<Paper Name>.pdf` — the original PDF (for Annotator rendering)
- `Files/<Paper Name>.txt` — extracted text (for Claude fast reading)
- `Zettelkasten/Notes/<Paper Name>.md` — the annotation note + user's synthesis

## Gotchas

- The annotation block **must** be a blockquote (every line starts with `>`)
- The `^ID` anchor line must **not** start with `>` — it's outside the blockquote
- There must be a blank line before and after each annotation block
- The `==highlighted text==` in the HIGHLIGHT section is for Obsidian rendering, not for anchoring
- URL-encode spaces in title/path fields with `%20`
- The `prefix` and `suffix` should be long enough for unique matching (~30-50 chars)
