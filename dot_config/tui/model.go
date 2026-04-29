package tui

import tea "github.com/charmbracelet/bubbletea"

// ── Base model ────────────────────────────────────────────────────────────────

// Base holds common state every TUI tool needs.
// Embed it in your model struct to get width/height tracking and quit handling.
//
//	type model struct {
//	    tui.Base
//	    list list.Model
//	    // ...
//	}
type Base struct {
	Width    int
	Height   int
	Quitting bool
}

// Quit marks the model as quitting and returns a tea.Quit command.
func (b *Base) Quit() tea.Cmd {
	b.Quitting = true
	return tea.Quit
}

// Resize updates Width and Height from a WindowSizeMsg.
func (b *Base) Resize(msg tea.WindowSizeMsg) {
	b.Width = msg.Width
	b.Height = msg.Height
}

// IsQuit returns true for ctrl+c, esc, and q key messages.
func IsQuit(msg tea.KeyMsg) bool {
	switch msg.String() {
	case "ctrl+c", "esc", "q":
		return true
	}
	return false
}

// ── Async helpers ─────────────────────────────────────────────────────────────

// PanePreviewCmd captures the last n lines of a tmux pane asynchronously.
// The result is delivered as a string message — handle it in Update:
//
//	case string:
//	    m.preview = msg
func PanePreviewCmd(paneID string, lines int) tea.Cmd {
	return panePreviewCmd(paneID, lines)
}
