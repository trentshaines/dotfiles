#!/bin/bash
# Formats pending Claude notifications for fzf display.
# Delegates to Python for correct Unicode display-width handling.

QUEUE_FILE="/tmp/claude-notifications.queue"
[[ ! -f "$QUEUE_FILE" ]] && exit 0

# stty reads from /dev/tty directly — works even in subshells/pipelines
# tmux pane_width is the most reliable source inside a popup
cols=$(tmux display-message -p '#{pane_width}' 2>/dev/null)
[[ -z "$cols" ]] && cols=$({ stty size </dev/tty; } 2>/dev/null | awk '{print $2}')
[[ -z "$cols" ]] && cols=${COLUMNS:-80}

python3 - "$QUEUE_FILE" "$(date +%s)" "$cols" <<'PYEOF'
import sys, subprocess, unicodedata, os

queue_file, now, cols = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
usable = cols - 6  # fzf rounded border (4) + internal padding (2)

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

# Column widths — hard caps first, then fit to available space
SEP = ' │ '
sep_w = dw(SEP)
time_w  = 9   # "just now" = 8, "59m ago" = 6
loc_cap = 30
title_cap = 36
proj_cap  = 20

# Natural widths from content (don't pad wider than needed)
nat_loc   = min(loc_cap,   max(dw(r[3]) for r in rows))
nat_title = min(title_cap, max(dw(r[4]) for r in rows) if any(r[4] for r in rows) else 0)
nat_proj  = min(proj_cap,  max(dw(r[6]) for r in rows))

# Total fixed layout cost
fixed = nat_loc + sep_w + nat_title + sep_w + time_w + 2 + nat_proj
# If it doesn't fit, shrink title first then loc
if fixed > usable:
    overage = fixed - usable
    reduction = min(overage, nat_title - 10)
    nat_title -= reduction
    overage -= reduction
    if overage > 0:
        nat_loc = max(10, nat_loc - overage)

loc_w, title_w, proj_w = nat_loc, nat_title, nat_proj

for ts, target, client, loc, title, finished, project in rows:
    left = pad(loc, loc_w) + SEP + pad(title, title_w) + SEP + pad(finished, time_w)
    proj = trunc(project, proj_w)
    gap = max(2, usable - dw(left) - dw(proj))
    print(f'{ts}\t{target}\t{client}\t{left}{" " * gap}{proj}')

PYEOF
