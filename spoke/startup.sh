#!/bin/bash
# Startup script for Spoke node

# Set all environment variables
if [ -z "$HUB_ENDPOINT" ]; then
    echo "Hub Endpoint not set"
    exit 1
fi
if [ -z "$HUB_PUB_KEY" ]; then
    echo "HUB Public Key not set"
    exit 1
fi
if [ -z "$DEFAULT_PEER_PRIV_KEY" ]; then
    echo "Default Peer Priv Key not set"
    exit 1
fi

# File to modify
FILE="initial_config.conf"

# Replace placeholders with environment values
sed -i "s|#HUBENDPOINT#|$HUB_ENDPOINT|g" "$FILE"
sed -i "s|#HUBPUBLICKEY#|$HUB_PUB_KEY|g" "$FILE"
sed -i "s|#DEFAULTPEERPRIV#|$DEFAULT_PEER_PRIV_KEY|g" "$FILE"

function create_new_config {
    # Start default wireguard connection, retrying the command until it succeeds
    while true; do
        # Try to bring up the WireGuard interface
        wg-quick up ./initial_config.conf

        # Check if the command was successful
        if [ $? -eq 0 ]; then
            echo "WireGuard connection established successfully."
            break
        else
            echo "Failed to bring up WireGuard. Retrying in 5 seconds..."
            sleep 5
        fi
    done

    # Wait for connection to Hub
    echo "Waiting for connection to 10.123.123.1 via default config..."
    while ! ./check_host.sh 10.123.123.1; do
        echo "Waiting for connection to 10.123.123.1 via default config..."
        sleep 2
    done
    echo "Connection established!"

    # Get new config
    ./create_new_peer.sh
    if [ $? -ne 0 ]; then
        echo "creating config failed."
        # Kill any background processes we've started
        jobs -p | xargs -r kill
        exit 1
    fi

    echo "Peer config sent to hub. Waiting 2 seconds for hub processing..."
    sleep 2
    # Tear down default Wireguard config and set up new one
    wg-quick down ./initial_config.conf
    wg-quick up ./wg-configs/custom_config.conf
}

# Check for custom config, or create one
if [ -f "wg-configs/custom_config.conf" ]; then
    wg-quick up ./wg-configs/custom_config.conf
else
    create_new_config
fi

echo "Waiting for connection to 10.123.123.1 via new config..."
count=0
while ! ./check_host.sh 10.123.123.1; do
    ((count++))
    echo "Waiting for connection to 10.123.123.1 via new config..."
    sleep 2
    if [[ $count -eq 6 ]]; then # 6 attempts == 3 minutes at 30 seconds per host check attempt
        echo "couldn't connect. Attempting to retrieve new config..."
        wg-quick down ./wg-configs/custom_config.conf
        rm -f wg-configs/custom_config.conf
        create_new_config
        count=0
    fi
done
echo "Connection established!"

# Periodic connectivity check & auto-recovery
(
while true; do
    if ! ./check_host.sh 10.123.123.1; then
        echo "Lost connection to 10.123.123.1. Attempting recovery..."
        wg-quick down ./wg-configs/custom_config.conf
        sleep 2
        wg-quick up ./wg-configs/custom_config.conf

        # Wait and recheck connection
        retry=0
        while ! ./check_host.sh 10.123.123.1; do
            ((retry++))
            echo "Reconnection attempt $retry failed..."
            sleep 2
            if [[ $retry -eq 2 ]]; then
                echo "Failed to reconnect. Regenerating config..."
                wg-quick down ./wg-configs/custom_config.conf
                rm -f wg-configs/custom_config.conf
                create_new_config
                break
            fi
        done

        echo "Connection re-established!"
    fi
    sleep 30 # Check every 30 seconds
done
) &

# Start chunker server in background
echo "Starting chunker server"
cd /app/chunker_server && conda run -n py312 gunicorn --bind 0.0.0.0:11435 app:app --workers $CHUNKER_WORKERS --access-logfile /proc/1/fd/1 --error-logfile /proc/1/fd/2 &

vllm serve infly/inf-retriever-v1-1.5b pull granite-embedding:278m-fp16 --host 0.0.0.0 --port 11434