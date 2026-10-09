#!/usr/bin/env python3
"""Guard explicitly named tmux windows against automatic naming clients."""
import os
from pathlib import Path
import subprocess
import sys


def tmux(*args):
    return subprocess.check_output(['tmux', *args], text=True).rstrip('\n')


def main():
    action, target = sys.argv[1:3]
    if not target.startswith(('@', '%')):
        raise ValueError('expected a tmux window or pane ID')
    pinned = tmux('show-options', '-wqv', '-t', target, '@manual-window-name')
    if pinned:
        current = tmux('display-message', '-p', '-t', target, '#{window_name}')
        if current != pinned:
            tmux('rename-window', '-t', target, pinned)
        return
    if action == 'enforce':
        return
    if action != 'branch':
        raise ValueError('unknown action')
    cwd = tmux('display-message', '-p', '-t', target, '#{pane_current_path}')
    env = dict(os.environ, TMUX_PANE=target)
    function = Path(__file__).parent.parent / 'fish/functions/__update_tmux_window_name.fish'
    subprocess.run(['fish', '--no-config', '-c', 'source $argv[1]; __update_tmux_window_name',
                    '--', str(function)], cwd=cwd, env=env, check=True)


if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError:
        # A window may close while its queued naming hook runs.
        pass
