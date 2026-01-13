#!/bin/bash

LIST_FILE="server.list"
DEFAULT_USER="sag"

# 1. Check if server.list exists
if [ ! -f "$LIST_FILE" ]; then
    echo "Error: File '$LIST_FILE' not found."
    exit 1
fi

# Declare arrays to store server information
declare -a SERVER_NAMES
declare -a SERVER_IPS

# 2. Parse the file (read line by line)
# Skip empty lines or comments starting with '#'
idx=0
while read -r name ip; do
    if [[ -n "$name" && "$name" != \#* ]]; then
        SERVER_NAMES[$idx]=$name
        SERVER_IPS[$idx]=$ip
        ((idx++))
    fi
done < "$LIST_FILE"

# Exit if no servers are found
if [ ${#SERVER_NAMES[@]} -eq 0 ]; then
    echo "No server information found."
    exit 1
fi

# 3. Display Server List (Starting from 1)
echo "========================================"
echo "      Select a server to connect"
echo "========================================"

for i in "${!SERVER_NAMES[@]}"; do
    # Display starting from 1 for user convenience
    display_num=$((i+1))
    printf "%2d) %-15s [%s]\n" "$display_num" "${SERVER_NAMES[$i]}" "${SERVER_IPS[$i]}"
done
echo "========================================"

# 4. Input Selection
read -p "Enter number: " host_num

# Validate input (Must be a number and within range)
if ! [[ "$host_num" =~ ^[0-9]+$ ]] || [ "$host_num" -lt 1 ] || [ "$host_num" -gt "${#SERVER_NAMES[@]}" ]; then
    echo "Invalid number. Exiting script."
    exit 1
fi

# Calculate actual array index (Input - 1)
real_idx=$((host_num-1))
TARGET_IP=${SERVER_IPS[$real_idx]}
TARGET_NAME=${SERVER_NAMES[$real_idx]}

# 5. Input Username (Handle default value)
read -p "Enter User ID (Default: $DEFAULT_USER): " input_user

# Use default user if input is empty
TARGET_USER=${input_user:-$DEFAULT_USER}

# 6. Execute SSH Connection
echo ""
echo ">> Connecting to $TARGET_NAME ($TARGET_IP) as $TARGET_USER..."
echo ""

ssh "${TARGET_USER}@${TARGET_IP}"
