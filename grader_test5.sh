#!/bin/bash
# Grader script - Batch 15 (Based on Mock Test 5)
# Version: 2024-03-10

# --- Configuration ---
REPORT_FILE="/tmp/exam-report-batch15.txt"
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
    [1]=3  # Operate (tuned)
    [2]=5  # FSConfig (setgid dir) + Users/Groups
    [3]=2  # Scripts (bash script, loops)
    [4]=4  # Local Storage (RAID - mdadm) + FSConfig (mkfs, mount, fstab)
    [5]=6  # Deploy/Maintain (environment variables)
    [6]=8  # Users/Groups (useradd) + Security (sshd config)
    [7]=4  # Local Storage (Stratis) + FSConfig (mount, snapshot)
    [8]=6  # Deploy/Maintain (vsftpd install/config) + Security (firewall)
    [9]=3  # Operate (rsyslog config)
    [10]=1 # Tools (find)
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

check_file_content() {
    local target_path="$1"
    local pattern="$2"
    local points_ok="$3"
    local points_fail="$4"
    local grep_opts="$5"
    if [ ! -f "$target_path" ]; then
        echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Cannot check content, file '$target_path' does not exist." | tee -a ${REPORT_FILE}
        return $points_fail
    fi
    if grep ${grep_opts} -- "${pattern}" "$target_path" &>/dev/null; then
        echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t File '$target_path' contains expected pattern '${pattern}'." | tee -a ${REPORT_FILE}
        return $points_ok
    else
        echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t File '$target_path' does not contain expected pattern '${pattern}'." | tee -a ${REPORT_FILE}
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
echo "Starting Grade Evaluation Batch 15 - $(date)" | tee -a ${REPORT_FILE}
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

### TASK 1: Set Tuned Profile to powersave
CURRENT_TASK=1; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Set Tuned Profile to powersave${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
EXPECTED_PROFILE="powersave"
if tuned-adm active | grep -q "$EXPECTED_PROFILE"; then
    T_SCORE=30
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Active tuned profile is '$EXPECTED_PROFILE'."
else
    echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Active tuned profile is not '$EXPECTED_PROFILE' (Found: $(tuned-adm active | awk '/Current active profile:/ {print $4}'))."
fi
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 2: Shared Directory /home/admins (adminuser) - Rehash
CURRENT_TASK=2; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Shared Directory /home/admins (adminuser) - Rehash${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
DIR_2="/home/admins"; GROUP_NAME_2="adminuser"
TASK_POINTS=0
# Check group exists
if ! getent group $GROUP_NAME_2 &>/dev/null; then groupadd $GROUP_NAME_2; echo -e "${COLOR_FAIL}[INFO]${COLOR_RESET}\t Group '$GROUP_NAME_2' created."; else echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Group '$GROUP_NAME_2' exists."; fi
# Check directory exists
check_file_exists "$DIR_2" 5 0; T_SUB_SCORE=$?; TASK_POINTS=$((TASK_POINTS + T_SUB_SCORE))
if [[ $T_SUB_SCORE -eq 5 ]]; then
    # Check group owner
    if [[ $(stat -c %G "$DIR_2") == "$GROUP_NAME_2" ]]; then TASK_POINTS=$((TASK_POINTS + 5)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Directory group owner is '$GROUP_NAME_2'."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Directory group owner is not '$GROUP_NAME_2'."; fi
    # Check permissions (rwxrws--- : 2770 allows group rwx + SGID)
    PERMS_OCT_2=$(stat -c %a "$DIR_2")
    if [[ "$PERMS_OCT_2" == "2770" ]]; then TASK_POINTS=$((TASK_POINTS + 20)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Permissions are 2770 (group rwx + SGID).";
    elif [[ -g "$DIR_2" ]]; then TASK_POINTS=$((TASK_POINTS + 5)); echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t SGID set, but permissions ($PERMS_OCT_2) not 2770.";
    else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Permissions ($PERMS_OCT_2) and/or SGID incorrect (expected 2770)."; fi
else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Directory '$DIR_2' does not exist."; fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 3: multilines.sh Script
CURRENT_TASK=3; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: multilines.sh Script${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
# Ensure user coder and dir exist
id coder &>/dev/null || useradd -m coder
SCRIPT_DIR="/home/coder"; SCRIPT_PATH="$SCRIPT_DIR/multilines.sh"
mkdir -p "$SCRIPT_DIR"; chown coder:coder "$SCRIPT_DIR"
TASK_POINTS=0
check_file_exists "$SCRIPT_PATH" 10 0; T_SUB_SCORE=$?; TASK_POINTS=$((TASK_POINTS + T_SUB_SCORE))
if [[ $T_SUB_SCORE -eq 10 ]]; then
     if [ -x "$SCRIPT_PATH" ]; then
          TASK_POINTS=$((TASK_POINTS + 10))
          echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Script '$SCRIPT_PATH' is executable."
          # Test script output
          OUTPUT_3=$("$SCRIPT_PATH" 2>&1)
          if [[ $(echo "$OUTPUT_3" | wc -l) -eq 3 ]] && \
             echo "$OUTPUT_3" | sed -n '1p' | grep -q "test1" && \
             echo "$OUTPUT_3" | sed -n '2p' | grep -q "test2" && \
             echo "$OUTPUT_3" | sed -n '3p' | grep -q "test3"; then
               TASK_POINTS=$((TASK_POINTS + 10))
               echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Script output is correct (test1, test2, test3 on separate lines)."
          else
               echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Script output incorrect. Expected test1\\ntest2\\ntest3. Got:\n$OUTPUT_3"
          fi
     else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Script '$SCRIPT_PATH' is not executable."; fi
fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 4: Create RAID1 Array /dev/md0
CURRENT_TASK=4; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Create RAID1 Array /dev/md0${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
RAID_DEVICE="/dev/md0"; MOUNT_POINT_4="/raid1"; DISK1="/dev/nvme1n1"; DISK2="/dev/nvme2n1"
TASK_POINTS=0
# Check mdadm installed
if ! rpm -q mdadm &>/dev/null; then dnf install -y mdadm &>/dev/null; fi
# Check RAID device exists and is active
if [ -b "$RAID_DEVICE" ] && mdadm --detail "$RAID_DEVICE" &>/dev/null; then
    TASK_POINTS=$((TASK_POINTS + 10))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t RAID device '$RAID_DEVICE' exists and is active."
    # Check RAID level and components
    if mdadm --detail "$RAID_DEVICE" | grep -q 'Raid Level : raid1' && \
       mdadm --detail "$RAID_DEVICE" | grep -q "$DISK1" && \
       mdadm --detail "$RAID_DEVICE" | grep -q "$DISK2"; then
        TASK_POINTS=$((TASK_POINTS + 10))
        echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t RAID level is raid1 and contains correct member disks."
    else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t RAID level or member disks incorrect."; fi
    # Check mount point and persistent mount
    check_mount "$MOUNT_POINT_4" "$RAID_DEVICE" "ext4\|xfs" "defaults" 10 0; T_SUB_SCORE=$?; TASK_POINTS=$((TASK_POINTS + T_SUB_SCORE))
    # Check fstab entry exists (as specified in answer)
    if ! grep -Fw "$MOUNT_POINT_4" /etc/fstab | grep "$RAID_DEVICE" &>/dev/null; then
         echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t fstab entry missing or incorrect for '$MOUNT_POINT_4'.";
         if [[ $T_SUB_SCORE -eq 10 ]]; then TASK_POINTS=$((TASK_POINTS - 5)); fi # Deduct if mount ok but fstab bad
    fi
else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t RAID device '$RAID_DEVICE' not found or inactive."; fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 5: System-wide Environment Variable EXAM=redhat
CURRENT_TASK=5; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Environment Variable EXAM=redhat${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
ENV_VAR_NAME="EXAM"; ENV_VAR_VALUE="redhat"
TASK_POINTS=0
# Check /etc/environment
if grep -Eq "^\s*${ENV_VAR_NAME}\s*=\s*['\"]?${ENV_VAR_VALUE}['\"]?\s*$" /etc/environment; then
    TASK_POINTS=$((TASK_POINTS + 15))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Found $ENV_VAR_NAME=$ENV_VAR_VALUE in /etc/environment."
else
    echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t $ENV_VAR_NAME=$ENV_VAR_VALUE not found in /etc/environment."
fi
# Check /etc/profile sourcing /etc/environment or setting it directly
# This check is less precise as sourcing methods can vary
if grep -Eq "^\s*(\.|source)\s+/etc/environment" /etc/profile || \
   grep -Eq "^\s*export\s+${ENV_VAR_NAME}\s*=\s*['\"]?${ENV_VAR_VALUE}['\"]?\s*$" /etc/profile /etc/profile.d/*.sh; then
    TASK_POINTS=$((TASK_POINTS + 15))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t /etc/profile appears to source /etc/environment or set $ENV_VAR_NAME."
else
    echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t /etc/profile does not appear to source /etc/environment or set $ENV_VAR_NAME."
fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}


### TASK 6: Create user Tom, Restrict SSH access
CURRENT_TASK=6; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Create user Tom, Restrict SSH access${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
USER_TOM="Tom" # Case sensitive
TASK_POINTS=0
# Check user exists and password set
if id "$USER_TOM" &>/dev/null; then TASK_POINTS=$((TASK_POINTS + 5)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t User '$USER_TOM' exists."; else useradd "$USER_TOM"; echo -e "${COLOR_FAIL}[INFO]${COLOR_RESET}\t User '$USER_TOM' created."; fi
if grep "^${USER_TOM}:" /etc/shadow | cut -d: -f2 | grep -q '^\$.*'; then TASK_POINTS=$((TASK_POINTS + 5)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Password for '$USER_TOM' appears set."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Password for '$USER_TOM' not set."; fi
# Check sshd_config for AllowUsers
if grep -Eq "^\s*AllowUsers\s+${USER_TOM}\s*$" /etc/ssh/sshd_config; then
    TASK_POINTS=$((TASK_POINTS + 20))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t AllowUsers $USER_TOM found in sshd_config."
else
    echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t AllowUsers $USER_TOM not found or incorrect in sshd_config."
fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 7: Stratis Pool, Filesystem, Mount, Snapshot
CURRENT_TASK=7; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Stratis Pool, Filesystem, Mount, Snapshot${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
POOL_NAME_7="redhat"; DISK_7="/dev/nvme1n1"; FS_NAME_7="rhcsa"; MOUNT_POINT_7="/guru"; SNAP_NAME_7="rhcsa-snap"
TASK_POINTS=0
# Check stratisd service
if systemctl is-active stratisd --quiet && systemctl is-enabled stratisd --quiet; then TASK_POINTS=$((TASK_POINTS + 3)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t stratisd running/enabled."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t stratisd not running/enabled."; fi
# Check pool exists
if stratis pool list | grep -qw "$POOL_NAME_7"; then TASK_POINTS=$((TASK_POINTS + 3)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Pool '$POOL_NAME_7' exists."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Pool '$POOL_NAME_7' not found."; fi
# Check filesystem exists in pool
if stratis filesystem list "$POOL_NAME_7" 2>/dev/null | grep -qw "$FS_NAME_7"; then TASK_POINTS=$((TASK_POINTS + 4)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Filesystem '$FS_NAME_7' exists in pool '$POOL_NAME_7'."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Filesystem '$FS_NAME_7' not found in pool '$POOL_NAME_7'."; fi
# Check mount point exists and is mounted persistently
FS_UUID_7=$(stratis filesystem list "$POOL_NAME_7" -n "$FS_NAME_7" --output=json 2>/dev/null | jq -r '.[].Uuid')
if [[ -n "$FS_UUID_7" ]]; then
    check_mount "$MOUNT_POINT_7" "UUID=$FS_UUID_7" "xfs" "defaults" 10 0; T_SUB_SCORE=$?; TASK_POINTS=$((TASK_POINTS + T_SUB_SCORE))
    # Check fstab entry
    if ! grep -Fw "$MOUNT_POINT_7" /etc/fstab | grep "UUID=$FS_UUID_7" &>/dev/null; then
         echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t fstab entry missing/incorrect for Stratis FS '$MOUNT_POINT_7'.";
         if [[ $T_SUB_SCORE -eq 10 ]]; then TASK_POINTS=$((TASK_POINTS - 5)); fi # Deduct points
    fi
else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Could not get UUID for Stratis filesystem '$FS_NAME_7'."; fi
# Check snapshot exists
if stratis filesystem list "$POOL_NAME_7" 2>/dev/null | grep -qw "$SNAP_NAME_7"; then TASK_POINTS=$((TASK_POINTS + 10)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Snapshot '$SNAP_NAME_7' exists."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Snapshot '$SNAP_NAME_7' not found."; fi

T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}


### TASK 8: Configure vsftpd Anonymous Download
CURRENT_TASK=8; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Configure vsftpd Anonymous Download${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
FTP_PUB_DIR="/var/ftp/pub"; TEST_FILE="$FTP_PUB_DIR/testfile.txt"
TASK_POINTS=0
# Check package, service status
if rpm -q vsftpd &>/dev/null; then TASK_POINTS=$((TASK_POINTS + 5)); else dnf install -y vsftpd &>/dev/null; echo -e "${COLOR_FAIL}[INFO]${COLOR_RESET}\t vsftpd installed."; fi
check_service_status vsftpd active 5 0; T_SUB_SCORE=$?; TASK_POINTS=$((TASK_POINTS + T_SUB_SCORE))
check_service_status vsftpd enabled 5 0; T_SUB_SCORE=$?; TASK_POINTS=$((TASK_POINTS + T_SUB_SCORE))
# Check anonymous enable setting
if grep -Eq '^\s*anonymous_enable\s*=\s*YES' /etc/vsftpd/vsftpd.conf; then TASK_POINTS=$((TASK_POINTS + 5)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t anonymous_enable=YES found."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t anonymous_enable=YES not found."; fi
# Check pub directory and test file
check_file_exists "$TEST_FILE" 5 0; T_SUB_SCORE=$?; TASK_POINTS=$((TASK_POINTS + T_SUB_SCORE))
# Check firewall allows ftp
if firewall-cmd --list-services --permanent 2>/dev/null | grep -qw ftp ; then TASK_POINTS=$((TASK_POINTS + 5)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Firewall allows 'ftp'."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Firewall doesn't allow 'ftp'."; fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 9: Configure rsyslog for daemon facility
CURRENT_TASK=9; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Configure rsyslog for daemon facility${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
TARGET_LOG_9="/var/log/daemonlog.log"
RSYSLOG_CONF="/etc/rsyslog.conf" # Or /etc/rsyslog.d/*.conf
TASK_POINTS=0
# Check rsyslog active
check_service_status rsyslog active 5 0; T_SUB_SCORE=$?; TASK_POINTS=$((TASK_POINTS + T_SUB_SCORE))
# Check configuration file for daemon.* rule pointing ONLY to the target file
# This is tricky to check perfectly, look for the specific line and maybe absence of daemon elsewhere
if grep -Eq "^\s*daemon\.\*\s+-?${TARGET_LOG_9}" $RSYSLOG_CONF /etc/rsyslog.d/*.conf; then
    TASK_POINTS=$((TASK_POINTS + 15))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Found rsyslog rule for daemon.* facility logging to '$TARGET_LOG_9'."
else
    echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Did not find rsyslog rule for daemon.* facility logging to '$TARGET_LOG_9'."
fi
# Check target log file exists
check_file_exists "$TARGET_LOG_9" 10 0; T_SUB_SCORE=$?; TASK_POINTS=$((TASK_POINTS + T_SUB_SCORE))
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 10: Find files by size range
CURRENT_TASK=10; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Find files by size range${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
TARGET_FILE_10="/home/coder/workspace/search.txt"
# Ensure dirs exist
mkdir -p /home/coder/workspace; chown coder:coder /home/coder /home/coder/workspace
# Create dummy files for test
dd if=/dev/zero of=/usr/share/test_35k_file bs=1k count=35 &>/dev/null
dd if=/dev/zero of=/usr/share/test_55k_file bs=1k count=55 &>/dev/null
TASK_POINTS=0
check_file_exists "$TARGET_FILE_10" 10 0; T_SUB_SCORE=$?; TASK_POINTS=$((TASK_POINTS + T_SUB_SCORE))
if [[ $T_SUB_SCORE -eq 10 ]]; then
    # Check content - should contain 35k file, should NOT contain 55k file
    if grep -q "/usr/share/test_35k_file" "$TARGET_FILE_10" && ! grep -q "/usr/share/test_55k_file" "$TARGET_FILE_10"; then
        TASK_POINTS=$((TASK_POINTS + 20))
        echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Target file '$TARGET_FILE_10' exists and contains correct size-based results."
    else
        echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Target file '$TARGET_FILE_10' content seems incorrect based on size filters."
    fi
fi
rm -f /usr/share/test_35k_file /usr/share/test_55k_file # Cleanup dummy files
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