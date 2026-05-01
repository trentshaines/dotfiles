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
	running    bool
	timeAgo    string
}

const (
	tabUnvisited = 0
	tabRunning   = 1
	tabVisited   = 2
	tabCount     = 3
)

var tabLabels = [tabCount]string{"Unvisited", "Running", "Visited"}

func (n Notification) FilterValue() string {
	return n.session + " " + n.windowName + " " + n.paneTitle + " " + n.project
}
func (n Notification) Title() string       { return n.paneTitle }
func (n Notification) Description() string { return n.session }

const (
	staleVisitedTTL   = 7 * 24 * 60 * 60 // visited rows: 7 days
	staleUnvisitedTTL = 24 * 60 * 60      // unvisited rows: 24h
)

func sweepStale() {
	data, err := os.ReadFile(queueFile)
	if err != nil {
		return
	}
	now := time.Now().Unix()
	visitedCutoff   := now - int64(staleVisitedTTL)
	unvisitedCutoff := now - int64(staleUnvisitedTTL)
	lines := strings.Split(string(data), "\n")
	kept := make([]string, 0, len(lines))
	dropped := 0
	for _, line := range lines {
		if line == "" {
			continue
		}
		parts := strings.Split(line, "\t")
		if len(parts) >= 8 {
			ts, _      := strconv.ParseInt(parts[0], 10, 64)
			visited, _ := strconv.ParseInt(parts[7], 10, 64)
			// Drop visited rows older than 7 days
			if visited > 0 && visited < visitedCutoff {
				dropped++
				continue
			}
			// Drop unvisited rows older than 24h
			if visited == 0 && ts > 0 && ts < unvisitedCutoff {
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
			// Pane gone — auto-dismiss so it never shows again
			exec.Command(deleteScr, target).Run()
			continue
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

const runningFile = "/tmp/claude-running.queue"

// claudeRunningOn returns true if any process named "claude" is bound to the
// given terminal. tty should be the basename (e.g. "ttys003"), no "/dev/".
// Uses `ps -t <tty> -o comm=` which works reliably on macOS (pgrep -t is buggy here).
func claudeRunningOn(tty string) bool {
	if tty == "" {
		return false
	}
	out, err := exec.Command("ps", "-t", tty, "-o", "comm=").Output()
	if err != nil {
		return false
	}
	for _, line := range strings.Split(string(out), "\n") {
		if strings.TrimSpace(line) == "claude" {
			return true
		}
	}
	return false
}

// loadRunning reads the running queue maintained by notify-running-{start,end}.sh.
// Rows whose tmux pane no longer exists are dropped (and the file is rewritten).
// Format: TIMESTAMP\tPANE_ID\tTARGET\tCLIENT\tPROJECT\tSESSION\tWINDOW_NAME\tPANE_INDEX
func loadRunning() []Notification {
	data, err := os.ReadFile(runningFile)
	if err != nil {
		return nil
	}
	lines := strings.Split(strings.TrimRight(string(data), "\n"), "\n")
	kept := make([]string, 0, len(lines))
	var result []Notification
	for _, line := range lines {
		if line == "" {
			continue
		}
		parts := strings.Split(line, "\t")
		if len(parts) < 8 {
			continue
		}
		ts, paneID, target, client, project, session, window, paneIdx :=
			parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6], parts[7]

		// Validate pane still exists; also fetch its tty so we can verify
		// claude is actually running there. Hooks miss ungraceful exits
		// (kill, terminal close, Ctrl+C); the process check is the backstop.
		paneInfo, err := exec.Command(tmuxBin, "display-message", "-t", paneID, "-p", "#{pane_title}\t#{pane_tty}").Output()
		if err != nil {
			continue // pane gone — drop stale row
		}
		infoParts := strings.SplitN(strings.TrimSpace(string(paneInfo)), "\t", 2)
		if len(infoParts) != 2 {
			continue
		}
		raw := infoParts[0]
		paneTty := strings.TrimPrefix(infoParts[1], "/dev/")
		if !claudeRunningOn(paneTty) {
			continue // no live claude in this pane — drop stale row
		}
		paneTitle := raw
		for _, pfx := range []string{"✓ ", "✳ "} {
			paneTitle = strings.TrimPrefix(paneTitle, pfx)
		}
		if paneTitle == "" {
			paneTitle = window
		}

		kept = append(kept, line)
		result = append(result, Notification{
			ts:         ts,
			target:     target,
			client:     client,
			project:    project,
			session:    session,
			windowName: window,
			paneIndex:  paneIdx,
			paneTitle:  paneTitle,
			running:    true,
			timeAgo:    ago(ts),
		})
	}
	// Rewrite file if we dropped any stale rows.
	if len(kept) != len(lines) {
		out := strings.Join(kept, "\n")
		if len(kept) > 0 {
			out += "\n"
		}
		tmp := runningFile + ".tmp"
		if err := os.WriteFile(tmp, []byte(out), 0o644); err == nil {
			_ = os.Rename(tmp, runningFile)
		}
	}
	sort.SliceStable(result, func(i, j int) bool {
		// Most recently started first.
		return result[i].ts > result[j].ts
	})
	return result
}

// loadAll returns the three tab buckets: unvisited queue rows, running panes
// (live), visited queue rows. loadNotifications already runs sweepStale.
func loadAll() [tabCount][]Notification {
	queue := loadNotifications()
	var unvisited, visited []Notification
	for _, n := range queue {
		if n.visited {
			visited = append(visited, n)
		} else {
			unvisited = append(unvisited, n)
		}
	}
	return [tabCount][]Notification{unvisited, loadRunning(), visited}
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
	if sel {
		marker = ui.Caret()
	} else if mrk {
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
	if n.running {
		// Live tmux row: agent currently working.
		status = ui.SActive.Render("⠿ ")
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
			// Selected = bright white bold. Cursor signal lives here, not in row tone.
			fmt.Fprint(w, ui.SBright.Bold(true).Render(line))
		}
	} else {
		// Per-column colors. Unvisited rows stay normal — the left status glyph
		// (`⠿`/`✓`) carries the active vs done signal, not row brightness.
		locSty := ui.SNormal
		taskSty := ui.SNormal
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
		b, err := exec.Command(tmuxBin, "capture-pane", "-p", "-t", target, "-S", "-25").Output()
		if err != nil {
			return previewMsg("")
		}
		return previewMsg(string(b))
	}
}

type model struct {
	list     list.Model
	tabs     [tabCount][]Notification
	tabIdx   int
	marked   map[string]bool
	c        cols
	width    int
	height   int
	preview  string
	switchTo *Notification
	quitting bool
}

// itemsFor converts the slice of Notifications for tab i into list.Items.
func itemsFor(ns []Notification) []list.Item {
	items := make([]list.Item, len(ns))
	for i, n := range ns {
		items[i] = n
	}
	return items
}

// firstNonEmptyTab returns the lowest-index tab that has any rows. Falls back
// to Unvisited if every tab is empty so the picker still has a stable cursor.
func firstNonEmptyTab(tabs [tabCount][]Notification) int {
	for i := 0; i < tabCount; i++ {
		if len(tabs[i]) > 0 {
			return i
		}
	}
	return tabUnvisited
}

func newModel(tabs [tabCount][]Notification, width, height int) model {
	marked := make(map[string]bool)

	listW := width * 58 / 100
	listH := height - 4 // title(1) + tab strip(1) + footer(1) + buffer(1)
	if listH < 5 {
		listH = 5
	}
	c := makeCols(listW)

	startTab := firstNonEmptyTab(tabs)
	l := ui.NewList(itemsFor(tabs[startTab]), itemDelegate{c: c, marked: marked}, listW, listH)
	l.SetShowTitle(false)
	l.Styles.TitleBar = lipgloss.NewStyle()
	l.SetShowStatusBar(false)
	l.SetFilteringEnabled(true)
	l.Styles.FilterPrompt = lipgloss.NewStyle().Foreground(ui.TmuxPink)
	l.Styles.FilterCursor = lipgloss.NewStyle().Foreground(ui.TmuxPink)
	l.Styles.NoItems = ui.SDim.Padding(1, 2)
	l.AdditionalShortHelpKeys = func() []key.Binding {
		return []key.Binding{
			key.NewBinding(key.WithKeys("←/→"), key.WithHelp("←/→", "tab")),
			key.NewBinding(key.WithKeys("tab"), key.WithHelp("tab", "mark")),
			key.NewBinding(key.WithKeys("ctrl+d"), key.WithHelp("ctrl+d", "dismiss")),
		}
	}

	return model{
		list:   l,
		tabs:   tabs,
		tabIdx: startTab,
		marked: marked,
		c:      c,
		width:  width,
		height: height,
	}
}

// switchTab swaps the list's items to those of tab idx. Resets cursor and
// clears any active filter, since filter context doesn't carry across tabs.
func (m *model) switchTab(idx int) {
	if idx < 0 {
		idx = tabCount - 1
	}
	if idx >= tabCount {
		idx = 0
	}
	m.tabIdx = idx
	if m.list.FilterState() != list.Unfiltered {
		m.list.ResetFilter()
	}
	m.list.SetItems(itemsFor(m.tabs[idx]))
	m.list.ResetSelected()
}

// renderTabStrip renders the row of tab labels with counts. Active tab is
// bracketed and bold; inactive tabs are dim.
func renderTabStrip(active int, tabs [tabCount][]Notification) string {
	var parts []string
	for i := 0; i < tabCount; i++ {
		text := fmt.Sprintf("%s %d", tabLabels[i], len(tabs[i]))
		if i == active {
			parts = append(parts, ui.SBright.Bold(true).Render("[ "+text+" ]"))
		} else {
			parts = append(parts, ui.SDim.Render("  "+text+"  "))
		}
	}
	return "  " + strings.Join(parts, " ")
}

func (m model) Init() tea.Cmd {
	if item, ok := m.list.SelectedItem().(Notification); ok {
		return fetchPreview(item.target)
	}
	return nil
}

func (m model) reload() model {
	m.tabs = loadAll()
	if len(m.tabs[m.tabIdx]) == 0 && m.tabIdx != tabUnvisited {
		// Avoid landing on an empty tab after a dismiss.
		m.tabIdx = firstNonEmptyTab(m.tabs)
	}
	m.list.SetItems(itemsFor(m.tabs[m.tabIdx]))
	m.list.SetDelegate(itemDelegate{c: m.c, marked: m.marked})
	return m
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {

	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		listW := msg.Width * 58 / 100
		listH := msg.Height - 4 // title + tab strip + footer + buffer
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

		case "left", "shift+tab", "ctrl+h":
			m.switchTab(m.tabIdx - 1)
			if item, ok := m.list.SelectedItem().(Notification); ok {
				return m, fetchPreview(item.target)
			}
			return m, nil

		case "right", "ctrl+l":
			m.switchTab(m.tabIdx + 1)
			if item, ok := m.list.SelectedItem().(Notification); ok {
				return m, fetchPreview(item.target)
			}
			return m, nil

		case "enter":
			if item, ok := m.list.SelectedItem().(Notification); ok {
				n := item
				m.switchTo = &n
				// Explicit visit via the picker counts as engagement —
				// pop the row off the queue so it doesn't reappear dimmed.
				// (No-op for Running rows since they aren't in the queue.)
				if !n.running {
					exec.Command(deleteScr, n.target).Run()
				}
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
			// Dismiss is queue-only — no-op on Running tab.
			if m.tabIdx == tabRunning {
				return m, nil
			}
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
	tabStrip := renderTabStrip(m.tabIdx, m.tabs)
	bodyH := m.height - 3 // title(1) + footer(1) + buffer(1)
	listView := m.list.View()
	// Stack tab strip above the list in the left column.
	leftCol := tabStrip + "\n" + listView

	// Measure actual rendered left-column width so preview fills exactly to the right edge.
	actualLeftW := 0
	for _, row := range strings.Split(leftCol, "\n") {
		if w := lipgloss.Width(row); w > actualLeftW {
			actualLeftW = w
		}
	}
	previewW := m.width - actualLeftW
	if previewW < 10 {
		previewW = 10
	}
	preview := ui.PreviewPanel(m.preview, previewW, bodyH, 0)
	body := lipgloss.JoinHorizontal(lipgloss.Top, leftCol, preview)
	footer := ui.Footer("←/→:tab", "enter:switch", "tab:mark", "ctrl+d:dismiss", "/:filter", "q:quit")

	return ui.FillHeight(title+"\n"+body+"\n"+footer, m.height)
}

// ── Main ──────────────────────────────────────────────────────────────────────

func main() {
	tabs := loadAll()

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

	p := tea.NewProgram(newModel(tabs, width, height))
	result, err := p.Run()
	if err != nil {
		os.WriteFile("/tmp/agent-picker-err.txt", []byte(err.Error()+"\n"), 0644)
		os.Exit(1)
	}

	if fm, ok := result.(model); ok && fm.switchTo != nil && len(os.Args) > 1 {
		os.WriteFile(os.Args[1], []byte(fm.switchTo.target+"\t"+fm.switchTo.client+"\n"), 0600)
	}
}
