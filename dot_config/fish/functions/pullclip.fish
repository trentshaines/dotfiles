function pullclip --description "Pull the Mac mini's clipboard into this laptop's clipboard"
    set -l host trenthaines@100.64.101.124
    ssh -o BatchMode=yes $host pbpaste | pbcopy
    and echo "✓ pulled mini clipboard ("(pbpaste | wc -c | string trim)" bytes)"
    or echo "✗ failed to reach mini"
end
