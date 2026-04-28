#!/usr/bin/env python3
# Formats TABLE tsv (loc\ttask\ttime\tproject) into aligned lines for gum filter.
import sys, unicodedata

table_file, cols = sys.argv[1], int(sys.argv[2])
usable = cols - 2

def dw(s):
    return sum(2 if unicodedata.east_asian_width(c) in 'WF' else 1 for c in s)

def trunc(s, w):
    if dw(s) <= w: return s
    out, total = '', 0
    for c in s:
        cw = 2 if unicodedata.east_asian_width(c) in 'WF' else 1
        if total + cw > w - 1: return out + '…'
        out += c; total += cw
    return out

def pad(s, w):
    s = trunc(s, w)
    return s + ' ' * (w - dw(s))

rows = [l.rstrip('\n').split('\t') for l in open(table_file) if l.strip()]
rows = [r for r in rows if len(r) >= 4]
if not rows: sys.exit(0)

SEP = '  '
time_w = 9
proj_w = min(20, max(dw(r[3]) for r in rows))
loc_w  = min(32, max(dw(r[0]) for r in rows))
title_w = max(10, usable - loc_w - time_w - proj_w - len(SEP) * 3)

for loc, task, time, proj, *_ in rows:
    print(pad(loc, loc_w) + SEP + pad(task, title_w) + SEP + pad(time, time_w) + SEP + trunc(proj, proj_w))
