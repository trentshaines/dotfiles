package tui

import (
	"fmt"
	"os/exec"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
)

const tmuxBin = "/opt/homebrew/bin/tmux"

// PanePreviewMsg is the async result of PanePreviewCmd.
type PanePreviewMsg string

func panePreviewCmd(paneID string, lines int) tea.Cmd {
	return func() tea.Msg {
		b, err := exec.Command(tmuxBin, "capture-pane", "-p", "-e", "-t", paneID,
			"-S", fmt.Sprintf("-%d", lines)).Output()
		if err != nil {
			return PanePreviewMsg("")
		}
		return PanePreviewMsg(strings.TrimRight(string(b), "\n"))
	}
}
