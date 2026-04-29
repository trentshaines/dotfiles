package tui

import (
	"strings"

	"github.com/charmbracelet/bubbles/list"
	"github.com/charmbracelet/bubbles/textinput"
	"github.com/charmbracelet/lipgloss"
)

// ── Ready-to-render components ────────────────────────────────────────────────

// PreviewBox renders lines of content inside the styled double-border box,
// trimming empty lines and keeping only the last maxLines non-empty ones.
// width is the full terminal/popup width — margins are applied automatically.
func PreviewBox(content string, width, maxLines int) string {
	return PreviewPanel(content, width-2, 0, maxLines)
}

// PreviewPanel renders the preview as a right-side panel with explicit dimensions.
// width is the panel's total width (including border). height=0 means auto.
func PreviewPanel(content string, width, height, maxLines int) string {
	innerW := width - 2  // subtract left+right border
	innerH := height - 2 // subtract top+bottom border

	lines := strings.Split(content, "\n")
	var kept []string
	for _, l := range lines {
		if strings.TrimSpace(l) != "" {
			// Truncate each line to inner width so no wrapping escapes the box
			kept = append(kept, Trunc(l, innerW))
		}
	}

	// Clip to innerH lines (take most recent)
	limit := innerH
	if maxLines > 0 && maxLines < limit {
		limit = maxLines
	}
	if limit > 0 && len(kept) > limit {
		kept = kept[len(kept)-limit:]
	}

	s := SBorder.Width(innerW)
	if height > 0 {
		// MaxHeight hard-clips; Height only pads — use both to pin exact size
		s = s.Height(innerH).MaxHeight(height)
	}
	return s.Render(SPreview.Render(strings.Join(kept, "\n")))
}

// FillHeight pads or trims a rendered string to exactly h lines.
// Use this in View() to guarantee consistent line count for inline rendering.
func FillHeight(s string, h int) string {
	lines := strings.Split(s, "\n")
	for len(lines) < h {
		lines = append(lines, "")
	}
	if len(lines) > h {
		lines = lines[:h]
	}
	return strings.Join(lines, "\n")
}

// Footer renders a hint bar from key:action pairs, e.g. Footer("enter:switch", "q:quit").
func Footer(hints ...string) string {
	sKey := lipgloss.NewStyle().Foreground(Highlight).Bold(true)
	sAct := lipgloss.NewStyle().Foreground(FGDim)
	sSep := lipgloss.NewStyle().Foreground(Inactive).Render("  ·  ")

	parts := make([]string, 0, len(hints))
	for _, h := range hints {
		k, v, ok := strings.Cut(h, ":")
		if !ok {
			parts = append(parts, SFooter.Render(h))
			continue
		}
		parts = append(parts, sKey.Render(k)+sAct.Render(":"+v))
	}
	return "  " + strings.Join(parts, sSep)
}

// Caret returns the ❯ selection marker in TmuxPink.
func Caret() string {
	return lipgloss.NewStyle().Foreground(TmuxPink).Bold(true).Render("❯ ")
}

// ActiveMark returns the ▶ active-pane marker in teal.
func ActiveMark() string {
	return SActive.Render("▶ ")
}

// MarkedBullet returns the ◉ multi-select marker in orange.
func MarkedBullet() string {
	return SMarked.Render("◉ ")
}

// ── List factory ──────────────────────────────────────────────────────────────

// NewList creates a pre-styled bubbles/list with TokyoNight styles applied.
// Call l.Styles.TitleBar = lipgloss.NewStyle() if you use SolidTitle.
func NewList(items []list.Item, delegate list.ItemDelegate, width, height int) list.Model {
	l := list.New(items, delegate, width, height)
	l.Styles.Title = STitle
	l.Styles.FilterPrompt = lipgloss.NewStyle().Foreground(Highlight)
	l.Styles.FilterCursor = lipgloss.NewStyle().Foreground(Highlight)
	l.Styles.NoItems = SDim.Padding(1, 2)
	return l
}

// NewSolidTitleList is like NewList but with the solid highlight title bar.
// Zeroes out TitleBar padding automatically.
func NewSolidTitleList(title string, items []list.Item, delegate list.ItemDelegate, width, height int) list.Model {
	l := NewList(items, delegate, width, height)
	l.Title = title
	l.Styles.TitleBar = lipgloss.NewStyle()
	l.Styles.Title = SolidTitle(width)
	return l
}

// ── Search input factory ──────────────────────────────────────────────────────

// NewSearchInput returns a pre-styled text input for fzf-style search bars.
func NewSearchInput(placeholder string) textinput.Model {
	ti := textinput.New()
	ti.Placeholder = placeholder
	ti.PlaceholderStyle = SDim
	ti.TextStyle = SBright
	ti.Cursor.Style = lipgloss.NewStyle().Foreground(TmuxPink)
	ti.Focus()
	return ti
}

// SearchPrompt renders the search input with the ❯ prefix.
func SearchPrompt(ti textinput.Model) string {
	return lipgloss.NewStyle().Foreground(TmuxPink).Bold(true).Render("  ❯ ") + ti.View()
}
