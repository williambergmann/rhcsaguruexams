#!/bin/bash
# Grader script - Batch 14 (Based on Mock Test 2 Cont.)
# Version: 2024-03-10

# --- Configuration ---
REPORT_FILE="/tmp/exam-report-batch14.txt"
PASS_THRESHOLD_PERCENT=70 # Percentage required to pass
MAX_SCORE=300

# --- Color Codes ---
COLOR_OK="\033[32m"
COLOR_FAIL="\033[31m"
COLOR_INFO="\033[1m"
COLOR_RESET="\033[0m"

# --- Objective Mapping ---
# 1=Tools, 2=Scripts, 3=Operate, 4=LocalStore, 5=FSConfig,
# 6=Deploy/Maintain, 7=Network, 8=Users/Groups, 9=Security, 10=Containers
declare -A TASK_OBJECTIVE=(
    [1]=7  # Networking (sysctl - IPv6 Forwarding)
    [2]=8  # Users/Groups (useradd)
    [3]=9  # Security (SELinux context - semanage/restorecon)
    [4]=10 # Containers (pull, run --user) + Users/Groups
    [5]=2  # Scripts (bash script - args, loops, useradd, passwd)
    [6]=4  # Local Storage (partitioning)
    [7]=1  # Tools (find, cp)
    [8]=4  # Local Storage (partitioning, mkswap, swapon, fstab)
    [9]=9  # Security (ACLs) + Tools (cp, chown)
    [10]=3 # Operate (journald config)
)

# Objective names (index 1-10)
declare -A OBJECTIVE_NAMES=(
    [1]="Understand and use essential tools"
    [2]="Create simple shell scripts"
    [3]="Operate running systems"
    [4]="Configure local storage"
    [5]="Create and configure file systems"
    [6]="Deploy, configure and maintain systems"
    [7]="Manage basic networking"
    [8]="Manage users and groups"
    [9]="Manage security"
    [10]="Manage containers"
)

# Initialize objective scores (index 1-10)
declare -A OBJECTIVE_SCORE
declare -A OBJECTIVE_TOTAL
for i in {1..10}; do
    OBJECTIVE_SCORE[$i]=0
    OBJECTIVE_TOTAL[$i]=0
done

# --- Helper Functions ---
check_file_exists() {
    local target_path="$1"
    local points_ok="$2"
    local points_fail="$3"
    if [ -e "$target_path" ]; then
        echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t File/Directory '$target_path' exists." | tee -a ${REPORT_FILE}
        return $points_ok
    else
        echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t File/Directory '$target_path' does not exist." | tee -a ${REPORT_FILE}
        return $points_fail
    fi
}

check_command_output() {
    local cmd="$1"
    local pattern="$2"
    local points_ok="$3"
    local points_fail="$4"
    local grep_opts="$5"
    if eval "$cmd" 2>&1 | grep ${grep_opts} -- "${pattern}" &>/dev/null; then
        echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Command '$cmd' output contains expected pattern '${pattern}'." | tee -a ${REPORT_FILE}
        return $points_ok
    else
        echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Command '$cmd' output does not contain expected pattern '${pattern}'." | tee -a ${REPORT_FILE}
        return $points_fail
    fi
}

check_service_status() {
    local service="$1"
    local state="$2" # active or enabled
    local points_ok="$3"
    local points_fail="$4"
    if systemctl "is-${state}" --quiet "$service"; then
        echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Service '$service' is $state." | tee -a ${REPORT_FILE}
        return $points_ok
    else
        echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Service '$service' is NOT $state." | tee -a ${REPORT_FILE}
        return $points_fail
    fi
}

add_score() {
    local points=$1
    SCORE=$(( SCORE + points ))
}

# Function to update scores (overall and by objective)
grade_task() {
    local task_num=$1
    local points_possible=$2
    local points_earned=$3
    local obj_index=${TASK_OBJECTIVE[$task_num]}

    add_score "$points_earned"
    TOTAL=$(( TOTAL + points_possible )) # Keep track of total attempted points

    if [[ -n "$obj_index" ]]; then
        OBJECTIVE_SCORE[$obj_index]=$(( ${OBJECTIVE_SCORE[$obj_index]} + points_earned ))
        OBJECTIVE_TOTAL[$obj_index]=$(( ${OBJECTIVE_TOTAL[$obj_index]} + points_possible ))
    else
         echo -e "${COLOR_FAIL}[WARN]${COLOR_RESET}\t Task $task_num has no objective mapping!" | tee -a ${REPORT_FILE}
    fi
}


# --- Initialization ---
clear
# Check root privileges
if [[ $EUID -ne 0 ]]; then
   echo -e "${COLOR_FAIL}This script must be run as root.${COLOR_RESET}"
   exit 1
fi

# Clean up previous report
rm -f ${REPORT_FILE} &>/dev/null
touch ${REPORT_FILE} &>/dev/null
echo "Starting Grade Evaluation Batch 14 - $(date)" | tee -a ${REPORT_FILE}
echo "-----------------------------------------" | tee -a ${REPORT_FILE}

# Initialize score variables
SCORE=0
TOTAL=0

# --- Pre-check: SELinux ---
echo -e "${COLOR_INFO}Pre-check: SELinux Status${COLOR_RESET}" | tee -a ${REPORT_FILE}
if getenforce | grep -iq enforcing &>/dev/null; then
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t SELinux is in Enforcing mode." | tee -a ${REPORT_FILE}
else
    echo -e "${COLOR_FAIL}[FATAL]${COLOR_RESET}\t Task evaluation may be unreliable because SELinux is not in enforcing mode." | tee -a ${REPORT_FILE}
fi
echo -e "\n" | tee -a ${REPORT_FILE}
# --- Task Evaluation ---

### TASK 1: Enable IPv6 Forwarding
CURRENT_TASK=1; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Enable IPv6 Forwarding${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
SYSCTL_PARAM="net.ipv6.conf.all.forwarding"
TASK_POINTS=0
# Check running kernel value
if [[ $(sysctl -n "$SYSCTL_PARAM" 2>/dev/null) == 1 ]]; then TASK_POINTS=$((TASK_POINTS + 10)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t $SYSCTL_PARAM is currently active (1)."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t $SYSCTL_PARAM is not currently active."; fi
# Check persistent configuration
if grep -Eqs "^\s*${SYSCTL_PARAM}\s*=\s*1" /etc/sysctl.conf /etc/sysctl.d/*.conf; then TASK_POINTS=$((TASK_POINTS + 20)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Persistent setting $SYSCTL_PARAM = 1 found."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Persistent setting $SYSCTL_PARAM = 1 NOT found."; fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 2: User max, UID 6000, no login
CURRENT_TASK=2; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: User max, UID 6000, no login${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
USER_NAME="max"; EXPECTED_UID=6000; EXPECTED_SHELL="/sbin/nologin"
TASK_POINTS=0
if id "$USER_NAME" &>/dev/null; then
    TASK_POINTS=$(( TASK_POINTS + 10 )); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t User '$USER_NAME' exists."
    if [[ $(id -u "$USER_NAME") == "$EXPECTED_UID" ]]; then TASK_POINTS=$(( TASK_POINTS + 10 )); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t UID is $EXPECTED_UID."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t UID is not $EXPECTED_UID."; fi
    if getent passwd "$USER_NAME" | cut -d: -f7 | grep -q "$EXPECTED_SHELL"; then TASK_POINTS=$(( TASK_POINTS + 10 )); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Shell is $EXPECTED_SHELL."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Shell is not $EXPECTED_SHELL."; fi
else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t User '$USER_NAME' does not exist."; fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 3: SELinux Type Change for /etc/ssh
CURRENT_TASK=3; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: SELinux Type Change for /etc/ssh${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
TARGET_DIR="/etc/ssh"; EXPECTED_TYPE="var_log_t"
TASK_POINTS=0
echo -e "${COLOR_INFO}[WARN]${COLOR_RESET}\t Changing context of /etc/ssh is non-standard and potentially breaks SSH." | tee -a ${REPORT_FILE}
# Check current context
CURRENT_CONTEXT=$(ls -Zd "$TARGET_DIR" 2>/dev/null | awk '{print $4}')
if [[ "$CURRENT_CONTEXT" == *":${EXPECTED_TYPE}:"* ]]; then
    TASK_POINTS=$(( TASK_POINTS + 15 ))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Current SELinux type for '$TARGET_DIR' is '$EXPECTED_TYPE'."
else
    echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Current SELinux type for '$TARGET_DIR' is not '$EXPECTED_TYPE' (Found: $CURRENT_CONTEXT)."
fi
# Check persistent context (semanage fcontext)
PERSISTENT_CONTEXT=$(semanage fcontext -l | grep "^${TARGET_DIR}\(/.*\)?" | awk '$NF == "'$EXPECTED_TYPE':s0"' | head -n 1)
if [[ -n "$PERSISTENT_CONTEXT" ]]; then
    TASK_POINTS=$(( TASK_POINTS + 15 ))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Persistent SELinux type '$EXPECTED_TYPE' found for '$TARGET_DIR'. Ensure restorecon was run."
else
     echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Persistent SELinux type '$EXPECTED_TYPE' not found for '$TARGET_DIR' using semanage."
fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 4: Podman Pull ubi8, Run as user harry
CURRENT_TASK=4; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Podman Pull ubi8, Run as user harry${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
IMAGE_NAME="registry.access.redhat.com/ubi8"; CONTAINER_NAME="ubi8-container"; RUN_USER="harry"
TASK_POINTS=0
# Ensure podman and user harry exist
if ! command -v podman &> /dev/null; then dnf install -y container-tools &>/dev/null; fi
id "$RUN_USER" &>/dev/null || useradd "$RUN_USER"
# Check image pulled
if podman image exists "$IMAGE_NAME"; then TASK_POINTS=$((TASK_POINTS + 10)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Image '$IMAGE_NAME' exists locally."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Image '$IMAGE_NAME' not found locally."; fi
# Check container running
if podman ps --filter name="^${CONTAINER_NAME}$" --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
    TASK_POINTS=$((TASK_POINTS + 10))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Container '$CONTAINER_NAME' is running."
    # Check user inside container (inspect effective user)
    CONTAINER_USER=$(podman inspect "$CONTAINER_NAME" --format '{{.Config.User}}')
    # Need to exec to check effective runtime user ID if .Config.User is empty/root
    if [[ "$CONTAINER_USER" == "$RUN_USER" ]] || [[ "$CONTAINER_USER" == "$(id -u $RUN_USER)" ]]; then
         TASK_POINTS=$((TASK_POINTS + 10))
         echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Container user configured as '$RUN_USER'."
    elif podman exec "$CONTAINER_NAME" id -u 2>/dev/null | grep -q "$(id -u $RUN_USER)"; then
          TASK_POINTS=$((TASK_POINTS + 10))
          echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Container process running as effective user '$RUN_USER'."
    else
         echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Container '$CONTAINER_NAME' is not configured to run as user '$RUN_USER' (Found user: '$CONTAINER_USER')."
    fi
else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Container '$CONTAINER_NAME' is not running."; fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 5: users.sh Script
CURRENT_TASK=5; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: users.sh Script${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
SCRIPT_DIR="/root/workspace"; SCRIPT_PATH="$SCRIPT_DIR/users.sh"
mkdir -p "$SCRIPT_DIR" # Ensure dir exists
TASK_POINTS=0
# Check script existence and executability
check_file_exists "$SCRIPT_PATH" 5 0; T_SUB_SCORE=$?
if [[ $T_SUB_SCORE -eq 5 ]]; then
    TASK_POINTS=$((TASK_POINTS + T_SUB_SCORE))
    if [ -x "$SCRIPT_PATH" ]; then
        TASK_POINTS=$((TASK_POINTS + 5))
        echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Script '$SCRIPT_PATH' is executable."
        # Test run: create test users testA, testB
        rm -f /etc/subuid /etc/subgid # Avoid issues with test user creation if podman installed
        userdel -r testA &>/dev/null; userdel -r testB &>/dev/null
        "$SCRIPT_PATH" "testA,testB" # Execute script
        USERA_OK=false; USERB_OK=false; PW_OK=false
        if id testA &>/dev/null; then USERA_OK=true; fi
        if id testB &>/dev/null; then USERB_OK=true; fi
        # Rudimentary password check (just checks if PW field looks set)
        if grep '^testA:' /etc/shadow | cut -d: -f2 | grep -q '^\$.*'; then PW_OK=true; fi

        if $USERA_OK && $USERB_OK; then TASK_POINTS=$((TASK_POINTS + 10)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Script created test users."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Script failed to create test users."; fi
        if $PW_OK; then TASK_POINTS=$((TASK_POINTS + 10)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Script appeared to set password."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Script failed to set password."; fi
        userdel -r testA &>/dev/null; userdel -r testB &>/dev/null # Cleanup
    else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Script '$SCRIPT_PATH' is not executable."; fi
else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Script '$SCRIPT_PATH' does not exist."; fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}


### TASK 6: Create LVM Partition Type
CURRENT_TASK=6; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Create LVM Partition Type${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
DEVICE_6="/dev/nvme1n1"
LVM_TYPE_CODE_GPT="E6D6D379-F507-44C2-A23C-238F2A3DF928" # LVM GUID
LVM_TYPE_CODE_MBR="8e"
# Check if *any* partition on the device has the LVM type using parted
if parted -s "$DEVICE_6" print | grep -iq lvm; then
     echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Found at least one partition with LVM type on '$DEVICE_6'." | tee -a ${REPORT_FILE}
     T_SCORE=30
else
     echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t No partition with LVM type found on '$DEVICE_6'." | tee -a ${REPORT_FILE}
fi
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 7: Find and Copy coder's Files
CURRENT_TASK=7; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Find and Copy coder's Files${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
TARGET_DIR_7="/root/Backup"
USER_CODER_7="coder"
# Ensure user coder exists for test, create dummy file
id "$USER_CODER_7" &>/dev/null || useradd "$USER_CODER_7"
mkdir -p /home/"$USER_CODER_7"
touch /home/"$USER_CODER_7"/coder_file1.txt && chown "$USER_CODER_7":"$USER_CODER_7" /home/"$USER_CODER_7"/coder_file1.txt
mkdir -p "$TARGET_DIR_7" # Ensure target exists
TASK_POINTS=0
# Simple check: does the target directory exist and contain the dummy file?
if [ -d "$TARGET_DIR_7" ]; then
    TASK_POINTS=$(( TASK_POINTS + 10 ))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Target directory '$TARGET_DIR_7' exists."
    if [ -f "${TARGET_DIR_7}/coder_file1.txt" ]; then
        TASK_POINTS=$(( TASK_POINTS + 20 ))
        echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Found dummy coder file in target directory (copy likely worked)."
    else
        echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Did not find dummy coder file in target directory."
    fi
else
    echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Target directory '$TARGET_DIR_7' does not exist."
fi
# Cleanup dummy file
rm -f /home/"$USER_CODER_7"/coder_file1.txt
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 8: Add 512M Swap Partition on nvme2n1
CURRENT_TASK=8; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Add 512M Swap Partition on nvme2n1${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
SWAP_DISK="/dev/nvme2n1" # Specific disk
EXPECTED_SIZE_MB=512
SIZE_MIN=490; SIZE_MAX=530 # Allow tolerance
TASK_POINTS=0
FOUND_NEW_SWAP_8=false
NEW_SWAP_SIZE_OK_8=false
FSTAB_OK_8=false
ACTIVE_OK_8=false

# Check swapon output first
while IFS= read -r line; do
    FS_SPEC=$(echo "$line" | awk '{print $1}')
    FS_TYPE=$(echo "$line" | awk '{print $2}') # partition or file
    FS_SIZE=$(echo "$line" | awk '{print $3}') # Size in KiB
    if [[ "$FS_SPEC" == ${SWAP_DISK}* ]] && [[ "$FS_TYPE" == "partition" ]]; then
        ACTIVE_OK_8=true
        SIZE_MB_8=$(awk -v size="$FS_SIZE" 'BEGIN {printf "%.0f", size/1024}')
        if [[ "$SIZE_MB_8" -ge $SIZE_MIN ]] && [[ "$SIZE_MB_8" -le $SIZE_MAX ]]; then
            NEW_SWAP_SIZE_OK_8=true
        fi
        # Now check fstab for this specific device
        if grep -F "$FS_SPEC" /etc/fstab | grep -w swap | grep -v "^#" &>/dev/null; then
            FSTAB_OK_8=true
        fi
        break # Found a swap partition on the correct disk
    fi
done < <(swapon -s | sed '1d') # Exclude header

if $ACTIVE_OK_8; then TASK_POINTS=$((TASK_POINTS + 10)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Found active swap partition on '$SWAP_DISK'."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t No active swap partition found on '$SWAP_DISK'."; fi
if $NEW_SWAP_SIZE_OK_8; then TASK_POINTS=$((TASK_POINTS + 10)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Active swap partition size is correct (~${EXPECTED_SIZE_MB}M)."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Active swap partition size is incorrect."; fi
if $FSTAB_OK_8; then TASK_POINTS=$((TASK_POINTS + 10)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Persistent swap entry found in /etc/fstab."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Persistent swap entry not found in /etc/fstab."; fi

T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 9: ACLs on /var/tmp/fstab (harry/natasha)
CURRENT_TASK=9; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: ACLs on /var/tmp/fstab (harry/natasha)${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
TARGET_FILE_9="/var/tmp/fstab"
USER_HARRY="harry"; USER_NATASHA="natasha"
# Ensure users exist
id "$USER_HARRY" &>/dev/null || useradd "$USER_HARRY"
id "$USER_NATASHA" &>/dev/null || useradd "$USER_NATASHA"
TASK_POINTS=0
# Check file exists, owner root:root
check_file_exists "$TARGET_FILE_9" 5 0; T_SUB_SCORE=$?; TASK_POINTS=$((TASK_POINTS + T_SUB_SCORE))
if [[ $T_SUB_SCORE -eq 5 ]]; then
    if [[ $(stat -c %U:%G "$TARGET_FILE_9") == "root:root" ]]; then TASK_POINTS=$((TASK_POINTS + 5)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Owner/Group is root:root."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Owner/Group is not root:root."; fi
    # Check ACLs
    ACL_OUT_9=$(getfacl "$TARGET_FILE_9" 2>/dev/null)
    HARRY_OK=false; NATASHA_OK=false; OTHER_OK=false
    if echo "$ACL_OUT_9" | grep -Eq "^user:${USER_HARRY}:rw-"; then HARRY_OK=true; fi
    if echo "$ACL_OUT_9" | grep -Eq "^user:${USER_NATASHA}:---"; then NATASHA_OK=true; fi
    if echo "$ACL_OUT_9" | grep -Eq "^other::r--"; then OTHER_OK=true; fi

    if $HARRY_OK; then TASK_POINTS=$((TASK_POINTS + 5)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t ACL for harry (rw-) correct."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t ACL for harry incorrect/missing."; fi
    if $NATASHA_OK; then TASK_POINTS=$((TASK_POINTS + 5)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t ACL for natasha (---) correct."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t ACL for natasha incorrect/missing."; fi
    if $OTHER_OK; then TASK_POINTS=$((TASK_POINTS + 5)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Other permissions (r--) correct."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Other permissions incorrect."; fi
else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t File '$TARGET_FILE_9' does not exist."; fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 10: Persistent Journald Log Storage (100M Limit)
CURRENT_TASK=10; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Persistent Journald Log Storage (100M Limit)${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
JOURNALD_CONF="/etc/systemd/journald.conf"
TASK_POINTS=0
# Check Storage=persistent
if grep -Eq '^\s*Storage\s*=\s*persistent' "$JOURNALD_CONF"; then
    TASK_POINTS=$((TASK_POINTS + 15))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Storage=persistent found in '$JOURNALD_CONF'."
else
    # Check if auto mode resulted in persistent due to dir existence
    if [ -d /var/log/journal ] && grep -Eq '^\s*Storage\s*=\s*auto' "$JOURNALD_CONF"; then
         TASK_POINTS=$((TASK_POINTS + 10)) # Partial credit for effective persistence
         echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Storage=auto with /var/log/journal existing (effectively persistent)."
    elif [ -d /var/log/journal ] && ! grep -Eq '^\s*Storage\s*=' "$JOURNALD_CONF"; then
         TASK_POINTS=$((TASK_POINTS + 10)) # Partial credit for default auto behavior
         echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t /var/log/journal exists and Storage not set (effectively persistent)."
    else
        echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Storage=persistent not explicitly set, and persistence via auto not confirmed."
    fi
fi
# Check SystemMaxUse=100M
if grep -Eq '^\s*SystemMaxUse\s*=\s*100M' "$JOURNALD_CONF"; then
    TASK_POINTS=$((TASK_POINTS + 15))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t SystemMaxUse=100M found in '$JOURNALD_CONF'."
else
    echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t SystemMaxUse=100M not found or incorrect in '$JOURNALD_CONF'."
fi
# Verify runtime effect (approximate size check)
DISK_USAGE_MB=$(journalctl --disk-usage | awk -F '[ M]+' '/Archived and active journals take up/ {print $8}')
if [[ -n "$DISK_USAGE_MB" ]] && [[ "$DISK_USAGE_MB" -lt 120 ]]; then # Allow some overhead
     echo -e "${COLOR_OK}[INFO]${COLOR_RESET}\t Current journal disk usage (${DISK_USAGE_MB}M) respects limit."
else
     echo -e "${COLOR_FAIL}[WARN]${COLOR_RESET}\t Current journal disk usage (${DISK_USAGE_MB}M) seems high or couldn't be checked."
fi

T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}


# --- Final Grading ---
echo "------------------------------------------------" | tee -a ${REPORT_FILE}
echo "Evaluation Complete. Press Enter for results overview."
read
clear

# --- Calculate Objective Scores ---
echo -e "\nPerformance on exam objectives:\n" | tee -a ${REPORT_FILE}
printf " \t%-45s : %s\n" "OBJECTIVE" "SCORE" | tee -a ${REPORT_FILE}
printf " \t%-45s : %s\n" "---------------------------------------------" "------" | tee -a ${REPORT_FILE}
GRAND_TOTAL_POSSIBLE=0
for i in {1..10}; do
    OBJ_NAME=${OBJECTIVE_NAMES[$i]:-"Unknown Objective $i"}
    OBJ_SCORE_VAL=${OBJECTIVE_SCORE[$i]:-0}
    OBJ_TOTAL_VAL=${OBJECTIVE_TOTAL[$i]:-0}
    PERCENT=0
    if [[ $OBJ_TOTAL_VAL -gt 0 ]]; then
        PERCENT=$(( OBJ_SCORE_VAL * 100 / OBJ_TOTAL_VAL ))
        GRAND_TOTAL_POSSIBLE=$(( GRAND_TOTAL_POSSIBLE + OBJ_TOTAL_VAL ))
    fi
    printf " \t%-45s : %s%%\n" "$OBJ_NAME" "$PERCENT" | tee -a ${REPORT_FILE}
done
echo -e "\n------------------------------------------------" | tee -a ${REPORT_FILE}

# --- Calculate Overall Score ---
if [[ $GRAND_TOTAL_POSSIBLE -lt $MAX_SCORE ]] && [[ $GRAND_TOTAL_POSSIBLE -gt 0 ]]; then
    PASS_SCORE=$(( GRAND_TOTAL_POSSIBLE * PASS_THRESHOLD_PERCENT / 100 ))
    MAX_SCORE_ADJUSTED=$GRAND_TOTAL_POSSIBLE
else
    PASS_SCORE=$(( MAX_SCORE * PASS_THRESHOLD_PERCENT / 100 ))
    MAX_SCORE_ADJUSTED=$MAX_SCORE
fi

echo -e "\nPassing score:\t\t${PASS_SCORE} ( ${PASS_THRESHOLD_PERCENT}% of ${MAX_SCORE_ADJUSTED} points possible)" | tee -a ${REPORT_FILE}
echo -e "Your score:\t\t${SCORE}" | tee -a ${REPORT_FILE}
echo -e "\n" | tee -a ${REPORT_FILE}

if [[ $SCORE -ge $PASS_SCORE ]]; then
    echo -e "${COLOR_OK}Result: PASS${COLOR_RESET}" | tee -a ${REPORT_FILE}
    echo -e "\n${COLOR_OK}CONGRATULATIONS!!${COLOR_RESET}\t You passed this practice test (Score >= ${PASS_THRESHOLD_PERCENT}%)."
    echo -e "\t\t\t Remember, this is practice; the real exam may differ."
else
    echo -e "${COLOR_FAIL}Result: NO PASS${COLOR_RESET}" | tee -a ${REPORT_FILE}
    echo -e "\n${COLOR_FAIL}[FAIL]${COLOR_RESET}\t\t You did NOT pass this practice test (Score < ${PASS_THRESHOLD_PERCENT}%)."
    echo -e "\t\t\t Review the [FAIL] messages and objective scores in ${REPORT_FILE}."
fi
echo -e "\nFull report saved to ${REPORT_FILE}"