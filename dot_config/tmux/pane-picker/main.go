package main

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"strconv"
	"strings"

	"github.com/charmbracelet/bubbles/list"
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	ui "trenthaines.dev/tui"
)

var tmuxBin = "/opt/homebrew/bin/tmux"

// ── Data ──────────────────────────────────────────────────────────────────────

type Pane struct {
	id      string
	session string
	window  string
	winName string
	pane    string
	command string
	title   string
	path    string
	active  bool
}

func (p Pane) FilterValue() string { return "" } // unused — we filter manually
func (p Pane) Title() string       { return p.title }
func (p Pane) Description() string { return p.session }

func (p Pane) shortPath() string {
	home := os.Getenv("HOME")
	s := strings.TrimPrefix(p.path, home)
	if s != p.path {
		s = "~" + s
	}
	parts := strings.Split(strings.Trim(s, "/"), "/")
	if len(parts) > 2 {
		s = "…/" + strings.Join(parts[len(parts)-2:], "/")
	}
	return s
}

func (p Pane) searchText() string {
	return strings.ToLower(p.session + " " + p.winName + " " + p.command + " " + p.title + " " + p.shortPath())
}

func loadPanes() []Pane {
	format := strings.Join([]string{
		"#{pane_id}", "#{pane_active}", "#{session_name}",
		"#{window_index}", "#{window_name}", "#{pane_index}",
		"#{pane_current_command}", "#{pane_title}", "#{pane_current_path}",
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
			id: parts[0], active: parts[1] == "1",
			session: parts[2], window: parts[3], winName: parts[4],
			pane: parts[5], command: parts[6], title: title, path: parts[8],
		})
	}
	return panes
}

func filterPanes(panes []Pane, query string) []Pane {
	if query == "" {
		return panes
	}
	q := strings.ToLower(query)
	var out []Pane
	for _, p := range panes {
		if strings.Contains(p.searchText(), q) {
			out = append(out, p)
		}
	}
	return out
}

// ── Columns ───────────────────────────────────────────────────────────────────

type cols struct{ loc, cmd, detail int }

func makeCols(width int) cols {
	w := width - 4
	loc, cmd := 28, 14
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

var cmdColors = map[string]lipgloss.Color{
	"nvim": ui.Green, "vim": ui.Green,
	"claude": ui.Cyan,
	"node":   ui.Yellow,
	"python": ui.Blue, "python3": ui.Blue,
	"go":  ui.Teal,
	"ssh": ui.Orange,
}

func (d itemDelegate) Render(w io.Writer, m list.Model, index int, item list.Item) {
	p, ok := item.(Pane)
	if !ok {
		return
	}
	sel := index == m.Index()

	marker := "  "
	if sel {
		marker = ui.Caret()
	} else if p.active {
		marker = ui.ActiveMark()
	}

	loc := p.session + " → " + p.winName + " (" + p.pane + ")"
	detail := p.title
	if detail == "" || detail == p.command {
		detail = p.shortPath()
	}

	if sel {
		line := marker + ui.Pad(loc, d.c.loc) + "  " + ui.Pad(p.command, d.c.cmd) + "  " + ui.Trunc(detail, d.c.detail)
		fmt.Fprint(w, ui.SSelected.Render(line))
	} else {
		cmdSty := ui.SNormal
		if c, ok := cmdColors[p.command]; ok {
			cmdSty = lipgloss.NewStyle().Foreground(c)
		}
		fmt.Fprint(w,
			marker+
				ui.SNormal.Render(ui.Pad(loc, d.c.loc))+"  "+
				cmdSty.Render(ui.Pad(p.command, d.c.cmd))+"  "+
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
	input    textinput.Model
	list     list.Model
	allPanes []Pane
	c        cols
	width    int
	height   int
	preview  string
	switchTo string
	quitting bool
}


func newModel(panes []Pane, width, height int) model {
	c := makeCols(width)

	// Text input for search
	ti := ui.NewSearchInput("search panes…")

	// List (no built-in filtering — we handle it)
	items := panesToItems(panes)
	previewH := 12
	listH := height - previewH - 4 // -4: title + input + footer + border
	if listH < 5 {
		listH = 5
	}

	l := list.New(items, itemDelegate{c: c}, width, listH)
	l.SetShowTitle(false)
	l.SetShowStatusBar(false)
	l.SetFilteringEnabled(false)
	l.SetShowHelp(false)
	l.Styles.NoItems = ui.SDim.Padding(1, 2)

	return model{input: ti, list: l, allPanes: panes, c: c, width: width, height: height}
}

func panesToItems(panes []Pane) []list.Item {
	items := make([]list.Item, len(panes))
	for i, p := range panes {
		items[i] = p
	}
	return items
}

func (m model) Init() tea.Cmd {
	if p, ok := m.list.SelectedItem().(Pane); ok {
		return tea.Batch(textinput.Blink, fetchPreview(p.id))
	}
	return textinput.Blink
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.c = makeCols(msg.Width)
		previewH := 12
		listH := msg.Height - previewH - 4
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
		switch msg.String() {
		case "ctrl+c":
			m.quitting = true
			return m, tea.Quit
		case "esc":
			if m.input.Value() != "" {
				m.input.SetValue("")
				filtered := filterPanes(m.allPanes, "")
				m.list.SetItems(panesToItems(filtered))
				return m, nil
			}
			m.quitting = true
			return m, tea.Quit
		case "enter":
			if p, ok := m.list.SelectedItem().(Pane); ok {
				m.switchTo = p.id
				m.quitting = true
				return m, tea.Quit
			}
		case "up", "down":
			prevIdx := m.list.Index()
			var cmd tea.Cmd
			m.list, cmd = m.list.Update(msg)
			if m.list.Index() != prevIdx {
				if p, ok := m.list.SelectedItem().(Pane); ok {
					return m, tea.Batch(cmd, fetchPreview(p.id))
				}
			}
			return m, cmd
		default:
			// All other keys go to the text input
			var cmd tea.Cmd
			m.input, cmd = m.input.Update(msg)
			filtered := filterPanes(m.allPanes, m.input.Value())
			m.list.SetItems(panesToItems(filtered))
			if p, ok := m.list.SelectedItem().(Pane); ok {
				return m, tea.Batch(cmd, fetchPreview(p.id))
			}
			return m, cmd
		}
	}

	return m, nil
}

func (m model) View() string {
	if m.quitting {
		return ""
	}

	title := ui.SolidTitle(m.width).Render("All Panes")

	prompt := ui.SearchPrompt(m.input)

	preview := ui.PreviewBox(m.preview, m.width, 10)
	footer := ui.Footer("enter:switch", "esc:clear/quit", "↑↓:navigate")

	return title + "\n" + prompt + "\n" + m.list.View() + "\n" + preview + "\n" + footer
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
