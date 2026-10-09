function ox3 --description "ssh ox3, auto-reconnecting into the cyber tmux session on drop"
    set -l delay 1

    while true
        set -l t0 (date +%s)
        ssh $argv ox3
        set -l code $status
        set -l elapsed (math (date +%s) - $t0)

        # Clean exit: typed `exit`, or detached from tmux. Done.
        test $code -eq 0; and return 0
        # Ctrl-C — don't fight the user.
        test $code -eq 130; and return 130

        # A session that actually ran is a fresh start for the backoff.
        test $elapsed -gt 30; and set delay 1

        echo (set_color yellow)"[ox3] dropped (exit $code) — reconnecting in "$delay"s, Ctrl-C to stop"(set_color normal)
        sleep $delay; or return 130
        set delay (math "min(30, $delay * 2)")
    end
end
