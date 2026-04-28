package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"os/exec"
	"sort"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/bubbles/list"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

const queueFile = "/tmp/claude-notifications.queue"

var (
	tmuxBin   = "/opt/homebrew/bin/tmux"
	homeDir   = os.Getenv("HOME")
	deleteScr = homeDir + "/.claude/scripts/claude-delete.sh"
	switchScr = homeDir + "/.claude/scripts/claude-switch.sh"
)

// ── Data ──────────────────────────────────────────────────────────────────────

type Notification struct {
	ts         string
	target     string
	client     string
	project    string
	session    string
	windowName string
	paneIndex  string
	paneTitle  string
	done       bool // pane title starts with ✓
	timeAgo    string
}

func (n Notification) FilterValue() string {
	return n.session + " " + n.windowName + " " + n.paneTitle + " " + n.project + " " + n.target
}
func (n Notification) Title() string       { return n.paneTitle }
func (n Notification) Description() string { return n.session }

func loadNotifications() []Notification {
	f, err := os.Open(queueFile)
	if err != nil {
		return nil
	}
	defer f.Close()

	var out []Notification
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		parts := strings.Split(scanner.Text(), "\t")
		if len(parts) < 8 {
			continue
		}
		ts, target, client, project, session, window, paneIdx, visited :=
			parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6], parts[7]
		if visited != "0" || target == "" {
			continue
		}
		if _, err := strconv.ParseInt(ts, 10, 64); err != nil {
			continue
		}

		paneTitle := ""
		if b, err := exec.Command(tmuxBin, "display-message", "-t", target, "-p", "#{pane_title}").Output(); err == nil {
			paneTitle = strings.TrimSpace(string(b))
			for _, pfx := range []string{"✓ ", "✳ "} {
				paneTitle = strings.TrimPrefix(paneTitle, pfx)
			}
		}

		done := false
		if b, err := exec.Command(tmuxBin, "display-message", "-t", target, "-p", "#{pane_title}").Output(); err == nil {
			done = strings.HasPrefix(strings.TrimSpace(string(b)), "✓")
		}

		out = append(out, Notification{
			ts:         ts,
			target:     target,
			client:     client,
			project:    project,
			session:    session,
			windowName: window,
			paneIndex:  paneIdx,
			paneTitle:  paneTitle,
			done:       done,
			timeAgo:    ago(ts),
		})
	}

	sort.Slice(out, func(i, j int) bool { return out[i].ts > out[j].ts })
	return out
}

func ago(ts string) string {
	t, _ := strconv.ParseInt(ts, 10, 64)
	mins := int(time.Now().Unix()-t) / 60
	switch {
	case mins < 1:
		return "just now"
	case mins < 60:
		return fmt.Sprintf("%dm ago", mins)
	default:
		return fmt.Sprintf("%dh ago", mins/60)
	}
}

// ── Display helpers ───────────────────────────────────────────────────────────

func dw(s string) int { return utf8.RuneCountInString(s) }

func trunc(s string, max int) string {
	r := []rune(s)
	if len(r) <= max {
		return s
	}
	if max <= 1 {
		return "…"
	}
	return string(r[:max-1]) + "…"
}

func padTo(s string, width int) string {
	s = trunc(s, width)
	return s + strings.Repeat(" ", width-dw(s))
}

// ── Delegate ──────────────────────────────────────────────────────────────────

type colWidths struct{ loc, title, timeW, proj int }

type itemDelegate struct {
	cols   colWidths
	marked map[string]bool
}

func newDelegate(cols colWidths, marked map[string]bool) itemDelegate {
	return itemDelegate{cols: cols, marked: marked}
}

func (d itemDelegate) Height() int                              { return 1 }
func (d itemDelegate) Spacing() int                             { return 0 }
func (d itemDelegate) Update(_ tea.Msg, _ *list.Model) tea.Cmd { return nil }

var (
	sNormal   = lipgloss.NewStyle().Foreground(lipgloss.Color("245"))
	sSelected = lipgloss.NewStyle().Foreground(lipgloss.Color("212")).Bold(true)
	sMarked   = lipgloss.NewStyle().Foreground(lipgloss.Color("214"))
	sSelMark  = lipgloss.NewStyle().Foreground(lipgloss.Color("214")).Bold(true)
	sDone     = lipgloss.NewStyle().Foreground(lipgloss.Color("240"))
	sActive   = lipgloss.NewStyle().Foreground(lipgloss.Color("86"))
)

func (d itemDelegate) Render(w io.Writer, m list.Model, index int, item list.Item) {
	n, ok := item.(Notification)
	if !ok {
		return
	}
	sel := index == m.Index()
	mrk := d.marked[n.target]

	prefix := "  "
	if mrk {
		prefix = "◉ "
	}

	indicator := "⠿ "
	if n.done {
		indicator = "✓ "
	}

	loc := padTo(n.session+" → "+n.windowName+" ("+n.paneIndex+")", d.cols.loc)
	tsk := padTo(n.paneTitle, d.cols.title)
	tim := padTo(n.timeAgo, d.cols.timeW)
	prj := trunc(n.project, d.cols.proj)

	line := prefix + indicator + loc + "  " + tsk + "  " + tim + "  " + prj

	switch {
	case sel && mrk:
		fmt.Fprint(w, sSelMark.Render(line))
	case sel && !n.done:
		fmt.Fprint(w, sSelected.Render(line))
	case sel:
		fmt.Fprint(w, sSelected.Render(line))
	case mrk:
		fmt.Fprint(w, sMarked.Render(line))
	case n.done:
		fmt.Fprint(w, sDone.Render(line))
	default:
		fmt.Fprint(w, sActive.Render(line))
	}
}

// ── Model ─────────────────────────────────────────────────────────────────────

type previewMsg string

func fetchPreview(target string) tea.Cmd {
	return func() tea.Msg {
		b, err := exec.Command(tmuxBin, "capture-pane", "-p", "-t", target, "-S", "-15").Output()
		if err != nil {
			return previewMsg("")
		}
		return previewMsg(string(b))
	}
}

type model struct {
	list     list.Model
	marked   map[string]bool
	cols     colWidths
	width    int
	height   int
	preview  string
	switchTo *Notification
	quitting bool
}

var (
	sFooter  = lipgloss.NewStyle().Foreground(lipgloss.Color("241"))
	sPreview = lipgloss.NewStyle().Foreground(lipgloss.Color("240")).Padding(0, 1)
	sBorder  = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("240"))
)

func computeCols(width int) colWidths {
	// prefix(2) + indicator(2) + loc + "  " + title + "  " + time(9) + "  " + proj(18)
	// overhead = 2+2+2+2+2 = 10 fixed, + 9 + 18 = 37 total non-loc/title
	loc := 30
	proj := 18
	timeW := 9
	overhead := 2 + 2 + loc + 2 + 2 + timeW + 2 + proj
	title := width - overhead
	if title < 12 {
		title = 12
	}
	if title > 55 {
		title = 55
	}
	return colWidths{loc: loc, title: title, timeW: timeW, proj: proj}
}

func newModel(notifications []Notification, width, height int) model {
	cols := computeCols(width)
	marked := make(map[string]bool)
	d := newDelegate(cols, marked)

	items := make([]list.Item, len(notifications))
	for i, n := range notifications {
		items[i] = n
	}

	l := list.New(items, d, width, height-5)
	l.Title = "Claude Notifications"
	l.SetShowStatusBar(true)
	l.SetFilteringEnabled(true)
	l.Styles.Title = lipgloss.NewStyle().Foreground(lipgloss.Color("212")).Bold(true).Padding(0, 1)
	l.AdditionalShortHelpKeys = func() []key.Binding {
		return []key.Binding{
			key.NewBinding(key.WithKeys("tab"), key.WithHelp("tab", "mark")),
			key.NewBinding(key.WithKeys("ctrl+d"), key.WithHelp("ctrl+d", "dismiss")),
		}
	}

	return model{list: l, marked: marked, cols: cols, width: width, height: height}
}

func (m model) Init() tea.Cmd {
	if item, ok := m.list.SelectedItem().(Notification); ok {
		return fetchPreview(item.target)
	}
	return nil
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {

	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.cols = computeCols(msg.Width)
		previewH := 6
		m.list.SetWidth(msg.Width)
		m.list.SetHeight(msg.Height - previewH - 3)
		m.list.SetDelegate(newDelegate(m.cols, m.marked))
		return m, nil

	case previewMsg:
		m.preview = string(msg)
		return m, nil

	case tea.KeyMsg:
		if m.list.FilterState() == list.Filtering {
			break
		}

		switch msg.String() {
		case "ctrl+c", "esc":
			m.quitting = true
			return m, tea.Quit

		case "q":
			if m.list.FilterState() != list.Filtering {
				m.quitting = true
				return m, tea.Quit
			}

		case "enter":
			if item, ok := m.list.SelectedItem().(Notification); ok {
				n := item
				m.switchTo = &n
				m.quitting = true
				return m, tea.Quit
			}

		case "tab":
			if item, ok := m.list.SelectedItem().(Notification); ok {
				if m.marked[item.target] {
					delete(m.marked, item.target)
				} else {
					m.marked[item.target] = true
				}
				m.list.SetDelegate(newDelegate(m.cols, m.marked))
				m.list.CursorDown()
			}
			return m, nil

		case "ctrl+d":
			targets := []string{}
			if len(m.marked) > 0 {
				for t := range m.marked {
					targets = append(targets, t)
				}
			} else if item, ok := m.list.SelectedItem().(Notification); ok {
				targets = append(targets, item.target)
			}
			for _, t := range targets {
				exec.Command(deleteScr, t).Run()
				delete(m.marked, t)
			}
			// Reload
			notifications := loadNotifications()
			items := make([]list.Item, len(notifications))
			for i, n := range notifications {
				items[i] = n
			}
			m.list.SetItems(items)
			m.list.SetDelegate(newDelegate(m.cols, m.marked))
			if len(notifications) == 0 {
				m.quitting = true
				return m, tea.Quit
			}
			return m, nil
		}
	}

	prevIdx := m.list.Index()
	var cmd tea.Cmd
	m.list, cmd = m.list.Update(msg)
	if m.list.Index() != prevIdx {
		if item, ok := m.list.SelectedItem().(Notification); ok {
			return m, tea.Batch(cmd, fetchPreview(item.target))
		}
	}
	return m, cmd
}

func (m model) View() string {
	if m.quitting {
		return ""
	}

	// Preview panel
	previewLines := strings.Split(m.preview, "\n")
	// take last 5 non-empty lines
	var filtered []string
	for _, l := range previewLines {
		if strings.TrimSpace(l) != "" {
			filtered = append(filtered, l)
		}
	}
	if len(filtered) > 5 {
		filtered = filtered[len(filtered)-5:]
	}
	previewContent := strings.Join(filtered, "\n")
	preview := sBorder.Width(m.width - 2).Render(sPreview.Render(previewContent))

	footer := sFooter.Render(" enter: switch  ·  tab: mark  ·  ctrl+d: dismiss  ·  /: filter  ·  q: quit")

	return m.list.View() + "\n" + preview + "\n" + footer
}

// ── Main ──────────────────────────────────────────────────────────────────────

func main() {
	notifications := loadNotifications()
	if len(notifications) == 0 {
		fmt.Fprintln(os.Stderr, "no pending notifications")
		os.Exit(0)
	}

	width := 120
	if w := os.Getenv("TMUX_CLIENT_WIDTH"); w != "" {
		if n, err := strconv.Atoi(w); err == nil {
			width = n * 70 / 100
		}
	}

	p := tea.NewProgram(
		newModel(notifications, width, 30),
		tea.WithAltScreen(),
	)

	result, err := p.Run()
	if err != nil {
		os.Exit(1)
	}

	if fm, ok := result.(model); ok && fm.switchTo != nil {
		exec.Command(switchScr, fm.switchTo.target, fm.switchTo.client).Run()
	}
}
