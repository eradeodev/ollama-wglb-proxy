#!/bin/bash
# Accept incoming connections from default peer to create new peers

# Ensure peers directory exists
mkdir -p peers

# Listen for incoming connections
while true; do
    # Retrieve the next IP address
    NEXT_IP=$(./find_next_ip.sh)
    echo $NEXT_IP | nc -l -p 1234 -q 1
    echo "Sent IP address to client"

    # Calculate next peer number
    IFS='.' read -r a b c d <<< "$NEXT_IP"
    NEXT_PEER_NUMBER=$(($d - 2))

    # Listen for client peer config with a timeout
    if timeout 10 nc -l -p 1235 > peers/${NEXT_PEER_NUMBER}; then
        # Successfully retrieved peer config
        echo "Retrieved client peer config"
        echo "Rebuilding wireguard config..."
        ./rebuild_and_start_wg.sh
        # kill python process to rebuild proxy
        pkill python
    else
        # Timeout or error, handle failure
        rm -f peers/${NEXT_PEER_NUMBER}
        echo "FAILED: Could not retrieve client peer config"
    fi
done

