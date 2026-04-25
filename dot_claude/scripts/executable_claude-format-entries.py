#!/usr/bin/env python3
import sys, subprocess, unicodedata

queue_file, now, cols = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
usable = cols - 6  # fzf rounded border (4) + padding (2)

def dw(s):
    return sum(2 if unicodedata.east_asian_width(c) in 'WF' else 1 for c in s)

def trunc(s, max_w):
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
    s = trunc(s, width)
    return s + ' ' * (width - dw(s))

rows = []
try:
    lines = open(queue_file).readlines()
except Exception:
    sys.exit(0)

for line in sorted(lines, key=lambda l: -(int(l.split('\t')[0]) if l.split('\t')[0].isdigit() else 0)):
    parts = line.rstrip('\n').split('\t')
    if len(parts) < 8:
        continue
    ts, target, client, project, session, window_name, pane_index, visited = \
        parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6], parts[7]
    if visited != '0' or not ts.isdigit() or not target:
        continue
    try:
        pane_title = subprocess.check_output(
            ['/opt/homebrew/bin/tmux', 'display-message', '-t', target, '-p', '#{pane_title}'],
            stderr=subprocess.DEVNULL, timeout=1
        ).decode().strip()
        for prefix in ('✓ ', '✳ '):
            if pane_title.startswith(prefix):
                pane_title = pane_title[len(prefix):]
                break
    except Exception:
        pane_title = ''

    ago = (now - int(ts)) // 60
    if   ago < 1:  finished = 'just now'
    elif ago < 60: finished = f'{ago}m ago'
    else:          finished = f'{ago // 60}h ago'

    rows.append((ts, target, client,
                 f'{session} → {window_name} (pane {pane_index})',
                 pane_title, finished, project))

if not rows:
    sys.exit(0)

SEP    = ' │ '
sep_w  = dw(SEP)
time_w = 9
loc_w  = min(30, max(dw(r[3]) for r in rows))
proj_w = min(22, max(dw(r[6]) for r in rows))
title_w = max(10, usable - loc_w - sep_w * 3 - time_w - proj_w)

for ts, target, client, loc, title, finished, project in rows:
    line = (pad(loc, loc_w) + SEP +
            pad(title, title_w) + SEP +
            pad(finished, time_w) + SEP +
            trunc(project, proj_w))
    print(f'{ts}\t{target}\t{client}\t{line}')
