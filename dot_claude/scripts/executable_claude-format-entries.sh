#!/bin/bash
# Formats pending Claude notifications for fzf display.
# Delegates to Python for correct Unicode display-width handling.

QUEUE_FILE="/tmp/claude-notifications.queue"
[[ ! -f "$QUEUE_FILE" ]] && exit 0

# stty reads from /dev/tty directly — works even in subshells/pipelines
cols_fallback=$({ stty size </dev/tty; } 2>/dev/null | awk '{print $2}')
[[ -z "$cols_fallback" ]] && cols_fallback=${COLUMNS:-80}

python3 - "$QUEUE_FILE" "$(date +%s)" "$cols_fallback" <<'PYEOF'
import sys, subprocess, unicodedata, os

queue_file, now, cols_fallback = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
# fd 2 (stderr) stays attached to the tty even when stdout is piped (fzf reload)
try:
    cols = os.get_terminal_size(2).columns
except OSError:
    cols = int(os.environ.get('COLUMNS', cols_fallback))
usable = cols - 4  # fzf rounded border: 2 chars each side

def dw(s):
    """Display width of string (handles wide Unicode chars)."""
    return sum(2 if unicodedata.east_asian_width(c) in 'WF' else 1 for c in s)

def trunc(s, max_w):
    """Truncate to max display width, appending … if cut."""
    if dw(s) <= max_w:
        return s
    out, w = '', 0
    for c in s:
        cw = 2 if unicodedata.east_asian_width(c) in 'WF' else 1
        if w + cw > max_w - 1:
            return out + '…'
        out += c; w += cw
    return out

def pad(s, width):
    """Truncate then space-pad to exact display width."""
    s = trunc(s, width)
    return s + ' ' * (width - dw(s))

# Parse queue
rows = []
try:
    lines = open(queue_file).readlines()
except:
    sys.exit(0)

for line in sorted(lines, key=lambda l: -(int(l.split('\t')[0]) if l.split('\t')[0].isdigit() else 0)):
    parts = line.rstrip('\n').split('\t')
    if len(parts) < 8:
        continue
    ts, target, client, project, session, window_name, pane_index, visited = parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6], parts[7]
    if visited != '0':
        continue
    if not ts.isdigit() or not target:
        continue

    try:
        pane_title = subprocess.check_output(
            ['/opt/homebrew/bin/tmux', 'display-message', '-t', target, '-p', '#{pane_title}'],
            stderr=subprocess.DEVNULL, timeout=1
        ).decode().strip()
        # Strip done markers (✓ U+2713, ✳ U+2733)
        for prefix in ('✓ ', '✳ ', '✓ ', '✳ '):
            if pane_title.startswith(prefix):
                pane_title = pane_title[len(prefix):]
                break
    except:
        pane_title = ''

    ago = (now - int(ts)) // 60
    if   ago < 1:  finished = 'just now'
    elif ago < 60: finished = f'{ago}m ago'
    else:          finished = f'{ago // 60}h ago'

    loc = f'{session} → {window_name} (pane {pane_index})'
    rows.append((ts, target, client, loc, pane_title, finished, project))

if not rows:
    sys.exit(0)

# Column widths
SEP = ' │ '
sep_w = dw(SEP)
time_w = 9  # "just now" = 8

max_proj = min(20, max(dw(r[6]) for r in rows))

# remaining space for loc + title
inner = usable - time_w - sep_w * 2 - max_proj - 2
loc_w   = max(15, min(32, inner * 2 // 5))
title_w = max(10, inner - loc_w)

for ts, target, client, loc, title, finished, project in rows:
    left = pad(loc, loc_w) + SEP + pad(title, title_w) + SEP + pad(finished, time_w)
    proj = trunc(project, max_proj)
    gap = max(2, usable - dw(left) - dw(proj))
    print(f'{ts}\t{target}\t{client}\t{left}{" " * gap}{proj}')

PYEOF
