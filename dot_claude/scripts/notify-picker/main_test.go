package main

import (
	"os"
	"strconv"
	"testing"
	"time"
)

func TestParseAgentProcess(t *testing.T) {
	tests := []struct {
		name      string
		line      string
		wantAgent string
		want      bool
	}{
		{
			name:      "claude",
			line:      "01:23 claude claude --dangerously-skip-permissions",
			wantAgent: "Claude",
			want:      true,
		},
		{
			name:      "codex node launcher",
			line:      "02:34 node node /Users/me/.local/bin/codex --full-auto",
			wantAgent: "Codex",
			want:      true,
		},
		{
			name:      "codex native binary",
			line:      "03:45 /Users/me/.lo /Users/me/vendor/aarch64-apple-darwin/bin/codex --full-auto",
			wantAgent: "Codex",
			want:      true,
		},
		{
			name:      "opencode native binary",
			line:      "04:12 opencode opencode",
			wantAgent: "OpenCode",
			want:      true,
		},
		{
			name: "codex helper is not an agent",
			line: "04:56 /Users/me/.lo /Users/me/vendor/aarch64-apple-darwin/bin/codex-code-mode-host",
			want: false,
		},
		{
			name: "shell text mentioning codex is not an agent",
			line: "00:01 zsh /bin/zsh -c rg /bin/codex README.md",
			want: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, ok := parseAgentProcess(tt.line)
			if ok != tt.want {
				t.Fatalf("parseAgentProcess() ok = %v, want %v", ok, tt.want)
			}
			if ok && got.name != tt.wantAgent {
				t.Fatalf("parseAgentProcess() agent = %q, want %q", got.name, tt.wantAgent)
			}
		})
	}
}

func TestActiveTurnFromScreen(t *testing.T) {
	tests := []struct {
		name    string
		screen  string
		wantAge int64
		want    bool
	}{
		{
			name:    "codex active",
			screen:  "• Working (7m 12s • esc to interrupt)\n\n› Use /skills to list available skills\n",
			wantAge: 7*60 + 12,
			want:    true,
		},
		{
			name:    "claude active with changing spinner verb",
			screen:  "✻ Percolating… (1m 44s · esc to interrupt)\n",
			wantAge: 1*60 + 44,
			want:    true,
		},
		{
			name:   "opencode active",
			screen: "⬝⬝⬝⬝⬝⬝⬝⬝  esc interrupt                         171.6K (16%) · $3.15\n",
			want:   true,
		},
		{
			name:    "wrapped interrupt hint",
			screen:  "✻ Thinking… (49s ·\n  esc to interrupt)\n",
			wantAge: 49,
			want:    true,
		},
		{
			name:   "claude idle prompt overrides older progress",
			screen: "✻ Thinking… (49s · esc to interrupt)\nDone.\n❯\n⏵⏵ bypass permissions on\n",
			want:   false,
		},
		{
			name:   "resume confirmation is not active",
			screen: "Old progress (2m · esc to interrupt)\nEnter to confirm · Esc to cancel\n",
			want:   false,
		},
		{
			name:   "codex transport failure is not active",
			screen: "• Working (1h 2m • esc to interrupt)\n■ stream disconnected before completion\n› Retry\n",
			want:   false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			age, ok := activeTurnFromScreen(tt.screen)
			if ok != tt.want || age != tt.wantAge {
				t.Fatalf("activeTurnFromScreen() = (%d, %v), want (%d, %v)", age, ok, tt.wantAge, tt.want)
			}
		})
	}
}

func TestTurnTimestamp(t *testing.T) {
	now := time.Now().Unix()

	if got := turnTimestamp("", now-3600, 75, now); got != strconv.FormatInt(now-75, 10) {
		t.Fatalf("turnTimestamp() without hook = %q, want detected turn start", got)
	}

	fresh := strconv.FormatInt(now-70, 10)
	if got := turnTimestamp(fresh, now-3600, 75, now); got != fresh {
		t.Fatalf("turnTimestamp() fresh hook = %q, want %q", got, fresh)
	}

	stale := strconv.FormatInt(now-1800, 10)
	if got := turnTimestamp(stale, now-3600, 75, now); got != strconv.FormatInt(now-75, 10) {
		t.Fatalf("turnTimestamp() stale hook = %q, want detected turn start", got)
	}
}

func TestIsBackgroundShell(t *testing.T) {
	for _, comm := range []string{"bash", "zsh", "sh", "sleep"} {
		if !isBackgroundShell(comm) {
			t.Errorf("isBackgroundShell(%q) = false, want true", comm)
		}
	}
	for _, comm := range []string{"node", "claude", "codex", "mcp-grafana", "python3"} {
		if isBackgroundShell(comm) {
			t.Errorf("isBackgroundShell(%q) = true, want false", comm)
		}
	}
}

func TestBackgroundTTYs(t *testing.T) {
	// Mirrors the observed tree: a detached poll shell (76488) → node child
	// (99999) → claude agent (70308) on ttys061; a second detached shell hangs
	// off a non-agent login shell and must not mark any terminal.
	ppidByPID := map[int]int{
		76488: 99999, // poll shell's parent is a node child of the agent
		99999: 70308, // node child's parent is the agent
		70308: 10923, // agent's parent (tmux/login), not an agent
		55555: 4321,  // unrelated shell's parent
		4321:  1,     // reaches init without hitting an agent
	}
	agentTTYByPID := map[int]string{70308: "ttys061"}

	got := backgroundTTYs([]int{99999, 4321}, ppidByPID, agentTTYByPID)
	if !got["ttys061"] {
		t.Errorf("expected ttys061 to have scheduled background work, got %v", got)
	}
	if len(got) != 1 {
		t.Errorf("expected exactly one terminal flagged, got %v", got)
	}

	// A shell whose direct parent is the agent is detected too.
	got = backgroundTTYs([]int{70308}, ppidByPID, agentTTYByPID)
	if !got["ttys061"] {
		t.Errorf("direct agent child: expected ttys061, got %v", got)
	}

	// No detached shells → nothing flagged.
	if got = backgroundTTYs(nil, ppidByPID, agentTTYByPID); len(got) != 0 {
		t.Errorf("expected no terminals flagged, got %v", got)
	}
}

func TestLiveRunningDetection(t *testing.T) {
	if os.Getenv("AGENT_PICKER_LIVE_TEST") != "1" {
		t.Skip("set AGENT_PICKER_LIVE_TEST=1 to inspect the current tmux server")
	}
	rows := loadRunning()
	if len(rows) == 0 {
		t.Fatal("no active agent turns detected on the current tmux server")
	}
	for _, row := range rows {
		t.Logf("%s %s:%s.%s %s", row.project, row.session, row.windowName, row.paneIndex, row.paneTitle)
	}
}

func TestNotificationSource(t *testing.T) {
	legacy := make([]string, 8)
	if got := notificationAgent(legacy, "Codex"); got != "Codex" {
		t.Fatalf("legacy Codex notification labeled %q", got)
	}
	if got := notificationAgent(legacy, ""); got != "" {
		t.Fatalf("unknown legacy notification mislabeled %q", got)
	}
	if got := notificationAgent(append(legacy, "Claude"), "Codex"); got != "Codex" {
		t.Fatalf("stale Claude label overrides live Codex: %q", got)
	}
	for _, source := range []string{"Claude", "Codex", "OpenCode"} {
		if got := notificationAgent(append(legacy, source), ""); got != source {
			t.Fatalf("recorded source %q became %q", source, got)
		}
	}
}

func TestNotificationBuckets(t *testing.T) {
	queue := []Notification{
		{target: "work:1.1", paneID: "%7"},
		{target: "work:1.2", paneID: "%8"},
		{target: "work:1.3", paneID: "%9", visited: true},
	}
	running := []Notification{{target: "%7", paneID: "%7", running: true}}
	buckets := notificationBuckets(queue, running)
	if len(buckets[tabUnvisited]) != 1 || buckets[tabUnvisited][0].paneID != "%8" {
		t.Fatalf("running pane leaked into Unvisited: %+v", buckets[tabUnvisited])
	}
	if len(buckets[tabRunning]) != 1 || len(buckets[tabVisited]) != 1 {
		t.Fatal("lost running or visited entries")
	}
	// Hiding an active pane must not discard its pending notification.
	if got := notificationBuckets(queue, nil); len(got[tabUnvisited]) != 2 {
		t.Fatal("pending notification lost after activity ended")
	}
}

func TestLiveNotificationBuckets(t *testing.T) {
	if os.Getenv("AGENT_PICKER_LIVE_TEST") != "1" {
		t.Skip("set AGENT_PICKER_LIVE_TEST=1 to inspect the current tmux server")
	}
	buckets := loadAll()
	active := make(map[string]bool)
	for _, row := range buckets[tabRunning] {
		active[row.paneID] = true
	}
	for _, row := range buckets[tabUnvisited] {
		if active[row.paneID] {
			t.Fatal("live running pane also appears in Unvisited")
		}
	}
	for _, rows := range buckets {
		for _, row := range rows {
			if row.paneID == "" {
				t.Fatal("live row did not resolve a pane ID")
			}
		}
	}
	t.Logf("live buckets: %d unvisited, %d running, %d visited", len(buckets[0]), len(buckets[1]), len(buckets[2]))
}
