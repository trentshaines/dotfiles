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
	visited    bool
	timeAgo    string
}

func (n Notification) FilterValue() string {
	return n.session + " " + n.windowName + " " + n.paneTitle + " " + n.project
}
func (n Notification) Title() string       { return n.paneTitle }
func (n Notification) Description() string { return n.session }

// staleVisitedTTL is how long a visited-but-not-engaged row stays in the queue
// before the picker drops it from disk on the next launch.
const staleVisitedTTL = 7 * 24 * 60 * 60 // seconds

// sweepStale rewrites the queue file with rows where visited > 0 AND the visit
// is older than staleVisitedTTL filtered out. No-op if nothing to drop.
func sweepStale() {
	data, err := os.ReadFile(queueFile)
	if err != nil {
		return
	}
	cutoff := time.Now().Unix() - int64(staleVisitedTTL)
	lines := strings.Split(string(data), "\n")
	kept := make([]string, 0, len(lines))
	dropped := 0
	for _, line := range lines {
		if line == "" {
			continue
		}
		parts := strings.Split(line, "\t")
		if len(parts) >= 8 {
			if v, err := strconv.ParseInt(parts[7], 10, 64); err == nil && v > 0 && v < cutoff {
				dropped++
				continue
			}
		}
		kept = append(kept, line)
	}
	if dropped == 0 {
		return
	}
	out := strings.Join(kept, "\n")
	if len(kept) > 0 {
		out += "\n"
	}
	tmp := queueFile + ".tmp"
	if err := os.WriteFile(tmp, []byte(out), 0o644); err != nil {
		return
	}
	_ = os.Rename(tmp, queueFile)
}

func loadNotifications() []Notification {
	sweepStale()

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
		if target == "" {
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
			visited: visited != "0",
			timeAgo: ago(ts),
		})
	}
	// Unvisited (active) rows first, then by timestamp desc within each group.
	sort.SliceStable(out, func(i, j int) bool {
		if out[i].visited != out[j].visited {
			return !out[i].visited
		}
		return out[i].ts > out[j].ts
	})
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
	if n.visited {
		// Acknowledged but not yet engaged — keep visible but de-emphasize.
		if n.done {
			status = ui.SDim.Render("✓ ")
		} else {
			status = ui.SDim.Render("⠿ ")
		}
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
		locSty := ui.SNormal
		taskSty := ui.SBright
		timeSty := ui.SInfo
		projSty := ui.SSubtle
		if n.visited {
			locSty = ui.SDim
			taskSty = ui.SDim
			timeSty = ui.SDim
			projSty = ui.SDim
		} else if n.done {
			taskSty = ui.SDone
		}
		fmt.Fprint(w,
			marker+status+
				locSty.Render(ui.Pad(locStr, d.c.loc))+"  "+
				taskSty.Render(ui.Pad(taskStr, d.c.task))+"  "+
				timeSty.Render(ui.Pad(n.timeAgo, d.c.timeW))+"  "+
				projSty.Render(ui.Trunc(n.project, d.c.proj)),
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
	marked := make(map[string]bool)

	items := make([]list.Item, len(notifications))
	for i, n := range notifications {
		items[i] = n
	}

	listW := width * 58 / 100
	listH := height - 3 // title + footer + 1
	if listH < 5 {
		listH = 5
	}
	c := makeCols(listW)

	l := ui.NewList(items, itemDelegate{c: c, marked: marked}, listW, listH)
	l.SetShowTitle(false)
	l.Styles.TitleBar = lipgloss.NewStyle()
	l.SetShowStatusBar(false)
	l.SetFilteringEnabled(true)
	l.Styles.FilterPrompt = lipgloss.NewStyle().Foreground(ui.TmuxPink)
	l.Styles.FilterCursor = lipgloss.NewStyle().Foreground(ui.TmuxPink)
	l.Styles.NoItems = ui.SDim.Padding(1, 2)
	l.AdditionalShortHelpKeys = func() []key.Binding {
		return []key.Binding{
			key.NewBinding(key.WithKeys("tab"), key.WithHelp("tab", "mark")),
			key.NewBinding(key.WithKeys("ctrl+d"), key.WithHelp("ctrl+d", "dismiss")),
		}
	}

	return model{list: l, marked: marked, c: makeCols(listW), width: width, height: height}
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
		listW := msg.Width * 58 / 100
		listH := msg.Height - 3
		if listH < 5 {
			listH = 5
		}
		m.c = makeCols(listW)
		m.list.SetWidth(listW)
		m.list.SetHeight(listH)
		m.list.SetDelegate(itemDelegate{c: m.c, marked: m.marked})
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
	if m.quitting || m.width == 0 {
		return ""
	}

	title := ui.SolidTitle(m.width).Render("Agent Notifications")
	listW := m.width * 58 / 100
	previewW := m.width - listW
	listH := m.height - 3
	preview := ui.PreviewPanel(m.preview, previewW, listH, 0)
	body := lipgloss.JoinHorizontal(lipgloss.Top, m.list.View(), preview)
	footer := ui.Footer("enter:switch", "tab:mark", "ctrl+d:dismiss", "/:filter", "q:quit")

	return ui.FillHeight(title+"\n"+body+"\n"+footer, m.height)
}

// ── Main ──────────────────────────────────────────────────────────────────────

func main() {
	notifications := loadNotifications()

	width, height := 0, 0
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

	p := tea.NewProgram(newModel(notifications, width, height))
	result, err := p.Run()
	if err != nil {
		os.WriteFile("/tmp/agent-picker-err.txt", []byte(err.Error()+"\n"), 0644)
		os.Exit(1)
	}

	if fm, ok := result.(model); ok && fm.switchTo != nil && len(os.Args) > 1 {
		os.WriteFile(os.Args[1], []byte(fm.switchTo.target+"\t"+fm.switchTo.client+"\n"), 0600)
	}
}
