function fmmt --description "Start persistent SSH tunnel to work Mac Mini (kills existing first)"
    # Kill any existing tunnel
    pkill -f "autossh.*trenthaines@100.64.101.124" 2>/dev/null

    # Start new tunnel in background
    autossh -M 0 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -f -N \
        -L 3000:localhost:3000 -L 8000:localhost:8000 \
        trenthaines@100.64.101.124

    echo "Tunnel started (ports 3000, 8000 → work Mac Mini)"
end
