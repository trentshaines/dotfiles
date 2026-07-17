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
