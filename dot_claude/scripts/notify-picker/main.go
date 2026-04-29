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
		paneExists := false
		if b, err := exec.Command(tmuxBin, "display-message", "-t", target, "-p", "#{pane_title}").Output(); err == nil {
			raw = strings.TrimSpace(string(b))
			paneExists = true
		}
		// Skip stale targets where the pane no longer exists
		if !paneExists {
			continue
		}
		done := strings.HasPrefix(raw, "✓")
		paneTitle := raw
		for _, pfx := range []string{"✓ ", "✳ "} {
			paneTitle = strings.TrimPrefix(paneTitle, pfx)
		}
		// Fall back to window name if pane title is empty
		if paneTitle == "" {
			paneTitle = window
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

// ── Display ───────────────────────────────────────────────────────────────────

func runes(s string) int { return len([]rune(s)) }

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

func pad(s string, width int) string {
	s = trunc(s, width)
	return s + strings.Repeat(" ", width-runes(s))
}

// ── Delegate ──────────────────────────────────────────────────────────────────

type cols struct{ loc, task, timeW, proj int }

type itemDelegate struct {
	c      cols
	marked map[string]bool
}

func (d itemDelegate) Height() int                              { return 1 }
func (d itemDelegate) Spacing() int                             { return 0 }
func (d itemDelegate) Update(_ tea.Msg, _ *list.Model) tea.Cmd { return nil }

// TokyoNight-based palette
var (
	cYellow  = lipgloss.Color("#e0af68") // warm yellow — selected
	cOrange  = lipgloss.Color("#ff9e64") // orange — marked for dismiss
	cRed     = lipgloss.Color("#f7768e") // red — selected+marked
	cTeal    = lipgloss.Color("#73daca") // teal — active/running Claude
	cMuted   = lipgloss.Color("#565f89") // muted — done tasks
	cBlue    = lipgloss.Color("#7aa2f7") // blue — project
	cPurple  = lipgloss.Color("#9d7cd8") // purple — time
	cFg      = lipgloss.Color("#a9b1d6") // normal fg
	cComment = lipgloss.Color("#414868") // border/footer

	sSel     = lipgloss.NewStyle().Foreground(cYellow).Bold(true)
	sSelMark = lipgloss.NewStyle().Foreground(cRed).Bold(true)
	sMarked  = lipgloss.NewStyle().Foreground(cOrange)
	sActive  = lipgloss.NewStyle().Foreground(cTeal)
	sDone    = lipgloss.NewStyle().Foreground(cMuted)
	sLoc     = lipgloss.NewStyle().Foreground(cFg)
	sTime    = lipgloss.NewStyle().Foreground(cPurple)
	sProj    = lipgloss.NewStyle().Foreground(cBlue)
)

func (d itemDelegate) Render(w io.Writer, m list.Model, index int, item list.Item) {
	n, ok := item.(Notification)
	if !ok {
		return
	}
	sel := index == m.Index()
	mrk := d.marked[n.target]

	marker := "  "
	if mrk {
		marker = "◉ "
	}
	status := "⠿ "
	if n.done {
		status = "✓ "
	}

	taskStr := "[" + n.paneIndex + "] " + n.paneTitle

	if sel || mrk {
		// Selected/marked: whole line one color
		line := marker + status +
			pad(n.session+" → "+n.windowName, d.c.loc) + "  " +
			pad(taskStr, d.c.task) + "  " +
			pad(n.timeAgo, d.c.timeW) + "  " +
			trunc(n.project, d.c.proj)
		switch {
		case sel && mrk:
			fmt.Fprint(w, sSelMark.Render(line))
		case sel:
			fmt.Fprint(w, sSel.Render(line))
		default:
			fmt.Fprint(w, sMarked.Render(line))
		}
	} else {
		// Normal: per-column colors
		taskStyle := sActive
		if n.done {
			taskStyle = sDone
		}
		fmt.Fprint(w,
			marker+status+
				sLoc.Render(pad(n.session+" → "+n.windowName, d.c.loc))+"  "+
				taskStyle.Render(pad(taskStr, d.c.task))+"  "+
				sTime.Render(pad(n.timeAgo, d.c.timeW))+"  "+
				sProj.Render(trunc(n.project, d.c.proj)),
		)
	}
}

func makeCols(width int) cols {
	// line: marker(2) + status(2) + loc + "  " + task + "  " + time + "  " + proj
	// subtract 4 for list's own internal offset
	w := width - 4
	timeW := 9
	proj := 20
	loc := 32
	// task gets everything left
	task := w - 2 - 2 - loc - 2 - 2 - timeW - 2 - proj
	if task < 12 {
		task = 12
	}
	return cols{loc: loc, task: task, timeW: timeW, proj: proj}
}

// ── Msgs ──────────────────────────────────────────────────────────────────────

type previewMsg string

func fetchPreview(target string) tea.Cmd {
	return func() tea.Msg {
		b, err := exec.Command(tmuxBin, "capture-pane", "-p", "-e", "-t", target, "-S", "-12").Output()
		if err != nil {
			return previewMsg("")
		}
		return previewMsg(string(b))
	}
}

// ── Model ─────────────────────────────────────────────────────────────────────

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

var (
	sFooter  = lipgloss.NewStyle().Foreground(cComment)
	sPreview = lipgloss.NewStyle().Foreground(cMuted).PaddingLeft(1)
	sPrvBox  = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(cComment)
)

func newModel(notifications []Notification, width, height int) model {
	c := makeCols(width)
	marked := make(map[string]bool)

	items := make([]list.Item, len(notifications))
	for i, n := range notifications {
		items[i] = n
	}

	previewH := 8
	listH := height - previewH - 3 // footer + borders
	if listH < 5 {
		listH = 5
	}

	l := list.New(items, itemDelegate{c: c, marked: marked}, width, listH)
	l.Title = "Claude Notifications"
	l.SetShowStatusBar(true)
	l.SetFilteringEnabled(true)
	l.Styles.Title = lipgloss.NewStyle().
		Foreground(cYellow).Bold(true).Padding(0, 1)
	l.AdditionalShortHelpKeys = func() []key.Binding {
		return []key.Binding{
			key.NewBinding(key.WithKeys("tab"), key.WithHelp("tab", "mark")),
			key.NewBinding(key.WithKeys("ctrl+d"), key.WithHelp("ctrl+d", "dismiss")),
		}
	}

	m := model{list: l, marked: marked, c: c, width: width, height: height}
	return m
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
		m.width = msg.Width
		m.height = msg.Height
		m.c = makeCols(msg.Width)
		previewH := 8
		listH := msg.Height - previewH - 3
		if listH < 5 {
			listH = 5
		}
		m.list.SetWidth(msg.Width)
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
		case "ctrl+c", "esc":
			m.quitting = true
			return m, tea.Quit

		case "q":
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
			m = m.reload()
			if len(m.list.Items()) == 0 {
				m.quitting = true
				return m, tea.Quit
			}
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

	// Preview: last few non-empty lines
	lines := strings.Split(m.preview, "\n")
	var kept []string
	for _, l := range lines {
		if strings.TrimSpace(l) != "" {
			kept = append(kept, l)
		}
	}
	if len(kept) > 6 {
		kept = kept[len(kept)-6:]
	}
	prvContent := sPreview.Render(strings.Join(kept, "\n"))
	preview := sPrvBox.Width(m.width - 4).Render(prvContent)

	footer := sFooter.Render("  enter:switch  tab:mark  ctrl+d:dismiss  /:filter  q:quit")

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
	height := 40
	if h := os.Getenv("TMUX_CLIENT_HEIGHT"); h != "" {
		if n, err := strconv.Atoi(h); err == nil {
			height = n * 50 / 100
		}
	}

	p := tea.NewProgram(
		newModel(notifications, width, height),
		tea.WithAltScreen(),
	)

	result, err := p.Run()
	if err != nil {
		os.Exit(1)
	}

	// Write target+client to result file — shell wrapper handles the switch after popup closes
	if fm, ok := result.(model); ok && fm.switchTo != nil && len(os.Args) > 1 {
		os.WriteFile(os.Args[1], []byte(fm.switchTo.target+"\t"+fm.switchTo.client+"\n"), 0600)
	}
}
