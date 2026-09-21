#!/usr/bin/env python3
"""Regression tests: python3 ~/.config/tmux/test-assistant-state.py."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('state', Path(__file__).with_name('assistant-state.py'))
s = importlib.util.module_from_spec(spec)
spec.loader.exec_module(s)
A = '11111111-1111-7111-8111-111111111111'
B = '22222222-2222-7222-8222-222222222222'


class StateTests(unittest.TestCase):
    def test_no_replayed_resume_or_prompt(self):
        self.assertEqual(s.resume_options(['--no-alt-screen', 'resume', A, 'resume', A, 'delete files']), ['--no-alt-screen'])
        self.assertEqual(s.resume_options(['a prompt', '--search']), [])

    def test_node_wrapper_and_services(self):
        self.assertEqual(s.codex_args('node /some/path/codex --search'), ['--search'])
        for command in ['codex app-server', 'codex exec hello', 'bash -c "codex resume blah"', 'codex-code-mode-host']:
            self.assertIsNone(s.codex_args(command))

    def test_wrapped_process_tree_does_not_depend_on_pid_order(self):
        procs = {1: (100, 'codex'), 100: (999, 'node'), 999: (0, 'fish')}
        self.assertEqual(list(s.descendants(999, procs)), [999, 100, 1])

    def test_same_cwd_uses_actual_process_identity(self):
        panes = {name: dict(pane=name, pid=pid, cwd='/same', title=name) for name, pid in [('one:1.1', 100), ('one:1.2', 200)]}
        procs = {100: (0, 'fish'), 101: (100, 'codex'), 200: (0, 'fish'), 201: (200, 'codex')}
        with patch.object(s, 'open_sessions', return_value={101: B, 201: A}):
            self.assertEqual({e['pane']: e['session_id'] for e in s.collect_codex(panes, procs)}, {'one:1.1': B, 'one:1.2': A})

    def test_unresolved_live_process_never_guesses(self):
        with patch.object(s, 'open_sessions', return_value={}):
            with self.assertRaises(RuntimeError):
                s.collect_codex({'one:1.1': dict(pid=101, cwd='/same')}, {101: (0, 'codex')})

    def test_lock_preferred_over_old_rollout(self):
        output = f'p101\nn/home/.codex/thread-writer-locks/{B}.lock\nn/home/.codex/sessions/rollout-old-{A}.jsonl'
        with patch.object(s, 'run', return_value=output):
            self.assertEqual(s.open_sessions([101]), {101: B})

    def test_ambiguous_lock_fails_closed(self):
        output = f'p101\nn/h/thread-writer-locks/{A}.lock\nn/h/thread-writer-locks/{B}.lock'
        with patch.object(s, 'run', return_value=output):
            self.assertEqual(s.open_sessions([101]), {})

    def test_selected_layout_wins_over_unrelated_sidecar(self):
        with tempfile.TemporaryDirectory() as temp:
            d = Path(temp)
            layout = d / 'tmux_resurrect_test.txt'
            layout.write_text('')
            (d / 'last').symlink_to(layout.name)
            s.atomic_json(d / 'assistant-sessions.json', {'sessions': [{'session_id': B}]})
            self.assertEqual(s.load_state(d)['sessions'], [])
            s.atomic_json(Path(str(layout) + '.assistants.json'), {'layout': layout.name, 'sessions': [{'session_id': A}]})
            self.assertEqual(s.load_state(d)['sessions'][0]['session_id'], A)

    def test_occupied_pane_receives_no_keys(self):
        with tempfile.TemporaryDirectory() as temp:
            with patch.object(s, 'panes', return_value={'one:1.1': dict(pid=101, command='node')}), patch.object(s, 'processes', return_value={101: (0, 'codex')}), patch.object(s, 'tmux') as tmux:
                s.restore(Path(temp), {'sessions': [dict(tool='codex', session_id=A, pane='one:1.1')]})
                tmux.assert_not_called()

    def test_pending_restore_prevents_metadata_loss(self):
        with tempfile.TemporaryDirectory() as temp:
            d = Path(temp)
            (d / 'assistant-restore-pending.json').write_text('{}')
            with self.assertRaises(RuntimeError):
                s.save(d)


if __name__ == '__main__':
    unittest.main()
