function akey --description "Manage ANTHROPIC_API_KEY profiles in current shell"
    set -l profdir ~/.config/anthropic/profiles
    set -l active_file ~/.config/anthropic/active
    set -l legacy ~/.config/anthropic/key

    # One-time migration: legacy single key → profiles/default
    if test -r $legacy; and not test -d $profdir
        mkdir -p $profdir
        mv $legacy $profdir/default
        chmod 600 $profdir/default
        echo default >$active_file
        chmod 600 $active_file
        echo "akey: migrated legacy key → profiles/default"
    end

    set -l action ""
    test (count $argv) -ge 1; and set action $argv[1]

    switch $action
        case '' pick
            if not test -d $profdir
                echo "akey: no profiles. Run: akey set <name>"
                return 1
            end
            set -l current ""
            test -r $active_file; and set current (cat $active_file)
            set -l choices "(off) — clear ANTHROPIC_API_KEY"
            for f in $profdir/*
                test -e $f; or continue
                set -l n (basename $f)
                if test "$n" = "$current"
                    set choices $choices "$n  *"
                else
                    set choices $choices $n
                end
            end
            set -l choice (printf '%s\n' $choices | fzf --height=40% --reverse --header="select profile  (esc to cancel)" --no-sort)
            test -z "$choice"; and return 1
            if string match -q '(off)*' -- $choice
                akey off
            else
                # Strip trailing "  *" marker if present
                set -l name (string replace -r '  \*$' '' -- $choice)
                akey use $name
            end

        case set
            if test (count $argv) -lt 2
                echo "usage: akey set <name> [<key>]"
                return 1
            end
            set -l name $argv[2]
            set -l key
            if test (count $argv) -ge 3
                set key $argv[3]
            else
                read -s -P "API key for '$name': " key
                echo
            end
            if test -z "$key"
                echo "akey: empty key, aborting"
                return 1
            end
            mkdir -p $profdir
            printf '%s' "$key" >$profdir/$name
            chmod 600 $profdir/$name
            echo "akey: stored profile '$name'"

        case rm
            if test (count $argv) -lt 2
                echo "usage: akey rm <name>"
                return 1
            end
            set -l name $argv[2]
            if not test -e $profdir/$name
                echo "akey: no profile '$name'"
                return 1
            end
            rm -f $profdir/$name
            if test -r $active_file; and test (cat $active_file) = "$name"
                rm -f $active_file
                set --erase --universal ANTHROPIC_API_KEY 2>/dev/null
                set --erase --global ANTHROPIC_API_KEY 2>/dev/null
                echo "akey: removed '$name' (was active — env cleared)"
            else
                echo "akey: removed '$name'"
            end

        case list ls
            if not test -d $profdir
                echo "(no profiles)"
                return 0
            end
            set -l current ""
            test -r $active_file; and set current (cat $active_file)
            for f in $profdir/*
                test -e $f; or continue
                set -l n (basename $f)
                if test "$n" = "$current"
                    echo "* $n"
                else
                    echo "  $n"
                end
            end

        case use on
            set -l name
            if test (count $argv) -ge 2
                set name $argv[2]
            else if test "$action" = on; and test -r $active_file
                set name (cat $active_file)
            else
                echo "usage: akey $action <name>"
                return 1
            end
            if not test -r $profdir/$name
                echo "akey: no profile '$name'"
                return 1
            end
            set -gx ANTHROPIC_API_KEY (cat $profdir/$name)
            mkdir -p (dirname $active_file)
            echo $name >$active_file
            chmod 600 $active_file
            echo "akey: ON  [$name]  ...$(string sub -s -4 -- $ANTHROPIC_API_KEY)"

        case off
            set --erase --universal ANTHROPIC_API_KEY 2>/dev/null
            set --erase --global ANTHROPIC_API_KEY 2>/dev/null
            rm -f $active_file
            echo "akey: OFF"

        case status
            if set -q ANTHROPIC_API_KEY
                set -l current ""
                test -r $active_file; and set current (cat $active_file)
                if test -n "$current"
                    echo "akey: ON  [$current]  ...$(string sub -s -4 -- $ANTHROPIC_API_KEY)"
                else
                    echo "akey: ON  (no active marker)  ...$(string sub -s -4 -- $ANTHROPIC_API_KEY)"
                end
                set -S ANTHROPIC_API_KEY 2>/dev/null | grep -E '^\$ANTHROPIC_API_KEY: set in' | sed 's/^/  /'
            else
                echo "akey: OFF"
            end

        case '*'
            echo "Usage:"
            echo "  akey                  pick profile via fzf (or '(off)' to clear)"
            echo "  akey on [<name>]      activate (uses last-active if no name)"
            echo "  akey use <name>       activate by name"
            echo "  akey off              clear ANTHROPIC_API_KEY from all fish scopes"
            echo "  akey set <name> [k]   store/update a profile (prompts for key if omitted)"
            echo "  akey rm <name>        delete a profile"
            echo "  akey list             list profiles ('*' = active)"
            echo "  akey status           show current state"
            return 1
    end
end
