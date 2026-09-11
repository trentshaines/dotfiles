package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"syscall"
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
	paneID     string
	client     string
	project    string
	session    string
	windowName string
	paneIndex  string
	paneTitle  string
	done       bool
	visited    bool
	running    bool
	scheduled  bool   // running via a background poll/wakeup rather than an active turn
	agent      string // "Claude" | "Codex" | "OpenCode" | ""
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
	staleUnvisitedTTL = 24 * 60 * 60     // unvisited rows: 24h
)

func withFileLock(path string, fn func()) {
	lock, err := os.OpenFile(path+".lock", os.O_CREATE|os.O_RDWR, 0o644)
	if err != nil {
		return
	}
	defer lock.Close()
	if err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX); err != nil {
		return
	}
	defer syscall.Flock(int(lock.Fd()), syscall.LOCK_UN)
	fn()
}

func atomicWrite(path string, data []byte, mode os.FileMode) error {
	tmp, err := os.CreateTemp(filepath.Dir(path), filepath.Base(path)+".tmp.*")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	defer os.Remove(tmpName)

	if err := tmp.Chmod(mode); err != nil {
		tmp.Close()
		return err
	}
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmpName, path)
}

func sweepStale() {
	withFileLock(queueFile, func() {
		data, err := os.ReadFile(queueFile)
		if err != nil {
			return
		}
		now := time.Now().Unix()
		visitedCutoff := now - int64(staleVisitedTTL)
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
				ts, _ := strconv.ParseInt(parts[0], 10, 64)
				visited, _ := strconv.ParseInt(parts[7], 10, 64)
				// Drop visited rows older than 7 days.
				if visited > 0 && visited < visitedCutoff {
					dropped++
					continue
				}
				// Drop unvisited rows older than 24h.
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
		_ = atomicWrite(queueFile, []byte(out), 0o644)
	})
}

// The live pane is authoritative for its label. Older hooks could explicitly
// mislabel Codex as Claude when CODEX_THREAD_ID was absent.
func notificationAgent(parts []string, live string) string {
	if live != "" {
		return live
	}
	if len(parts) > 8 {
		switch parts[8] {
		case "Claude", "Codex", "OpenCode":
			return parts[8]
		}
	}
	return live
}

func loadNotifications() []Notification {
	sweepStale()

	f, err := os.Open(queueFile)
	if err != nil {
		return nil
	}
	defer f.Close()

	processes, _ := scanProcesses()
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

		raw, paneID, tty := "", "", ""
		if b, err := exec.Command(tmuxBin, "display-message", "-t", target, "-p", "#{pane_id}\t#{pane_tty}\t#{pane_title}").Output(); err == nil {
			context := strings.SplitN(strings.TrimRight(string(b), "\n"), "\t", 3)
			if len(context) != 3 {
				continue
			}
			paneID, tty, raw = context[0], strings.TrimPrefix(context[1], "/dev/"), context[2]
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
			ts: ts, target: target, paneID: paneID, client: client,
			project: project, session: session, windowName: window,
			paneIndex: paneIdx, paneTitle: paneTitle, done: done,
			visited: visited != "0",
			agent:   notificationAgent(parts, processes[tty].name),
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

type runningQueueEntry struct {
	ts      string
	client  string
	project string
}

type agentProcess struct {
	name      string
	startedAt int64
	pid       int
}

type tmuxPane struct {
	id      string
	tty     string
	session string
	winIdx  string
	winName string
	paneIdx string
	title   string
	path    string
}

// readRunningQueue preserves hook-provided start timestamps when present. The
// live tmux scan below is authoritative for whether a pane exists and has an
// agent process attached.
func readRunningQueue() map[string]runningQueueEntry {
	entries := make(map[string]runningQueueEntry)
	data, err := os.ReadFile(runningFile)
	if err != nil {
		return entries
	}
	for _, line := range strings.Split(strings.TrimRight(string(data), "\n"), "\n") {
		if line == "" {
			continue
		}
		parts := strings.Split(line, "\t")
		if len(parts) < 8 {
			continue
		}
		entries[parts[1]] = runningQueueEntry{
			ts:      parts[0],
			client:  parts[3],
			project: parts[4],
		}
	}
	return entries
}

func loadTmuxPanes() []tmuxPane {
	format := strings.Join([]string{
		"#{pane_id}", "#{pane_tty}", "#{session_name}", "#{window_index}",
		"#{window_name}", "#{pane_index}", "#{pane_title}", "#{pane_current_path}",
	}, "\t")
	out, err := exec.Command(tmuxBin, "list-panes", "-a", "-F", format).Output()
	if err != nil {
		return nil
	}

	var panes []tmuxPane
	for _, line := range strings.Split(strings.TrimRight(string(out), "\n"), "\n") {
		if line == "" {
			continue
		}
		parts := strings.SplitN(line, "\t", 8)
		if len(parts) != 8 {
			continue
		}
		panes = append(panes, tmuxPane{
			id:      parts[0],
			tty:     strings.TrimPrefix(parts[1], "/dev/"),
			session: parts[2],
			winIdx:  parts[3],
			winName: parts[4],
			paneIdx: parts[5],
			title:   parts[6],
			path:    parts[7],
		})
	}
	return panes
}

func projectName(path string) string {
	path = strings.TrimRight(path, "/")
	if path == "" {
		return ""
	}
	if path == homeDir {
		return "~"
	}
	parts := strings.Split(path, "/")
	return parts[len(parts)-1]
}

func parseElapsedSeconds(value string) (int64, bool) {
	dayParts := strings.SplitN(value, "-", 2)
	days := int64(0)
	timePart := value
	if len(dayParts) == 2 {
		n, err := strconv.ParseInt(dayParts[0], 10, 64)
		if err != nil {
			return 0, false
		}
		days = n
		timePart = dayParts[1]
	}

	parts := strings.Split(timePart, ":")
	total := days * 24 * 60 * 60
	switch len(parts) {
	case 2:
		mins, err1 := strconv.ParseInt(parts[0], 10, 64)
		secs, err2 := strconv.ParseInt(parts[1], 10, 64)
		if err1 != nil || err2 != nil {
			return 0, false
		}
		return total + mins*60 + secs, true
	case 3:
		hours, err1 := strconv.ParseInt(parts[0], 10, 64)
		mins, err2 := strconv.ParseInt(parts[1], 10, 64)
		secs, err3 := strconv.ParseInt(parts[2], 10, 64)
		if err1 != nil || err2 != nil || err3 != nil {
			return 0, false
		}
		return total + hours*60*60 + mins*60 + secs, true
	default:
		return 0, false
	}
}

func parseAgentProcess(line string) (agentProcess, bool) {
	fields := strings.Fields(line)
	if len(fields) < 3 {
		return agentProcess{}, false
	}
	elapsed, ok := parseElapsedSeconds(fields[0])
	if !ok {
		return agentProcess{}, false
	}
	comm := fields[1]
	args := fields[2:]
	commBase := filepath.Base(comm)
	argBase := func(i int) string {
		if i >= len(args) {
			return ""
		}
		return filepath.Base(strings.Trim(args[i], `"'`))
	}

	switch {
	case commBase == "claude" || argBase(0) == "claude" ||
		((argBase(0) == "node" || argBase(0) == "bun") && argBase(1) == "claude"):
		return agentProcess{name: "Claude", startedAt: time.Now().Unix() - elapsed}, true
	case argBase(0) == "codex" ||
		((argBase(0) == "node" || argBase(0) == "bun") && argBase(1) == "codex"):
		return agentProcess{name: "Codex", startedAt: time.Now().Unix() - elapsed}, true
	case commBase == "opencode" || argBase(0) == "opencode" ||
		((argBase(0) == "node" || argBase(0) == "bun") && argBase(1) == "opencode"):
		return agentProcess{name: "OpenCode", startedAt: time.Now().Unix() - elapsed}, true
	default:
		return agentProcess{}, false
	}
}

// isBackgroundShell reports whether a command is a shell or sleep — the shape a
// scheduled poll/wakeup takes when an agent parks work in a background process.
func isBackgroundShell(comm string) bool {
	switch comm {
	case "bash", "zsh", "sh", "dash", "fish", "sleep":
		return true
	}
	return false
}

// scanProcesses takes one process-table snapshot and returns two things:
//   - known CLI agents indexed by terminal (faster and more internally
//     consistent than running ps once per tmux pane), and
//   - the set of terminals whose agent has a live *detached* background shell.
//
// Claude Code, Codex, and OpenCode run background Bash via setsid, so a
// scheduled poll or wakeup shows up as a shell with no controlling terminal
// ("??") whose parent chain leads back to the agent still sitting on its pane.
// That agent is genuinely still working, so its pane should read as running
// even between visible turns.
func scanProcesses() (map[string]agentProcess, map[string]bool) {
	agents := make(map[string]agentProcess)
	background := make(map[string]bool)

	out, err := exec.Command("/bin/ps", "ax",
		"-o", "pid=", "-o", "ppid=", "-o", "tty=", "-o", "etime=", "-o", "comm=", "-o", "args=").Output()
	if err != nil {
		return agents, background
	}

	ppidByPID := make(map[int]int)        // pid -> parent pid, for every process
	agentTTYByPID := make(map[int]string) // agent pid -> its terminal
	var detachedPPIDs []int               // parents of detached background shells

	for _, line := range strings.Split(string(out), "\n") {
		fields := strings.Fields(line)
		if len(fields) < 6 {
			continue
		}
		pid, err1 := strconv.Atoi(fields[0])
		ppid, err2 := strconv.Atoi(fields[1])
		if err1 != nil || err2 != nil {
			continue
		}
		ppidByPID[pid] = ppid

		tty := fields[2]
		comm := filepath.Base(fields[4])
		// parseAgentProcess expects the "etime comm args…" tail (everything
		// after the tty column), matching the original ps column layout.
		rest := strings.Join(fields[3:], " ")

		if tty == "??" || tty == "?" {
			// Detached — a candidate scheduled poll/wakeup helper.
			if isBackgroundShell(comm) {
				detachedPPIDs = append(detachedPPIDs, ppid)
			}
			continue
		}

		ttyName := strings.TrimPrefix(tty, "/dev/")
		if proc, ok := parseAgentProcess(rest); ok {
			proc.pid = pid
			agentTTYByPID[pid] = ttyName
			// A node launcher and its native child can both match. Keep the
			// older process so the fallback timestamp represents the whole CLI
			// session (and so it is the common ancestor of any helpers).
			if existing, found := agents[ttyName]; !found || proc.startedAt < existing.startedAt {
				agents[ttyName] = proc
			}
		}
	}

	return agents, backgroundTTYs(detachedPPIDs, ppidByPID, agentTTYByPID)
}

// backgroundTTYs walks each detached background shell (identified by its parent
// pid) up the process tree and marks the terminal of the first agent ancestor
// it reaches. Pure so it can be tested without a live process table.
func backgroundTTYs(detachedPPIDs []int, ppidByPID map[int]int, agentTTYByPID map[int]string) map[string]bool {
	out := make(map[string]bool)
	for _, ppid := range detachedPPIDs {
		for cur, hops := ppid, 0; cur > 1 && hops < 32; cur, hops = ppidByPID[cur], hops+1 {
			if tty, ok := agentTTYByPID[cur]; ok {
				out[tty] = true
				break
			}
		}
	}
	return out
}

func parseStatusDurationSeconds(line string) (int64, bool) {
	start := strings.Index(line, "(")
	if start < 0 {
		return 0, false
	}
	end := strings.Index(line[start+1:], ")")
	if end < 0 {
		return 0, false
	}
	segment := line[start+1 : start+1+end]
	var total int64
	seen := false
	for _, field := range strings.Fields(segment) {
		field = strings.Trim(field, ",;")
		if field == "·" || field == "•" {
			break
		}
		if len(field) < 2 {
			continue
		}
		unit := field[len(field)-1]
		n, err := strconv.ParseInt(field[:len(field)-1], 10, 64)
		if err != nil {
			continue
		}
		switch unit {
		case 'd':
			total += n * 24 * 60 * 60
		case 'h':
			total += n * 60 * 60
		case 'm':
			total += n * 60
		case 's':
			total += n
		default:
			continue
		}
		seen = true
	}
	return total, seen
}

// activeTurnFromScreen recognizes the shared, user-facing contract exposed by
// both CLIs: an active turn offers "esc to interrupt". Agent-specific spinner
// verbs change frequently and can wrap independently in narrow panes, so they
// are deliberately not part of the predicate. The returned age is best-effort.
func activeTurnFromScreen(screen string) (int64, bool) {
	lines := strings.Split(strings.TrimRight(screen, "\n"), "\n")
	checked := 0
	for i := len(lines) - 1; i >= 0 && checked < 24; i-- {
		line := strings.TrimSpace(lines[i])
		if line == "" {
			continue
		}
		checked++
		lower := strings.ToLower(line)

		// These appear below any older progress text and mean the CLI is idle
		// or waiting for user input.
		if line == "❯" ||
			strings.Contains(lower, "esc to cancel") ||
			strings.HasPrefix(line, "■ ") {
			return 0, false
		}
		if strings.Contains(lower, "esc to interrupt") ||
			strings.Contains(lower, "esc interrupt") {
			if secs, ok := parseStatusDurationSeconds(line); ok {
				return secs, true
			}
			// In a narrow pane the duration and interrupt hint can wrap onto
			// adjacent lines.
			for j := i - 1; j >= 0 && j >= i-2; j-- {
				wrapped := strings.Join(lines[j:i+1], " ")
				if secs, ok := parseStatusDurationSeconds(strings.TrimSpace(wrapped)); ok {
					return secs, true
				}
			}
			return 0, true
		}
	}
	return 0, false
}

func paneActiveTurn(paneID string) (int64, bool) {
	out, err := exec.Command(tmuxBin, "capture-pane", "-p", "-t", paneID).Output()
	if err != nil {
		return 0, false
	}
	return activeTurnFromScreen(string(out))
}

func turnTimestamp(queueTS string, procStartedAt, activeAge, now int64) string {
	if activeAge > 0 {
		detected := now - activeAge
		if queued, err := strconv.ParseInt(queueTS, 10, 64); err != nil ||
			queued < detected-90 || queued > detected+90 {
			return strconv.FormatInt(detected, 10)
		}
	}
	if queueTS != "" {
		return queueTS
	}
	return strconv.FormatInt(procStartedAt, 10)
}

// loadRunning scans live tmux panes for known agent processes. The queue
// maintained by notify-running-{start,end}.sh is a timestamp cache, not the
// source of truth, so Codex panes and hook misses still show up.
func loadRunning() []Notification {
	queue := readRunningQueue()
	processes, background := scanProcesses()
	var result []Notification

	for _, pane := range loadTmuxPanes() {
		proc, ok := processes[pane.tty]
		if !ok {
			continue
		}
		activeAge, active := paneActiveTurn(pane.id)
		scheduled := background[pane.tty]
		// Show the pane while the agent is visibly working *or* while it has a
		// scheduled poll/wakeup parked in a background shell. Skip only truly
		// idle panes.
		if !active && !scheduled {
			continue
		}

		paneTitle := pane.title
		for _, pfx := range []string{"✓ ", "✳ "} {
			paneTitle = strings.TrimPrefix(paneTitle, pfx)
		}
		if paneTitle == "" {
			paneTitle = pane.winName
		}

		entry := queue[pane.id]
		project := entry.project
		if project == "" {
			project = projectName(pane.path)
		}
		ts := turnTimestamp(entry.ts, proc.startedAt, activeAge, time.Now().Unix())

		result = append(result, Notification{
			ts:         ts,
			target:     pane.id,
			paneID:     pane.id,
			client:     entry.client,
			project:    project,
			session:    pane.session,
			windowName: pane.winName,
			paneIndex:  pane.paneIdx,
			paneTitle:  paneTitle,
			running:    true,
			scheduled:  !active && scheduled,
			agent:      proc.name,
			timeAgo:    ago(ts),
		})
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
	return notificationBuckets(loadNotifications(), loadRunning())
}

func notificationBuckets(queue, running []Notification) [tabCount][]Notification {
	active := make(map[string]bool)
	for _, n := range running {
		active[n.paneID] = true
	}
	var unvisited, visited []Notification
	for _, n := range queue {
		if n.visited {
			visited = append(visited, n)
		} else if n.paneID == "" || !active[n.paneID] {
			unvisited = append(unvisited, n)
		}
	}
	return [tabCount][]Notification{unvisited, running, visited}
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

type cols struct{ agent, loc, task, timeW, proj int }

func makeCols(width int) cols {
	// line layout: "  "(marker,2) + status(2) + agent + "  " + loc + "  " +
	//              task + "  " + time + "  " + proj
	w := width - 4 // safety margin for list internal offset
	agent, timeW, proj, loc := 9, 9, 16, 26
	// fixed overhead = marker(2) + status(2) + four "  " separators(8) = 12
	task := w - 12 - agent - loc - timeW - proj
	if task < 12 {
		task = 12
	}
	return cols{agent: agent, loc: loc, task: task, timeW: timeW, proj: proj}
}

// ── Delegate ──────────────────────────────────────────────────────────────────

type itemDelegate struct {
	c      cols
	marked map[string]bool
}

func (d itemDelegate) Height() int                             { return 1 }
func (d itemDelegate) Spacing() int                            { return 0 }
func (d itemDelegate) Update(_ tea.Msg, _ *list.Model) tea.Cmd { return nil }

// agentThemes gives each CLI a distinct color + lowercase label so Claude,
// Codex, and OpenCode rows are told apart at a glance.
var agentThemes = map[string]struct {
	label string
	style lipgloss.Style
}{
	"Claude":   {"claude", lipgloss.NewStyle().Foreground(ui.Cyan)},
	"Codex":    {"codex", lipgloss.NewStyle().Foreground(ui.Green)},
	"OpenCode": {"opencode", lipgloss.NewStyle().Foreground(ui.Orange)},
}

// agentCell renders the fixed-width, color-coded agent label. Unknown agents
// render as blank padding so columns still line up; visited rows dim to match
// the rest of the row.
func agentCell(name string, width int, dim bool) string {
	th, ok := agentThemes[name]
	if !ok {
		return strings.Repeat(" ", width)
	}
	text := ui.Pad(th.label, width)
	if dim {
		return ui.SDim.Render(text)
	}
	return th.style.Render(text)
}

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
		if n.scheduled {
			// Live, but parked on a scheduled poll/wakeup rather than an
			// active turn — still running, just waiting to resume.
			status = ui.SInfo.Render("◴ ")
		} else {
			// Live tmux row: agent currently working.
			status = ui.SActive.Render("⠿ ")
		}
	}

	locStr := n.session + " → " + n.windowName
	taskStr := "[" + n.paneIndex + "] " + n.paneTitle

	if sel {
		// Keep the agent color even on the selected row; the rest of the line
		// carries the bright/marked cursor signal.
		agent := agentCell(n.agent, d.c.agent, false)
		rest := ui.Pad(locStr, d.c.loc) + "  " +
			ui.Pad(taskStr, d.c.task) + "  " +
			ui.Pad(n.timeAgo, d.c.timeW) + "  " +
			ui.Trunc(n.project, d.c.proj)
		if mrk {
			fmt.Fprint(w, marker+status+agent+"  "+ui.SSelMark.Render(rest))
		} else {
			// Selected = bright white bold. Cursor signal lives here, not in row tone.
			fmt.Fprint(w, marker+status+agent+"  "+ui.SBright.Bold(true).Render(rest))
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
			marker+status+agentCell(n.agent, d.c.agent, n.visited)+"  "+
				locSty.Render(ui.Pad(locStr, d.c.loc))+"  "+
				taskSty.Render(ui.Pad(taskStr, d.c.task))+"  "+
				timeSty.Render(ui.Pad(n.timeAgo, d.c.timeW))+"  "+
				projSty.Render(ui.Trunc(n.project, d.c.proj)),
		)
	}
}

// ── Model ─────────────────────────────────────────────────────────────────────

type previewMsg string
type refreshMsg struct{}

func refreshAfter(delay time.Duration) tea.Cmd {
	return tea.Tick(delay, func(time.Time) tea.Msg { return refreshMsg{} })
}

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
	cmds := []tea.Cmd{refreshAfter(2 * time.Second)}
	if item, ok := m.list.SelectedItem().(Notification); ok {
		cmds = append(cmds, fetchPreview(item.target))
	}
	return tea.Batch(cmds...)
}

func (m model) reload() model {
	selectedTarget := ""
	if item, ok := m.list.SelectedItem().(Notification); ok {
		selectedTarget = item.target
	}
	m.tabs = loadAll()
	if len(m.tabs[m.tabIdx]) == 0 && m.tabIdx != tabUnvisited {
		// Avoid landing on an empty tab after a dismiss.
		m.tabIdx = firstNonEmptyTab(m.tabs)
	}
	m.list.SetItems(itemsFor(m.tabs[m.tabIdx]))
	m.list.SetDelegate(itemDelegate{c: m.c, marked: m.marked})
	for i, n := range m.tabs[m.tabIdx] {
		if n.target == selectedTarget {
			m.list.Select(i)
			break
		}
	}
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

	case refreshMsg:
		m = m.reload()
		cmds := []tea.Cmd{refreshAfter(2 * time.Second)}
		if item, ok := m.list.SelectedItem().(Notification); ok {
			cmds = append(cmds, fetchPreview(item.target))
		}
		return m, tea.Batch(cmds...)

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
