function codr --description 'Resume the Codex session that just exited in this tmux pane'
    set -l resume_args
    if set -q argv[1]
        set resume_args $argv
    else if set -q TMUX
        set -l resume_id (tmux capture-pane -p -J -S -1000 2>/dev/null | python3 -c '
import re
import sys

lines = sys.stdin.read().splitlines()
resume_command = re.compile(r"\bcodex resume ([0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12})\b")
exit_message = re.compile(r"To (?:continue|resume) this session, run", re.I)
resume_ids = []
for i, line in enumerate(lines):
    if exit_message.search(line):
        for next_line in lines[i:i + 10]:
            match = resume_command.search(next_line)
            if match:
                resume_ids.append(match.group(1))
                break
if resume_ids:
    print(resume_ids[-1])
' 2>/dev/null)

        if test -n "$resume_id"
            set resume_args $resume_id
        end
    end

    if not set -q resume_args[1]
        echo 'No Codex exit command found in this tmux pane; opening the session picker.' >&2
    end

    if not cod update
        echo 'Codex update failed; session was not resumed.' >&2
        return 1
    end

    cod resume $resume_args
end
