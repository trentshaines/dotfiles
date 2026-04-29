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

	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/bubbles/list"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	ui "trenthaines.dev/tui"
)

const queueFile = "/tmp/claude-notifications.queue"

var (
	tmuxBin   = "/opt/homebrew/bin/tmux"
	homeDir   = os.Getenv("HOME")
	deleteScr = homeDir + "/.claude/scripts/claude-delete.sh"
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
	done       bool
	timeAgo    string
}

func (n Notification) FilterValue() string {
	return n.session + " " + n.windowName + " " + n.paneTitle + " " + n.project
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

		raw := ""
		if b, err := exec.Command(tmuxBin, "display-message", "-t", target, "-p", "#{pane_title}").Output(); err == nil {
			raw = strings.TrimSpace(string(b))
		} else {
			continue // skip stale targets
		}
		done := strings.HasPrefix(raw, "✓")
		paneTitle := raw
		for _, pfx := range []string{"✓ ", "✳ "} {
			paneTitle = strings.TrimPrefix(paneTitle, pfx)
		}
		if paneTitle == "" {
			paneTitle = window
		}

		out = append(out, Notification{
			ts: ts, target: target, client: client,
			project: project, session: session, windowName: window,
			paneIndex: paneIdx, paneTitle: paneTitle, done: done,
			timeAgo: ago(ts),
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

// ── Columns ───────────────────────────────────────────────────────────────────

type cols struct{ loc, task, timeW, proj int }

func makeCols(width int) cols {
	// line layout: "  "(2) + status(2) + loc + "  " + task + "  " + time + "  " + proj
	w := width - 4 // safety margin for list internal offset
	timeW, proj, loc := 9, 20, 30
	task := w - 2 - 2 - loc - 2 - 2 - timeW - 2 - proj
	if task < 12 {
		task = 12
	}
	return cols{loc: loc, task: task, timeW: timeW, proj: proj}
}

// ── Delegate ──────────────────────────────────────────────────────────────────

type itemDelegate struct {
	c      cols
	marked map[string]bool
}

func (d itemDelegate) Height() int                              { return 1 }
func (d itemDelegate) Spacing() int                             { return 0 }
func (d itemDelegate) Update(_ tea.Msg, _ *list.Model) tea.Cmd { return nil }

func (d itemDelegate) Render(w io.Writer, m list.Model, index int, item list.Item) {
	n, ok := item.(Notification)
	if !ok {
		return
	}
	sel := index == m.Index()
	mrk := d.marked[n.target]

	marker := "  "
	if mrk {
		marker = ui.SMarked.Render("◉ ")
	}
	status := ui.SActive.Render("⠿ ")
	if n.done {
		status = ui.SDim.Render("✓ ")
	}

	locStr := n.session + " → " + n.windowName
	taskStr := "[" + n.paneIndex + "] " + n.paneTitle

	if sel {
		// Whole-line highlight
		line := marker + status +
			ui.Pad(locStr, d.c.loc) + "  " +
			ui.Pad(taskStr, d.c.task) + "  " +
			ui.Pad(n.timeAgo, d.c.timeW) + "  " +
			ui.Trunc(n.project, d.c.proj)
		if mrk {
			fmt.Fprint(w, ui.SSelMark.Render(line))
		} else {
			fmt.Fprint(w, ui.SSelected.Render(line))
		}
	} else {
		// Per-column colors
		taskSty := ui.SBright
		if n.done {
			taskSty = ui.SDone
		}
		fmt.Fprint(w,
			marker+status+
				ui.SNormal.Render(ui.Pad(locStr, d.c.loc))+"  "+
				taskSty.Render(ui.Pad(taskStr, d.c.task))+"  "+
				ui.SInfo.Render(ui.Pad(n.timeAgo, d.c.timeW))+"  "+
				ui.SSubtle.Render(ui.Trunc(n.project, d.c.proj)),
		)
	}
}

// ── Model ─────────────────────────────────────────────────────────────────────

type previewMsg string

func fetchPreview(target string) tea.Cmd {
	return func() tea.Msg {
		b, err := exec.Command(tmuxBin, "capture-pane", "-p", "-e", "-t", target, "-S", "-25").Output()
		if err != nil {
			return previewMsg("")
		}
		return previewMsg(string(b))
	}
}

type model struct {
	list     list.Model
	marked   map[string]bool
	c        cols
	width    int
	height   int
	preview  string
	switchTo *Notification
	quitting bool
}

func newModel(notifications []Notification, width, height int) model {
	c := makeCols(width)
	marked := make(map[string]bool)

	items := make([]list.Item, len(notifications))
	for i, n := range notifications {
		items[i] = n
	}

	previewH := 12
	listH := height - previewH - 3
	if listH < 5 {
		listH = 5
	}

	l := ui.NewSolidTitleList("Agent Notifications", items, itemDelegate{c: c, marked: marked}, width, listH)
	l.SetShowStatusBar(true)
	l.SetStatusBarItemName("notification", "pending notifications")
	l.SetFilteringEnabled(true)
	l.Styles.FilterPrompt = lipgloss.NewStyle().Foreground(ui.Yellow)
	l.Styles.FilterCursor = lipgloss.NewStyle().Foreground(ui.Yellow)
	l.Styles.NoItems = ui.SDim.Padding(1, 2)
	l.AdditionalShortHelpKeys = func() []key.Binding {
		return []key.Binding{
			key.NewBinding(key.WithKeys("tab"), key.WithHelp("tab", "mark")),
			key.NewBinding(key.WithKeys("ctrl+d"), key.WithHelp("ctrl+d", "dismiss")),
		}
	}

	return model{list: l, marked: marked, c: c, width: width, height: height}
}

func (m model) Init() tea.Cmd {
	if item, ok := m.list.SelectedItem().(Notification); ok {
		return fetchPreview(item.target)
	}
	return nil
}

func (m model) reload() model {
	notifications := loadNotifications()
	items := make([]list.Item, len(notifications))
	for i, n := range notifications {
		items[i] = n
	}
	m.list.SetItems(items)
	m.list.SetDelegate(itemDelegate{c: m.c, marked: m.marked})
	return m
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
		m.list.SetDelegate(itemDelegate{c: m.c, marked: m.marked})
		m.list.Styles.Title = ui.SolidTitle(msg.Width)
		return m, nil

	case previewMsg:
		m.preview = string(msg)
		return m, nil

	case tea.KeyMsg:
		if m.list.FilterState() == list.Filtering {
			break
		}
		switch msg.String() {
		case "ctrl+c", "esc", "q":
			m.quitting = true
			return m, tea.Quit

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
				m.list.SetDelegate(itemDelegate{c: m.c, marked: m.marked})
				m.list.CursorDown()
			}
			return m, nil

		case "ctrl+d":
			targets := []string{}
			if len(m.marked) > 0 {
				for tgt := range m.marked {
					targets = append(targets, tgt)
				}
			} else if item, ok := m.list.SelectedItem().(Notification); ok {
				targets = append(targets, item.target)
			}
			for _, tgt := range targets {
				exec.Command(deleteScr, tgt).Run()
				delete(m.marked, tgt)
			}
			m = m.reload()
			if item, ok := m.list.SelectedItem().(Notification); ok {
				return m, fetchPreview(item.target)
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

	preview := ui.PreviewBox(m.preview, m.width, 10)
	footer := ui.Footer("enter:switch", "tab:mark", "ctrl+d:dismiss", "/:filter", "q:quit")

	return m.list.View() + "\n" + preview + "\n" + footer
}

// ── Main ──────────────────────────────────────────────────────────────────────

func main() {
	notifications := loadNotifications()

	width, height := 120, 40
	if w := os.Getenv("TMUX_CLIENT_WIDTH"); w != "" {
		if n, err := strconv.Atoi(w); err == nil {
			width = n * 70 / 100
		}
	}
	if h := os.Getenv("TMUX_CLIENT_HEIGHT"); h != "" {
		if n, err := strconv.Atoi(h); err == nil {
			height = n * 50 / 100
		}
	}

	p := tea.NewProgram(newModel(notifications, width, height), tea.WithAltScreen())
	result, err := p.Run()
	if err != nil {
		os.Exit(1)
	}

	if fm, ok := result.(model); ok && fm.switchTo != nil && len(os.Args) > 1 {
		os.WriteFile(os.Args[1], []byte(fm.switchTo.target+"\t"+fm.switchTo.client+"\n"), 0600)
	}
}
