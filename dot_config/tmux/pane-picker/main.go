package main

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"strconv"
	"strings"

	"github.com/charmbracelet/bubbles/list"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	ui "trenthaines.dev/tui"
)

var tmuxBin = "/opt/homebrew/bin/tmux"

// ── Data ──────────────────────────────────────────────────────────────────────

type Pane struct {
	id      string // %42
	session string
	window  string // index
	winName string
	pane    string // index
	command string
	title   string
	path    string
	active  bool
}

func (p Pane) FilterValue() string {
	return p.session + " " + p.winName + " " + p.command + " " + p.title + " " + p.shortPath()
}
func (p Pane) Title() string       { return p.title }
func (p Pane) Description() string { return p.session }

func (p Pane) target() string { return p.session + ":" + p.window + "." + p.pane }

func (p Pane) shortPath() string {
	home := os.Getenv("HOME")
	s := strings.TrimPrefix(p.path, home)
	if s != p.path {
		s = "~" + s
	}
	// Shorten to last 2 path components
	parts := strings.Split(strings.Trim(s, "/"), "/")
	if len(parts) > 2 {
		parts = parts[len(parts)-2:]
		s = "…/" + strings.Join(parts, "/")
	}
	return s
}

func loadPanes() []Pane {
	format := strings.Join([]string{
		"#{pane_id}",
		"#{pane_active}",
		"#{session_name}",
		"#{window_index}",
		"#{window_name}",
		"#{pane_index}",
		"#{pane_current_command}",
		"#{pane_title}",
		"#{pane_current_path}",
	}, "\t")

	b, err := exec.Command(tmuxBin, "list-panes", "-a", "-F", format).Output()
	if err != nil {
		return nil
	}

	var panes []Pane
	for _, line := range strings.Split(strings.TrimSpace(string(b)), "\n") {
		parts := strings.Split(line, "\t")
		if len(parts) < 9 {
			continue
		}
		title := parts[7]
		for _, pfx := range []string{"✓ ", "✳ "} {
			title = strings.TrimPrefix(title, pfx)
		}
		panes = append(panes, Pane{
			id:      parts[0],
			active:  parts[1] == "1",
			session: parts[2],
			window:  parts[3],
			winName: parts[4],
			pane:    parts[5],
			command: parts[6],
			title:   title,
			path:    parts[8],
		})
	}
	return panes
}

// ── Columns ───────────────────────────────────────────────────────────────────

type cols struct{ loc, cmd, detail int }

func makeCols(width int) cols {
	w := width - 4
	loc := 28
	cmd := 14
	detail := w - 2 - 2 - loc - 2 - 2 - cmd - 2
	if detail < 10 {
		detail = 10
	}
	return cols{loc: loc, cmd: cmd, detail: detail}
}

// ── Delegate ──────────────────────────────────────────────────────────────────

type itemDelegate struct{ c cols }

func (d itemDelegate) Height() int                              { return 1 }
func (d itemDelegate) Spacing() int                             { return 0 }
func (d itemDelegate) Update(_ tea.Msg, _ *list.Model) tea.Cmd { return nil }

var sCmdMap = map[string]lipgloss.Style{
	"nvim":   lipgloss.NewStyle().Foreground(ui.Green),
	"claude": lipgloss.NewStyle().Foreground(ui.Cyan),
	"node":   lipgloss.NewStyle().Foreground(ui.Yellow),
	"python": lipgloss.NewStyle().Foreground(ui.Blue),
	"python3": lipgloss.NewStyle().Foreground(ui.Blue),
	"go":     lipgloss.NewStyle().Foreground(ui.Teal),
	"fish":   lipgloss.NewStyle().Foreground(ui.FGDim),
	"bash":   lipgloss.NewStyle().Foreground(ui.FGDim),
	"zsh":    lipgloss.NewStyle().Foreground(ui.FGDim),
	"ssh":    lipgloss.NewStyle().Foreground(ui.Orange),
}

func cmdStyle(cmd string) lipgloss.Style {
	if s, ok := sCmdMap[cmd]; ok {
		return s
	}
	return ui.SNormal
}

func (d itemDelegate) Render(w io.Writer, m list.Model, index int, item list.Item) {
	p, ok := item.(Pane)
	if !ok {
		return
	}
	sel := index == m.Index()

	marker := "  "
	if p.active {
		marker = ui.SActive.Render("▶ ")
	}

	loc := p.session + " → " + p.winName + " (" + p.pane + ")"
	detail := p.title
	if detail == "" || detail == p.command {
		detail = p.shortPath()
	}

	if sel {
		line := marker +
			ui.Pad(loc, d.c.loc) + "  " +
			ui.Pad(p.command, d.c.cmd) + "  " +
			ui.Trunc(detail, d.c.detail)
		fmt.Fprint(w, ui.SSelected.Render(line))
	} else {
		fmt.Fprint(w,
			marker+
				ui.SNormal.Render(ui.Pad(loc, d.c.loc))+"  "+
				cmdStyle(p.command).Render(ui.Pad(p.command, d.c.cmd))+"  "+
				ui.SDim.Render(ui.Trunc(detail, d.c.detail)),
		)
	}
}

// ── Model ─────────────────────────────────────────────────────────────────────

type previewMsg string

func fetchPreview(id string) tea.Cmd {
	return func() tea.Msg {
		b, err := exec.Command(tmuxBin, "capture-pane", "-p", "-e", "-t", id, "-S", "-25").Output()
		if err != nil {
			return previewMsg("")
		}
		return previewMsg(string(b))
	}
}

type model struct {
	list     list.Model
	c        cols
	width    int
	height   int
	preview  string
	switchTo string // pane id
	quitting bool
}

func newModel(panes []Pane, width, height int) model {
	c := makeCols(width)
	items := make([]list.Item, len(panes))
	for i, p := range panes {
		items[i] = p
	}

	previewH := 12
	listH := height - previewH - 3
	if listH < 5 {
		listH = 5
	}

	l := list.New(items, itemDelegate{c: c}, width, listH)
	l.Title = "All Panes"
	l.SetShowStatusBar(true)
	l.SetFilteringEnabled(true)
	l.SetStatusBarItemName("pane", "panes")
	l.Styles.Title = ui.STitle
	l.Styles.FilterPrompt = lipgloss.NewStyle().Foreground(ui.Yellow)
	l.Styles.FilterCursor = lipgloss.NewStyle().Foreground(ui.Yellow)
	l.Styles.NoItems = ui.SDim.Padding(1, 2)

	l.SetFilterState(list.Filtering)
	return model{list: l, c: c, width: width, height: height}
}

func (m model) Init() tea.Cmd {
	if p, ok := m.list.SelectedItem().(Pane); ok {
		return fetchPreview(p.id)
	}
	return nil
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.c = makeCols(msg.Width)
		previewH := 12
		listH := msg.Height - previewH - 3
		if listH < 5 {
			listH = 5
		}
		m.list.SetWidth(msg.Width)
		m.list.SetHeight(listH)
		m.list.SetDelegate(itemDelegate{c: m.c})
		return m, nil

	case previewMsg:
		m.preview = string(msg)
		return m, nil

	case tea.KeyMsg:
		if m.list.FilterState() == list.Filtering {
			break
		}
		switch msg.String() {
		case "ctrl+c", "q":
			m.quitting = true
			return m, tea.Quit
		case "enter":
			if p, ok := m.list.SelectedItem().(Pane); ok {
				m.switchTo = p.id
				m.quitting = true
				return m, tea.Quit
			}
		}
	}

	prevIdx := m.list.Index()
	var cmd tea.Cmd
	m.list, cmd = m.list.Update(msg)
	if m.list.Index() != prevIdx {
		if p, ok := m.list.SelectedItem().(Pane); ok {
			return m, tea.Batch(cmd, fetchPreview(p.id))
		}
	}
	return m, cmd
}

func (m model) View() string {
	if m.quitting {
		return ""
	}

	lines := strings.Split(m.preview, "\n")
	var kept []string
	for _, l := range lines {
		if strings.TrimSpace(l) != "" {
			kept = append(kept, l)
		}
	}
	if len(kept) > 10 {
		kept = kept[len(kept)-10:]
	}
	preview := ui.SBorder.Width(m.width - 4).Render(
		ui.SPreview.Render(strings.Join(kept, "\n")),
	)
	footer := ui.SFooter.Render("  enter:switch  esc:clear filter  q:quit")
	return m.list.View() + "\n" + preview + "\n" + footer
}

// ── Main ──────────────────────────────────────────────────────────────────────

func main() {
	panes := loadPanes()

	width, height := 120, 40
	if w := os.Getenv("TMUX_CLIENT_WIDTH"); w != "" {
		if n, err := strconv.Atoi(w); err == nil {
			width = n * 95 / 100
		}
	}
	if h := os.Getenv("TMUX_CLIENT_HEIGHT"); h != "" {
		if n, err := strconv.Atoi(h); err == nil {
			height = n * 60 / 100
		}
	}

	p := tea.NewProgram(newModel(panes, width, height), tea.WithAltScreen())
	result, err := p.Run()
	if err != nil {
		os.Exit(1)
	}

	if fm, ok := result.(model); ok && fm.switchTo != "" && len(os.Args) > 1 {
		os.WriteFile(os.Args[1], []byte(fm.switchTo+"\n"), 0600)
	}
}
