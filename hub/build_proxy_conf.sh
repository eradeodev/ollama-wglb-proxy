#!/bin/bash
# Use the wireguard configs to build up the proxy config

#!/bin/bash

PEERS_DIR="peers"
OUTPUT_FILE="proxy_config.ini"
PORT=11434

echo -n "" > "$OUTPUT_FILE"

count=0
for file in "$PEERS_DIR"/*; do
    if [[ -f "$file" ]]; then
        IP=$(grep -oP 'AllowedIPs = \K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$file")
        if [[ -n "$IP" ]]; then
            if [[ $count -eq 0 ]]; then
                SERVER_NAME="DefaultServer"
            else
                SERVER_NAME="Server$count"
            fi
            echo "[$SERVER_NAME]" >> "$OUTPUT_FILE"
            echo "url = http://$IP:$PORT" >> "$OUTPUT_FILE"
            echo "queue_size = 3" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
            ((count++))
        fi
    fi
done

echo "Configuration written to $OUTPUT_FILE"

