---
name: tui-building
description: Building terminal UI tools with Bubble Tea and the shared trenthaines.dev/tui package. Use when creating TUI pickers, popups, or any interactive terminal tools — covers the shared package, layout patterns, testing, chezmoi integration, and known gotchas.
---

# TUI Building

## Shared Package: `trenthaines.dev/tui`

Source: `~/.config/tui/` (chezmoi-managed)
Import: `ui "trenthaines.dev/tui"`

Add to any new tool's `go.mod`:
```
require trenthaines.dev/tui v0.0.0
replace trenthaines.dev/tui => /Users/trenthaines/.config/tui
```

### Colors (TokyoNight Moon + tmux)
```go
ui.BG, ui.FG, ui.FGDim, ui.FGBold       // backgrounds / foregrounds
ui.Yellow, ui.Orange, ui.Red             // syntax
ui.Green, ui.Teal, ui.Cyan, ui.Blue      // syntax
ui.Purple, ui.Violet                     // syntax
ui.Comment, ui.Border, ui.Inactive       // UI muted
ui.Highlight   // #fff2cc — matches tmux status bar yellow
ui.TmuxPink    // #ff10f0 — matches tmux prefix indicator
```

### Semantic aliases
```go
ui.ColorActive    // Teal  — something running
ui.ColorDone      // Comment — completed/muted
ui.ColorSelected  // Yellow — cursor row
ui.ColorMarked    // Orange — tab-selected for action
```

### Pre-built styles
```go
ui.SNormal, ui.SBright, ui.SDim
ui.SSelected, ui.SMarked, ui.SSelMark, ui.SActive, ui.SDone
ui.SInfo, ui.SSubtle
ui.STitle    // plain yellow bold
ui.SFooter   // muted footer text
ui.SBorder   // double border (═), white — for inner panels
ui.SPreview  // dim text with left padding — for preview content
```

### Component functions
```go
// Full-width solid yellow title bar (matches tmux). Zero out TitleBar padding:
//   l.Styles.TitleBar = lipgloss.NewStyle()
//   l.Styles.Title = ui.SolidTitle(width)
ui.SolidTitle(width int) lipgloss.Style

// Preview box — double border, white, inner content padded
ui.PreviewBox(content string, width, maxLines int) string

// Side panel preview with explicit height (for side-by-side layout)
ui.PreviewPanel(content string, width, height, maxLines int) string

// Key hint footer — "enter:switch  ·  q:quit"
ui.Footer(hints ...string) string

// Ensure View() always outputs exactly h lines — REQUIRED for stable inline rendering
ui.FillHeight(s string, h int) string

// Selection markers
ui.Caret()        // ❯ in TmuxPink — selected row
ui.ActiveMark()   // ▶ in Teal — currently active pane
ui.MarkedBullet() // ◉ in Orange — tab-selected for dismiss

// Pre-styled bubbles/list factory
ui.NewList(items, delegate, width, height) list.Model
ui.NewSolidTitleList(title, items, delegate, width, height) list.Model

// fzf-style search input (cursor in TmuxPink, pre-focused)
ui.NewSearchInput(placeholder string) textinput.Model
ui.SearchPrompt(ti textinput.Model) string  // renders ❯ + input

// Async tmux pane capture
ui.PanePreviewCmd(paneID string, lines int) tea.Cmd  // delivers PanePreviewMsg
```

### Embeddable base model
```go
type model struct {
    ui.Base          // provides Width, Height, Quitting
    list  list.Model
    // ...
}
// Helpers: m.Resize(msg), m.Quit(), ui.IsQuit(keyMsg)
```

---

## New Tool Checklist

1. **Create source dir** — put source under `~/.config/` or `~/.claude/scripts/`
2. **go.mod** — init + add `trenthaines.dev/tui` replace directive
3. **Binary** — build to `~/bin/<name>`
4. **chezmoi** — `chezmoi add <source-dir>/`
5. **run_onchange** — create `~/.local/share/chezmoi/run_onchange_build-<name>.sh.tmpl`:
   ```bash
   #!/bin/bash
   # source: {{ include "path/to/main.go" | sha256sum }}
   /opt/homebrew/bin/go build -o ~/bin/<name> ~/.../source/
   ```
6. **Popup binding** — in `tmux.conf`:
   ```
   bind-key X display-popup -E -w 70% -h 50% -b rounded -S "fg=#ffffff" \
       -e "TMUX_CLIENT_WIDTH=#{client_width}" \
       -e "TMUX_CLIENT_HEIGHT=#{client_height}" \
       "/bin/bash $HOME/.../pick.sh"
   ```
   Shell wrapper writes result to temp file:
   ```bash
   RESULT=$(mktemp)
   ~/bin/<name> "$RESULT"
   [[ -s "$RESULT" ]] && do-something "$(cat $RESULT)"
   rm -f "$RESULT"
   ```

---

## Layout Patterns

### Standard side-by-side (list left, preview right)
```go
func (m model) View() string {
    if m.quitting || m.Width == 0 { return "" }  // CRITICAL: guard before WindowSizeMsg

    listW  := m.Width * 58 / 100
    prevW  := m.Width - listW
    listH  := m.Height - 2  // title(1) + footer(1)

    title   := ui.SolidTitle(m.Width).Render("My Tool")
    preview := ui.PreviewPanel(m.preview, prevW, listH, 0)
    body    := lipgloss.JoinHorizontal(lipgloss.Top, m.list.View(), preview)
    footer  := ui.Footer("enter:select", "q:quit")

    return ui.FillHeight(title+"\n"+body+"\n"+footer, m.Height)
}
```

### WindowSizeMsg handler
```go
case tea.WindowSizeMsg:
    m.Width, m.Height = msg.Width, msg.Height
    listW := msg.Width * 58 / 100
    listH := msg.Height - 2
    m.list.SetWidth(listW)
    m.list.SetHeight(listH)
    m.list.SetDelegate(myDelegate{c: makeCols(listW)})
    m.list.Styles.Title = ui.SolidTitle(listW)  // if title is inside list
```

### fzf-style search (manual filter, no bubbles/list filter)
```go
// Preferred: manual filter + textinput, like pane-picker
// Avoids bubbles/list filter chrome instability

type model struct {
    input    textinput.Model
    list     list.Model
    allItems []Item
}

// In Update, default key handler:
default:
    var cmd tea.Cmd
    m.input, cmd = m.input.Update(msg)
    filtered := filterItems(m.allItems, m.input.Value())
    m.list.SetItems(toListItems(filtered))
    return m, cmd
```

---

## Known Gotchas

### NEVER use `tea.WithAltScreen()` in tmux popups
There is a confirmed Bubble Tea bug where AltScreen takes a second to kick in inside tmux, causing visual glitches. Just omit it — the popup provides a clean terminal already.

```go
// WRONG — causes jump/glitch in tmux popup:
tea.NewProgram(model, tea.WithAltScreen())

// RIGHT:
tea.NewProgram(model)
```

### Always guard View() until WindowSizeMsg fires
```go
func (m model) View() string {
    if m.quitting || m.Width == 0 { return "" }  // empty first frame
    // ...
}
```
Initialize `width, height := 0, 0` in main(). The first render outputs nothing, WindowSizeMsg fires immediately and sets real dimensions, then full render happens correctly.

### Always use FillHeight
Without AltScreen, Bubble Tea uses cursor movement math to redraw. If View() outputs different line counts between frames (e.g., preview changes height), the cursor drifts and layout shifts. `FillHeight` pads/trims to always output exactly `m.Height` lines.

### Column widths use listW not full width
```go
// newModel: compute listW FIRST, then use it for delegate columns
listW := width * 58 / 100
c := makeCols(listW)   // NOT makeCols(width)
l := list.New(items, delegate{c: c}, listW, listH)
```

### Popup height includes border rows
`display-popup -h 50%` allocates 50% of client height INCLUDING the popup's top/bottom border (2 rows). The terminal inside gets slightly fewer rows. Trust `WindowSizeMsg.Height` as the authoritative value.

### Binary not in chezmoi — source is
Compile the binary to `~/bin/` (which is `.chezmoiignore`d). Only commit the source. The `run_onchange_` script rebuilds on any machine after `chezmoi apply`.

---

## Testing Without Affecting Terminal

Use a **detached tmux window** + `capture-pane`:

```bash
# Open in hidden background window
WIN=$(tmux new-window -d -n "tui-test" -P -F "#{window_id}" \
  "env TMUX_CLIENT_WIDTH=$(tmux display-message -p '#{client_width}') \
       TMUX_CLIENT_HEIGHT=$(tmux display-message -p '#{client_height}') \
       ~/bin/my-tool /tmp/test-result.txt")

sleep 1.5  # wait for first render

# Capture what rendered
tmux capture-pane -t "$WIN" -p | head -30

# Clean up
tmux kill-window -t "$WIN"
```

This is a static snapshot — good for verifying initial layout and content. Can't test interactive scrolling/keypress behavior. For that, use `charmbracelet/x/exp/teatest`.

---

## Existing TUI Tools

| Tool | Source | Binary | Popup |
|------|--------|--------|-------|
| Agent Notifications | `~/.claude/scripts/notify-picker/` | `~/bin/agent-notify-picker` | `prefix+e` via `claude-popup.sh` |
| All Panes | `~/.config/tmux/pane-picker/` | `~/bin/pane-picker` | `prefix+E` |

Both use `trenthaines.dev/tui`, side-by-side layout, FillHeight, no AltScreen.
