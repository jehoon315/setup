#!/bin/bash

# ==============================================================================
# Linux System & CXL Information Collector
# ------------------------------------------------------------------------------
# Description:
#   Collects hardware, OS, kernel, and network information.
#   Specially designed to analyze CXL devices with individual reports per device.
#
# Usage:
#   sudo ./collect_sysinfo.sh
# ==============================================================================

# --- [0] Root Privilege Check ---
if [ "$EUID" -ne 0 ]; then
    echo "========================================================"
    echo " [ERROR] Insufficient Privileges"
    echo " Root privileges are required to access hardware details (esp. -xxxx)."
    echo " Please run this script with sudo:"
    echo "   sudo $0"
    echo "========================================================"
    exit 1
fi

# --- [1] Configuration & Setup ---
HOSTNAME=$(hostname)
KERNEL_VER=$(uname -r)
DATE=$(date "+%Y%m%d_%H%M%S")

BASE_DIR="./system_reports"
TARGET_DIR="${BASE_DIR}/${HOSTNAME}_${KERNEL_VER}_${DATE}"

mkdir -p "$TARGET_DIR"

echo "========================================================"
echo " Starting System Information Collection..."
echo "--------------------------------------------------------"
echo " Hostname       : $HOSTNAME"
echo " Kernel Version : $KERNEL_VER"
echo " Timestamp      : $DATE"
echo " Output Dir     : $TARGET_DIR"
echo "========================================================"

# --- [2] Helper Functions ---
run_and_save() {
    FILENAME="$1"
    CMD="$2"
    FILEPATH="${TARGET_DIR}/${FILENAME}"
    
    echo " [EXEC] $CMD -> $FILENAME"
    echo "### Command: $CMD" > "$FILEPATH"
    echo "### Date: $(date)" >> "$FILEPATH"
    echo "--------------------------------------------------" >> "$FILEPATH"
    eval "$CMD" >> "$FILEPATH" 2>&1
}

copy_file() {
    FILENAME="$1"
    SOURCE_FILE="$2"
    FILEPATH="${TARGET_DIR}/${FILENAME}"
    echo " [COPY] $SOURCE_FILE -> $FILENAME"
    if [ -f "$SOURCE_FILE" ]; then
        echo "### Source: $SOURCE_FILE" > "$FILEPATH"
        echo "--------------------------------------------------" >> "$FILEPATH"
        cat "$SOURCE_FILE" >> "$FILEPATH"
    else
        echo "File $SOURCE_FILE not found." > "$FILEPATH"
    fi
}

# --- [3] Execution Phase ---

echo ""
echo ">>> Phase 1: OS & Kernel Basic Info"
run_and_save "00_os_release.txt"  "cat /etc/*release"
run_and_save "01_uname.txt"       "uname -a"
run_and_save "02_hostnamectl.txt" "hostnamectl"
copy_file    "03_cmdline.txt"     "/proc/cmdline"
copy_file    "04_kernel_config.txt" "/boot/config-${KERNEL_VER}"

echo ">>> Phase 2: CPU & Processes"
run_and_save "10_lscpu.txt"       "lscpu"
run_and_save "11_uptime.txt"      "uptime"

echo ">>> Phase 3: Memory & System Resources"
run_and_save "20_numactl.txt"     "numactl -H"
run_and_save "21_free.txt"        "free -h"
run_and_save "22_vmstat.txt"      "vmstat -s"
run_and_save "23_lsmem.txt"       "lsmem --output-all"
run_and_save "24_dmidecode_mem.txt" "dmidecode -t memory"
copy_file    "25_iomem.txt"       "/proc/iomem"
copy_file    "26_ioports.txt"     "/proc/ioports"
copy_file    "27_interrupts.txt"  "/proc/interrupts"

echo ">>> Phase 4: Kernel Modules & Parameters"
run_and_save "30_lsmod.txt"       "lsmod"
run_and_save "31_sysctl.txt"      "sysctl -a" 
copy_file    "32_tainted.txt"     "/proc/sys/kernel/tainted"

echo ">>> Phase 5: Storage & Disks"
run_and_save "40_lsblk.txt"       "lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT,UUID,MODEL"
run_and_save "41_df.txt"          "df -hT"
run_and_save "42_fdisk.txt"       "fdisk -l"

echo ">>> Phase 6: Network Configuration"
run_and_save "50_ip_addr.txt"     "ip -c addr"
run_and_save "51_ip_route.txt"    "ip route"
run_and_save "52_ss_ports.txt"    "ss -tuln"
run_and_save "53_ethtool.txt"     "ls /sys/class/net/ | xargs -I {} ethtool {} 2>/dev/null"

echo ">>> Phase 7: CXL Device Specific Analysis"
# 1. Save Inventory Summary
run_and_save "70_cxl_inventory.txt" "lspci -nn | grep -i CXL"

# 2. Extract Slot IDs
CXL_SLOTS=$(lspci -nn | grep -i CXL | awk '{print $1}')

if [ -z "$CXL_SLOTS" ]; then
    echo " [INFO] No CXL devices found on this system."
    echo "No CXL devices found." > "${TARGET_DIR}/71_cxl_no_dev.txt"
else
    echo " [INFO] Found CXL Device(s) at: $CXL_SLOTS"
    
    # 3. Iterate per device
    for SLOT in $CXL_SLOTS; do
        # Sanitize Slot ID (e.g., 35:00.0 -> 35-00.0) for safe filename
        SLOT_SAFE=${SLOT//:/-}
        
        FILENAME="71_cxl_dev_${SLOT_SAFE}.txt"
        echo " -> Processing Device: $SLOT (Saving to $FILENAME)"

        run_and_save $FILENAME       "lspci -s $SLOT -vvv -xxxx"
    done
fi

echo ">>> Phase 8: Hardware Bus (General)"
run_and_save "80_lspci_k.txt"     "lspci -k"
run_and_save "81_lsusb.txt"       "lsusb"
run_and_save "82_lshw.txt"        "lshw -short"

echo ">>> Phase 9: System Logs"
run_and_save "90_dmesg.txt"       "dmesg -T"

# --- [4] Compression & Cleanup ---
TAR_FILE="${BASE_DIR}/${HOSTNAME}_${KERNEL_VER}_${DATE}.tar.gz"

echo ""
echo "========================================================"
echo " Collection Finished. Compressing..."
tar -czf "$TAR_FILE" -C "$BASE_DIR" "${HOSTNAME}_${KERNEL_VER}_${DATE}"

if [ -f "$TAR_FILE" ]; then
    echo " [SUCCESS] Archive created: $TAR_FILE"
else
    echo " [ERROR] Failed to create archive."
fi
echo "========================================================"
