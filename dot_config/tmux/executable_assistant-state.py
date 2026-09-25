#!/usr/bin/env python3
"""Snapshot-bound Codex restore. Other assistants retain the TPM plugin adapter."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import time

HOME = Path.home()
UUID = r'[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}'
SHELLS = {'fish', 'bash', 'zsh', 'sh', 'dash', 'ksh'}
PLUGIN = HOME / '.tmux/plugins/tmux-assistant-resurrect/scripts'
NAMES = Path(__file__).with_name('resurrect-names.sh')
LAUNCHER = Path(__file__).with_name('codex-launch.sh')
# Hooks run before interactive shell initialization, including at login.
os.environ['PATH'] = os.pathsep.join([str(HOME / '.local/bin'), '/opt/homebrew/bin',
                                     '/usr/local/bin', os.environ.get('PATH', ''),
                                     '/usr/bin', '/bin', '/usr/sbin', '/sbin'])


def run(*args, check=True):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, check=check).stdout.strip()


def tmux(*args):
    return run('tmux', *args)


def data_dir():
    value = os.environ.get('TMUX_RESURRECT_DIR') or tmux('show-option', '-gqv', '@resurrect-dir')
    if value:
        return Path(os.path.expandvars(os.path.expanduser(value)))
    legacy = HOME / '.tmux/resurrect'
    return legacy if legacy.exists() else Path(os.environ.get('XDG_DATA_HOME', HOME / '.local/share')) / 'tmux/resurrect'


def log(directory, message):
    line = time.strftime('[%Y-%m-%dT%H:%M:%SZ] ', time.gmtime()) + message
    print(line, file=sys.stderr)
    with (directory / 'assistant-state.log').open('a') as f:
        f.write(line + '\n')


def atomic_json(path, value):
    fd, temp = tempfile.mkstemp(prefix='.' + path.name, dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as f:
            json.dump(value, f, indent=2)
            f.write('\n')
            f.flush()
            os.fsync(f.fileno())
        os.replace(temp, path)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)


def processes():
    result = {}
    for line in run('ps', '-ww', '-axo', 'pid=,ppid=,args=').splitlines():
        fields = line.strip().split(None, 2)
        if len(fields) == 3:
            result[int(fields[0])] = (int(fields[1]), fields[2])
    return result


def descendants(root, procs):
    queue, seen = [root], set()
    while queue:
        pid = queue.pop(0)
        if pid in seen:
            continue
        seen.add(pid)
        yield pid
        queue.extend(p for p, (parent, _) in procs.items() if parent == pid)


def codex_args(command):
    try:
        words = shlex.split(command)
    except ValueError:
        return None
    if not words:
        return None
    if Path(words[0]).name in ('node', 'bun'):
        words = words[1:]
    if words and Path(words[0]).name in ('codex', 'codex.js'):
        # Never treat a service, exec worker, or helper as an interactive TUI.
        if any(w in ('app-server', 'exec', 'mcp-server', 'debug') for w in words[1:]):
            return None
        return words[1:]
    return None


def resume_options(words):
    """Retain launch options only. No picker, resume ID, or old prompt replay."""
    boolean = {'--dangerously-bypass-approvals-and-sandbox', '--no-alt-screen',
               '--search', '--oss', '--approve-for-me'}
    valued = {'-m', '--model', '-p', '--profile', '-s', '--sandbox', '-a',
              '--ask-for-approval', '--add-dir', '--enable', '--disable',
              '--local-provider', '-c', '--config'}
    result = []
    i = 0
    while i < len(words):
        word = words[i]
        if word in boolean:
            if word not in result:
                result.append(word)
        elif word in valued and i + 1 < len(words):
            if not (word in ('-c', '--config') and words[i + 1].startswith('check_for_update_on_startup=')):
                result.extend(words[i:i + 2])
            i += 1
        elif word.split('=', 1)[0] in valued and '=' in word:
            if not word.startswith('--config=check_for_update_on_startup='):
                result.append(word)
        elif word in ('resume', 'fork'):
            # Stop at the session positional: everything beyond it may be a prompt.
            # Global options ahead of the subcommand cover the normal launch path.
            break
        elif not word.startswith('-'):
            break
        i += 1
    return result


def panes():
    result = {}
    fmt = '#{session_name}:#{window_index}.#{pane_index}|#{pane_id}|#{pane_pid}|#{pane_current_command}|#{pane_current_path}|#{pane_title}'
    for line in tmux('list-panes', '-a', '-F', fmt).splitlines():
        target, pane, pid, command, cwd, title = line.split('|', 5)
        result[target] = dict(pane=target, pane_id=pane, pid=int(pid), command=command,
                              cwd=cwd, title=title)
    return result


def open_sessions(pids):
    """Exact PID→thread mapping; never rank conversations by directory/mtime."""
    if not pids:
        return {}
    output = run('lsof', '-nP', '-p', ','.join(map(str, pids)), '-Fn', check=False)
    locks, rollouts = {}, {}
    pid = None
    for line in output.splitlines():
        if line.startswith('p') and line[1:].isdigit():
            pid = int(line[1:])
        elif line.startswith('n') and pid is not None:
            name = line[1:]
            match = re.search(r'/thread-writer-locks/(' + UUID + r')\.lock$', name)
            if match:
                locks.setdefault(pid, set()).add(match[1])
            match = re.search(r'/rollout-.*-(' + UUID + r')\.jsonl$', name)
            if match:
                rollouts.setdefault(pid, set()).add(match[1])
    result = {}
    for pid in pids:
        ids = locks.get(pid) or rollouts.get(pid, set())
        if len(ids) == 1:
            result[pid] = next(iter(ids))
    return result


def collect_codex(current, procs, errors=None):
    candidates = {}
    for target, pane in current.items():
        candidates[target] = [(pid, codex_args(procs[pid][1]))
                              for pid in descendants(pane['pid'], procs)
                              if pid in procs and codex_args(procs[pid][1]) is not None]
    exact = open_sessions([pid for group in candidates.values() for pid, _ in group])
    entries = []
    for target, group in candidates.items():
        if not group:
            continue
        matches = {exact[pid] for pid, _ in group if pid in exact}
        if len(matches) != 1:
            message = f'{target}: cannot establish one exact live Codex session'
            if errors is None:
                raise RuntimeError(message)
            errors.append(message)
            continue
        sid = matches.pop()
        pid, options = next((pid, words) for pid, words in reversed(group) if exact.get(pid) == sid)
        entry = {k: current[target][k] for k in ('pane', 'cwd', 'title')}
        entry.update(tool='codex', session_id=sid, pid=pid, argv=resume_options(options))
        entries.append(entry)
    return entries


def plugin_save():
    script = PLUGIN / 'save-assistant-sessions.sh'
    if not script.exists():
        return []
    with tempfile.TemporaryDirectory(prefix='tmux-assistants-') as temp:
        env = dict(os.environ, TMUX_RESURRECT_DIR=temp)
        subprocess.run(['bash', str(script)], env=env, check=True, capture_output=True)
        return [e for e in json.loads((Path(temp) / 'assistant-sessions.json').read_text())['sessions']
                if e['tool'] != 'codex']


def session_exists(sid):
    """A TUI can own a UUID before Codex persists any resumable conversation."""
    codex_home = Path(os.environ.get('CODEX_HOME', HOME / '.codex'))
    for db in sorted(codex_home.glob('state_*.sqlite'), key=lambda p: p.stat().st_mtime, reverse=True):
        with sqlite3.connect(f'file:{db}?mode=ro', uri=True) as connection:
            if connection.execute('SELECT 1 FROM threads WHERE id=?', (sid,)).fetchone():
                return True
    return False


def save_entries(directory, current):
    errors = []
    entries = collect_codex(current, processes(), errors)
    persisted = []
    for entry in entries:
        if session_exists(entry['session_id']):
            persisted.append(entry)
        else:
            errors.append(f"{entry['pane']}: session has not been persisted; skipping empty TUI")
    # Retain failed restores independently. One failure must never stop new saves.
    pending = directory / 'assistant-restore-pending.json'
    if pending.exists():
        state = json.loads(pending.read_text())
        server = tmux('display-message', '-p', '#{pid}')
        occupied = {e['pane'] for e in persisted}
        for entry in state.get('sessions', []):
            pane = current.get(entry['pane'])
            if (entry['pane'] not in occupied and pane
                    and state.get('server_pid') == server
                    and entry.get('pane_id') == pane['pane_id']
                    and pane['cwd'] == entry['cwd']
                    and session_exists(entry['session_id'])):
                persisted.append(entry)
    for error in errors:
        log(directory, error)
    return persisted


def bind_layout(directory, layout):
    """Write exact IDs INTO the layout before resurrect publishes its last link.

    This survives sidecar failure or interruption of the slower post-save hook.
    """
    entries = {e['pane']: e for e in save_entries(directory, panes())}
    lines = []
    bound = 0
    discarded = 0
    for line in layout.read_text().splitlines():
        fields = line.split('\t')
        if fields[0] == 'pane' and len(fields) >= 11:
            target = f'{fields[1]}:{fields[2]}.{fields[5]}'
            entry = entries.get(target)
            if entry and fields[7].lstrip(':') == entry['cwd']:
                fields[10] = ':' + shlex.join(['codex', *entry['argv'], 'resume', entry['session_id']])
                bound += 1
            elif codex_args(fields[10].lstrip(':')) is not None:
                # Resurrect's ps strategy matches PID prefixes (2994 also matches
                # 29941). Never retain a raw Codex command without exact ownership.
                fields[10] = ':'
                discarded += 1
        lines.append('\t'.join(fields))
    temporary = layout.with_suffix('.binding.tmp')
    temporary.write_text('\n'.join(lines) + '\n')
    os.replace(temporary, layout)
    log(directory, f'embedded {bound} exact Codex IDs in {layout.name}')
    if discarded:
        log(directory, f'discarded {discarded} unverified raw Codex commands from layout')


def save(directory):
    layout = (directory / 'last').resolve(strict=True)
    current = panes()
    entries = save_entries(directory, current)
    try:
        entries += plugin_save()
    except Exception as exc:
        log(directory, f'non-Codex adapter failed; saving Codex sessions anyway: {exc}')
    targets = {e['pane'] for e in entries}
    if len(targets) != len(entries):
        raise RuntimeError('duplicate pane mapping; preserving previous snapshot')
    state = dict(version=1, layout=layout.name, timestamp=time.time(), sessions=entries)
    # Historical files are never overwritten; the layout sidecar points to its latest save.
    history = directory / 'assistant-history'
    history.mkdir(exist_ok=True)
    atomic_json(history / f'{time.time_ns()}.json', state)
    atomic_json(Path(str(layout) + '.assistants.json'), state)
    atomic_json(directory / 'assistant-sessions.json', state)
    subprocess.run(['bash', str(NAMES), 'save'], check=True)
    if (directory / 'names.json').exists():
        shutil.copy2(directory / 'names.json', str(layout) + '.names.json')
    log(directory, f'saved {len(entries)} exact sessions for {layout.name}')
    # Keep a month of recovery metadata, always retaining the latest 100 files.
    backups = sorted(history.glob('*.json'), reverse=True)
    for path in backups[100:]:
        if path.stat().st_mtime < time.time() - 30 * 86400:
            path.unlink()


def load_state(directory):
    layout = (directory / 'last').resolve(strict=True)
    sidecar = Path(str(layout) + '.assistants.json')
    if sidecar.exists():
        state = json.loads(sidecar.read_text())
        if state.get('layout') != layout.name:
            raise RuntimeError('assistant snapshot does not match layout')
        return state
    # Old installations may have an overwritten sidecar. Recover only explicit IDs
    # in this exact layout; unrelated recent sessions are never substituted.
    entries = []
    for line in layout.read_text().splitlines():
        fields = line.split('\t')
        if fields[0] != 'pane' or len(fields) < 11:
            continue
        words = codex_args(fields[10].lstrip(':'))
        match = re.search(r'\bresume\s+(' + UUID + r')\b', fields[10])
        if words is not None and match:
            entries.append(dict(pane=f'{fields[1]}:{fields[2]}.{fields[5]}', tool='codex',
                                session_id=match[1], cwd=fields[7].lstrip(':'),
                                title=fields[6], argv=resume_options(words)))
    return dict(sessions=entries)


class RestoreIncomplete(RuntimeError):
    def __init__(self, entries):
        self.entries = entries
        super().__init__('restore incomplete for: ' + ', '.join(e['pane'] for e in entries))


def restore(directory, state, dry_run=False):
    seen = set()
    failed = []
    for entry in state['sessions']:
        if entry['tool'] != 'codex':
            continue
        sid, target = entry['session_id'], entry['pane']
        if not re.fullmatch(UUID, sid) or target in seen:
            raise RuntimeError('invalid or duplicate restore record')
        seen.add(target)
        current = panes()
        if target not in current:
            log(directory, f'skip missing pane {target}')
            continue
        pane = current[target]
        procs = processes()
        tree = list(descendants(pane['pid'], procs))
        # Both foreground and process-tree guards. Never type into a live assistant.
        if pane['command'].lstrip('-') not in SHELLS or any(
                codex_args(procs[p][1]) is not None for p in tree if p in procs):
            log(directory, f'skip occupied pane {target}')
            continue
        if not Path(entry['cwd']).is_dir():
            log(directory, f'skip missing cwd for {target}: {entry["cwd"]}')
            continue
        options = resume_options(entry.get('argv', shlex.split(entry.get('cli_args', ''))))
        command = 'cd ' + shlex.quote(entry['cwd']) + ' && bash ' + shlex.quote(str(LAUNCHER)) + ' ' + shlex.join(options + ['-c', 'check_for_update_on_startup=false', 'resume', sid])
        if dry_run:
            log(directory, f'would restore {target}: {sid}')
            continue
        tmux('send-keys', '-t', pane['pane_id'], 'C-u')
        tmux('send-keys', '-l', '-t', pane['pane_id'], command)
        tmux('send-keys', '-t', pane['pane_id'], 'Enter')
        # Verify actual session ownership, not merely successful send-keys.
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline:
            procs = processes()
            pids = [p for p in descendants(pane['pid'], procs)
                    if p in procs and codex_args(procs[p][1]) is not None]
            if sid in open_sessions(pids).values():
                if entry.get('title'):
                    tmux('select-pane', '-t', pane['pane_id'], '-T', entry['title'])
                log(directory, f'verified {target}: {sid}')
                break
            time.sleep(0.4)
        else:
            failed.append(target)
            log(directory, f'{target}: resume did not acquire expected session {sid}; inspect pane')
    others = [e for e in state['sessions'] if e['tool'] != 'codex']
    if others and not dry_run:
        with tempfile.TemporaryDirectory(prefix='tmux-assistants-') as temp:
            atomic_json(Path(temp) / 'assistant-sessions.json', dict(sessions=others))
            subprocess.run(['bash', str(PLUGIN / 'restore-assistant-sessions.sh')],
                           env=dict(os.environ, TMUX_RESURRECT_DIR=temp), check=True)
    if failed:
        raise RestoreIncomplete([e for e in state['sessions'] if e['pane'] in failed])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('save', 'restore', 'inspect', 'bind-layout'))
    parser.add_argument('layout', nargs='?', type=Path)
    parser.add_argument('--state', type=Path)
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    directory = data_dir()
    directory.mkdir(parents=True, exist_ok=True)
    with (directory / '.assistant-state.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if args.action == 'bind-layout':
            if args.layout is None:
                raise RuntimeError('bind-layout requires a layout file')
            bind_layout(directory, args.layout)
        elif args.action == 'save':
            save(directory)
        elif args.action == 'inspect':
            print(json.dumps(collect_codex(panes(), processes()), indent=2))
        else:
            state = json.loads(args.state.read_text()) if args.state else load_state(directory)
            pending = directory / 'assistant-restore-pending.json'
            if not args.dry_run:
                current = panes()
                pending_state = dict(state, server_pid=tmux('display-message', '-p', '#{pid}'))
                pending_state['sessions'] = [dict(e, pane_id=current.get(e['pane'], {}).get('pane_id')) for e in state['sessions']]
                atomic_json(pending, pending_state)
            try:
                restore(directory, state, args.dry_run)
            except RestoreIncomplete as exc:
                if not args.dry_run:
                    failed_targets = {e['pane'] for e in exc.entries}
                    pending_state['sessions'] = [e for e in pending_state['sessions'] if e['pane'] in failed_targets]
                    atomic_json(pending, pending_state)
                raise
            if not args.dry_run:
                pending.unlink(missing_ok=True)
            if not args.dry_run and not args.state:
                layout = (directory / 'last').resolve()
                saved_names = Path(str(layout) + '.names.json')
                if saved_names.exists():
                    shutil.copy2(saved_names, directory / 'names.json')
                    subprocess.run(['bash', str(NAMES), 'restore'], check=True)


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print(f'assistant-state: {exc}', file=sys.stderr)
        sys.exit(1)
