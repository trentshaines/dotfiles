function mmt --description "Start persistent SSH tunnel to Mac Mini (kills existing first)"
    # Kill any existing tunnel
    pkill -f "autossh.*100.77.152.106" 2>/dev/null

    # Start new tunnel in background
    autossh -M 0 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -f -N \
        -L 3000:localhost:3000 -L 8000:localhost:8000 \
        trenthaines@100.77.152.106

    echo "Tunnel started (ports 3000, 8000 → Mac Mini)"
end
