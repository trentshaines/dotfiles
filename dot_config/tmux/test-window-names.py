#!/usr/bin/env python3
"""Use a disposable tmux server; never restart or rename user windows."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parent

class WindowNamesTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="window-names-test-")
        self.d = Path(self.temp.name)
        self.socket = str(self.d / "socket")
        self.binary = shutil.which("tmux")
        wrapper = self.d / "tmux"
        wrapper.write_text("#!/bin/sh\nexec " + self.binary + ' -S "' + self.socket + '" "$@"\n')
        wrapper.chmod(0o755)
        self.env = dict(os.environ, PATH=str(self.d) + ":" + os.environ['PATH'],
                        TMUX_RESURRECT_DIR=str(self.d))
        self.env.pop("TMUX", None)
        self.call('tmux', '-f', '/dev/null', 'new-session', '-d', '-s', 'fixture', '-n', 'original', '/bin/sh')
        self.call('tmux', 'set-option', '-g', 'default-shell', '/bin/sh')
        self.call('tmux', 'source-file', str(ROOT / 'window-names.conf'))
        self.window = self.call('tmux', 'display-message', '-p', '-t', 'fixture:0', '#{window_id}')

    def tearDown(self):
        self.call('tmux', 'kill-server')
        self.temp.cleanup()

    def call(self, *args):
        return subprocess.check_output(args, env=self.env, text=True).rstrip('\n')

    def option(self, name):
        return self.call('tmux', 'show-options', '-wqv', '-t', self.window, name)

    def name(self):
        return self.call('tmux', 'display-message', '-p', '-t', self.window, '#{window_name}')

    def assert_name_eventually(self, expected):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if self.name() == expected:
                return
            time.sleep(.05)
        self.assertEqual(self.name(), expected)

    def pin(self, name):
        self.call('tmux', 'set-option', '-w', '-t', self.window, '@manual-window-name', name)
        self.call('tmux', 'rename-window', '-t', self.window, name)

    def test_assistant_rename_cannot_replace_pin_and_unpin_allows_it(self):
        intended = "My work; $(literal) 'quotes'"
        self.pin(intended)
        self.call('tmux', 'rename-window', '-t', self.window, 'assistant prompt')
        self.assert_name_eventually(intended)
        self.call('tmux', 'set-option', '-wu', '-t', self.window, '@manual-window-name')
        self.call('tmux', 'rename-window', '-t', self.window, 'new automatic name')
        self.assert_name_eventually('new automatic name')

    def test_metadata_survives_real_server_restart(self):
        self.pin('intentional name')
        self.call('bash', str(ROOT / 'resurrect-names.sh'), 'save')
        saved = json.loads((self.d / 'names.json').read_text())
        self.assertEqual(saved['windows'][0]['manualName'], 'intentional name')
        self.call('tmux', 'kill-server')
        time.sleep(.15)
        self.call('tmux', '-f', '/dev/null', 'new-session', '-d', '-s', 'fixture', '-n', 'startup name', '/bin/sh')
        self.window = self.call('tmux', 'display-message', '-p', '-t', 'fixture:0', '#{window_id}')
        self.call('bash', str(ROOT / 'resurrect-names.sh'), 'restore', str(self.d / 'names.json'))
        self.assertEqual(self.option('@manual-window-name'), 'intentional name')
        self.call('tmux', 'rename-window', '-t', self.window, 'resumed assistant')
        self.assert_name_eventually('intentional name')
        self.assertEqual(self.option('automatic-rename'), 'off')

    def test_legacy_snapshot_without_lock_restores_name(self):
        self.call('bash', str(ROOT / 'resurrect-names.sh'), 'save')
        path = self.d / 'names.json'
        state = json.loads(path.read_text())
        del state['windows'][0]['manualName']
        path.write_text(json.dumps(state))
        self.pin('temporary lock')
        self.call('bash', str(ROOT / 'resurrect-names.sh'), 'restore', str(path))
        self.assertEqual(self.option('@manual-window-name'), '')
        self.assertEqual(self.name(), 'original')

    def test_guard_targets_renamed_window_not_selected_window(self):
        self.pin('pinned first window')
        self.call('tmux', 'new-window', '-t', 'fixture', '-n', 'second', '/bin/sh')
        self.call('tmux', 'rename-window', '-t', self.window, 'wrong name')
        self.assert_name_eventually('pinned first window')
        self.assertEqual(self.call('tmux', 'display-message', '-p', '-t', 'fixture:1', '#{window_name}'), 'second')

if __name__ == '__main__':
    unittest.main()
