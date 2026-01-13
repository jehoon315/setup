#!/bin/bash

# ==============================================================================
# Memory Block Manager (Online Movable / Offline)
# 
# Description:
#   Iterates through a specified range of memory blocks and changes their state.
#   Supports 'online_movable' and 'offline' operations.
#
# Usage:
#   Run with root privileges. Follow interactive prompts.
# ==============================================================================

# Check if the script is running as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root."
  exit 1
fi

# ------------------------------------------------------------------------------
# 1. Receive User Inputs
# ------------------------------------------------------------------------------

# Input: Start Index
read -p "Enter Start Index: " START_IDX

# Input: End Index
read -p "Enter End Index: " END_IDX

# Input: Step (Default: 1)
read -p "Enter Step (Default 1): " STEP_INPUT
STEP=${STEP_INPUT:-1} # Set default to 1 if input is empty

# Input: Action (1 = online_movable, 2 = offline)
echo "Select Action:"
echo "  1) Online (Movable Zone)"
echo "  2) Offline"
read -p "Enter number (1 or 2): " ACTION_INPUT

# ------------------------------------------------------------------------------
# 2. Validate and Configure Settings
# ------------------------------------------------------------------------------

# Determine target state based on input
TARGET_STATE=""
case "$ACTION_INPUT" in
  1)
    TARGET_STATE="online_movable"
    ;;
  2)
    TARGET_STATE="offline"
    ;;
  *)
    echo "Error: Invalid action selected. Exiting."
    exit 1
    ;;
esac

echo "---------------------------------------------------"
echo " Configuration Summary"
echo " Range : $START_IDX to $END_IDX (Step: $STEP)"
echo " Action: $TARGET_STATE"
echo "---------------------------------------------------"

# ------------------------------------------------------------------------------
# 3. Execute State Change
# ------------------------------------------------------------------------------

# Loop through the range
for (( i=START_IDX; i<=END_IDX; i+=STEP ))
do
    MEM_PATH="/sys/devices/system/memory/memory$i/state"

    # Check if the memory block exists
    if [ -e "$MEM_PATH" ]; then
        CURRENT_STATE=$(cat "$MEM_PATH")
        
        # skip if already in target state
        if [ "$CURRENT_STATE" == "$TARGET_STATE" ]; then
            echo "[SKIP] Block $i is already $CURRENT_STATE."
        else
            # Try to write the new state
            if echo "$TARGET_STATE" > "$MEM_PATH" 2>/dev/null; then
                echo "[OK] Block $i changed to $TARGET_STATE."
            else
                echo "[FAIL] Block $i could not be changed (Device busy?)."
            fi
        fi
    else
        echo "[INFO] Block $i does not exist."
    fi
done

echo "---------------------------------------------------"
echo "Operation Complete."
