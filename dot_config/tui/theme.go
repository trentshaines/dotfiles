// Package tui provides shared TokyoNight styles and layout helpers for TUI tools.
package tui

import (
	"strings"
	"unicode/utf8"

	"github.com/charmbracelet/lipgloss"
)

// ── TokyoNight Night palette ──────────────────────────────────────────────────

var (
	// Backgrounds
	BG   = lipgloss.Color("#1a1b26")
	BGHL = lipgloss.Color("#292e42") // highlight / selection bg
	BG2  = lipgloss.Color("#24283b") // slightly lighter bg

	// Foregrounds
	FG     = lipgloss.Color("#a9b1d6") // normal text
	FGDim  = lipgloss.Color("#787c99") // dimmer text
	FGBold = lipgloss.Color("#c0caf5") // brighter text

	// Syntax colors
	Red    = lipgloss.Color("#f7768e")
	Orange = lipgloss.Color("#ff9e64")
	Yellow = lipgloss.Color("#e0af68")
	Green  = lipgloss.Color("#9ece6a")
	Teal   = lipgloss.Color("#73daca")
	Cyan   = lipgloss.Color("#7dcfff")
	Blue   = lipgloss.Color("#7aa2f7")
	Purple = lipgloss.Color("#9d7cd8")
	Violet = lipgloss.Color("#bb9af7")

	// UI colors
	Comment   = lipgloss.Color("#565f89") // muted / done
	Border    = lipgloss.Color("#3b3d57") // internal borders (subtle)
	Inactive  = lipgloss.Color("#414868") // inactive elements
	Highlight = lipgloss.Color("#fff2cc") // matches tmux status bar highlight
	TmuxPink  = lipgloss.Color("#ff10f0") // tmux prefix-pressed magenta
)

// ── Semantic aliases ──────────────────────────────────────────────────────────

var (
	ColorActive   = Teal   // something in progress
	ColorDone     = Comment // completed / muted
	ColorSelected = Yellow  // cursor selection
	ColorMarked   = Orange  // multi-select / warn
	ColorDanger   = Red     // destructive action
	ColorInfo     = Blue    // metadata / time
	ColorSubtle   = Violet  // secondary info / project
)

// ── Base styles ───────────────────────────────────────────────────────────────

var (
	SNormal   = lipgloss.NewStyle().Foreground(FG)
	SBright   = lipgloss.NewStyle().Foreground(FGBold)
	SDim      = lipgloss.NewStyle().Foreground(Comment)
	SSelected = lipgloss.NewStyle().Foreground(Yellow).Bold(true)
	SMarked   = lipgloss.NewStyle().Foreground(Orange)
	SSelMark  = lipgloss.NewStyle().Foreground(Red).Bold(true)
	SActive   = lipgloss.NewStyle().Foreground(Teal)
	SDone     = lipgloss.NewStyle().Foreground(Comment)
	SInfo     = lipgloss.NewStyle().Foreground(Blue)
	SSubtle   = lipgloss.NewStyle().Foreground(Violet)
	STitle    = lipgloss.NewStyle().Foreground(Yellow).Bold(true)
	SFooter   = lipgloss.NewStyle().Foreground(Inactive)
	SBorder   = lipgloss.NewStyle().Border(lipgloss.NormalBorder()).BorderForeground(lipgloss.Color("#ffffff"))
	SPreview  = lipgloss.NewStyle().Foreground(FGDim).PaddingLeft(1)
)

// ── Component helpers ─────────────────────────────────────────────────────────

// SolidTitle returns a full-width title bar style matching the tmux highlight colour.
// Pass the popup/terminal width so it stretches edge-to-edge.
// Also zero out bubbles/list's default TitleBar padding:
//
//	l.Styles.TitleBar = lipgloss.NewStyle()
//	l.Styles.Title    = tui.SolidTitle(width)
func SolidTitle(width int) lipgloss.Style {
	return lipgloss.NewStyle().
		Background(Highlight).
		Foreground(BG).
		Bold(true).
		Padding(0, 1).
		Width(width)
}

// ── Layout helpers ────────────────────────────────────────────────────────────

// DW returns the display width of a string (rune count; adequate for non-CJK).
func DW(s string) int {
	return utf8.RuneCountInString(s)
}

// Trunc truncates s to max display width, appending … if cut.
func Trunc(s string, max int) string {
	r := []rune(s)
	if len(r) <= max {
		return s
	}
	if max <= 1 {
		return "…"
	}
	return string(r[:max-1]) + "…"
}

// Pad truncates then space-pads s to exactly width display columns.
func Pad(s string, width int) string {
	s = Trunc(s, width)
	return s + strings.Repeat(" ", width-DW(s))
}
