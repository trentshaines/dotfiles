#!/usr/bin/env python3
"""Regression tests: python3 ~/.config/tmux/test-assistant-state.py."""
import importlib.util
import json
from pathlib import Path
import tempfile
import os
import shlex
import shutil
import time
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

    def test_pending_restore_does_not_block_new_saves(self):
        with tempfile.TemporaryDirectory() as temp:
            d = Path(temp)
            s.atomic_json(d / 'assistant-restore-pending.json', {'sessions': [{'pane': 'old:1.1', 'session_id': B}]})
            entry = dict(pane='new:1.1', session_id=A)
            with patch.object(s, 'collect_codex', return_value=[entry]), patch.object(s, 'processes', return_value={}), patch.object(s, 'session_exists', return_value=True), patch.object(s, 'tmux', return_value='123'):
                self.assertEqual(s.save_entries(d, {}), [entry])

    def test_empty_unpersisted_tui_is_not_saved(self):
        with tempfile.TemporaryDirectory() as temp:
            entries = [dict(pane='empty:1.1', session_id=A), dict(pane='real:1.1', session_id=B)]
            with patch.object(s, 'collect_codex', return_value=entries), patch.object(s, 'processes', return_value={}), patch.object(s, 'session_exists', side_effect=lambda sid: sid == B):
                self.assertEqual(s.save_entries(Path(temp), {}), [entries[1]])

    def test_unresolved_pane_does_not_hide_other_sessions(self):
        panes = {name: dict(pane=name, pid=pid, cwd='/same', title=name) for name, pid in [('one:1.1', 100), ('one:1.2', 200)]}
        procs = {100: (0, 'codex'), 200: (0, 'codex')}
        errors = []
        with patch.object(s, 'open_sessions', return_value={200: B}):
            self.assertEqual([e['session_id'] for e in s.collect_codex(panes, procs, errors)], [B])
        self.assertEqual(len(errors), 1)

    def test_resume_flags_do_not_accumulate(self):
        self.assertEqual(s.resume_options(['--search', '-c', 'check_for_update_on_startup=false', '-c', 'check_for_update_on_startup=false', 'resume', A]), ['--search'])

    def test_layout_recovers_fresh_session_without_sidecar(self):
        with tempfile.TemporaryDirectory() as temp:
            d = Path(temp)
            layout = d / 'tmux_resurrect_test.txt'
            layout.write_text('pane\tone\t1\t1\t:*\t1\ttitle\t:/same\t1\tnode\t:node /bin/codex --search\n')
            entry = dict(pane='one:1.1', cwd='/same', session_id=A, argv=['--search'])
            with patch.object(s, 'save_entries', return_value=[entry]), patch.object(s, 'panes', return_value={}):
                s.bind_layout(d, layout)
            (d / 'last').symlink_to(layout.name)
            state = s.load_state(d)
            self.assertEqual(state['sessions'][0]['session_id'], A)
            self.assertEqual(state['sessions'][0]['pane'], 'one:1.1')
            self.assertEqual(state['sessions'][0]['argv'], ['--search'])

    def test_failed_restore_is_retained_for_same_pane_only(self):
        with tempfile.TemporaryDirectory() as temp:
            d = Path(temp)
            entry = dict(pane='one:1.1', pane_id='%5', cwd='/same', session_id=A)
            s.atomic_json(d / 'assistant-restore-pending.json', dict(server_pid='123', sessions=[entry]))
            with patch.object(s, 'collect_codex', return_value=[]), patch.object(s, 'processes', return_value={}), patch.object(s, 'session_exists', return_value=True), patch.object(s, 'tmux', return_value='123'):
                self.assertEqual(s.save_entries(d, {'one:1.1': dict(pane_id='%5', cwd='/same')}), [entry])
                self.assertEqual(s.save_entries(d, {'one:1.1': dict(pane_id='%6', cwd='/same')}), [])
    @unittest.skipUnless(shutil.which('tmux') and shutil.which('lsof') and shutil.which('cc'), 'requires tmux, lsof and a C compiler')
    def test_real_tmux_restart_restores_two_fresh_sessions_in_same_cwd(self):
        # Dedicated server and fake Codex processes: no user panes or API calls.
        with tempfile.TemporaryDirectory(prefix='tmux-restore-test-') as temp:
            d = Path(temp)
            socket = str(d / 'socket')
            binary = d / 'codex'
            (d / 'thread-writer-locks').mkdir()
            source = d / 'fake.c'
            source.write_text('#include <stdio.h>\n#include <unistd.h>\nint main(int argc, char **argv) { char p[4096]; snprintf(p,sizeof(p),"%s/thread-writer-locks/%s.lock",' + json.dumps(temp) + ',argv[argc-1]); FILE *f=fopen(p,"w"); if(!f) return 1; sleep(120); fclose(f); }\n')
            s.run('cc', str(source), '-o', str(binary))
            def tmux(*args):
                return s.run('tmux', '-S', socket, *args)
            shell = 'env PATH=' + shlex.quote(str(d) + ':' + os.environ['PATH']) + ' /bin/bash --noprofile --norc'
            def start():
                tmux('-f', '/dev/null', 'new-session', '-d', '-s', 'fixture', '-c', temp, shell)
                tmux('split-window', '-t', 'fixture:0', '-c', temp, shell)
                deadline = time.monotonic() + 5
                while time.monotonic() < deadline:
                    if all('bash-3.2$' in tmux('capture-pane', '-p', '-t', target) or 'bash-' in tmux('capture-pane', '-p', '-t', target) for target in ('fixture:0.0', 'fixture:0.1')):
                        return
                    time.sleep(0.1)
                raise RuntimeError('fixture shell did not initialize')
            try:
                start()
                with patch.object(s, 'tmux', side_effect=tmux), patch.object(s, 'session_exists', return_value=True):
                    original = s.panes()
                    expected = dict(zip(sorted(original), (A, B)))
                    for target, sid in expected.items():
                        tmux('send-keys', '-t', original[target]['pane_id'], 'codex resume ' + sid, 'Enter')
                    deadline = time.monotonic() + 10
                    while time.monotonic() < deadline:
                        try:
                            entries = s.collect_codex(s.panes(), s.processes())
                            if len(entries) == 2:
                                break
                        except RuntimeError:
                            pass
                        time.sleep(0.1)
                    self.assertEqual({e['pane']: e['session_id'] for e in entries}, expected)
                    layout = d / 'tmux_resurrect_fixture.txt'
                    lines = []
                    for target in sorted(original):
                        session, loc = target.split(':')
                        window, pane = loc.split('.')
                        # Fresh launches contain no resume ID in the raw saved command.
                        lines.append('\t'.join(['pane', session, window, '1', ':*', pane, 'title', ':'+original[target]['cwd'], '1', 'codex', ':codex']))
                    layout.write_text('\n'.join(lines)+'\n')
                    s.bind_layout(d, layout)
                    (d / 'last').symlink_to(layout.name)
                    tmux('kill-server')
                    time.sleep(0.2)
                    start()
                    s.restore(d, s.load_state(d))
                    actual = {e['pane']: e['session_id'] for e in s.collect_codex(s.panes(), s.processes())}
                    self.assertEqual(actual, expected)
            finally:
                s.run('tmux', '-S', socket, 'kill-server', check=False)


if __name__ == '__main__':
    unittest.main()
