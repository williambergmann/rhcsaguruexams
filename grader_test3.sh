#!/bin/bash
# Grader script - Mock Test 3
# Version: 2025-04-17

# --- Configuration ---
REPORT_FILE="/tmp/exam-report-batch13.txt"
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
    [1]=8  # Users/Groups (useradd, groupadd, chage) + Security (sudoers)
    [2]=6  # Deploy/Maintain (skel, cron) + Users/Groups
    [3]=9  # Security (firewalld) + Operate (service status)
    [4]=2  # Scripts (bash script) + Tools (links)
    [5]=4  # Local Storage (Stratis) - Advanced Storage
    [6]=10 # Containers (pull, run, systemd service)
    [7]=10 # Containers (pull, run) + Deploy/Maintain (repo config, package install)
    [8]=7  # Networking (nmcli dummy, hostname)
    [9]=4  # Local Storage (pv, vg, lv) + FSConfig (mkfs, mount, fstab)
    [10]=4 # Local Storage (pv, vgextend, lvextend) + FSConfig (resizefs)
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
echo "Starting Grade Evaluation Batch 13 - $(date)" | tee -a ${REPORT_FILE}
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

### TASK 1: User Max, Group sysadmin, Sudo NOPASSWD, Expiry
CURRENT_TASK=1; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: User Max, Group sysadmin, Sudo NOPASSWD, Expiry${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
USER_MAX="Max" # Case sensitive
GROUP_SYSADMIN="sysadmin"
EXPIRY_DATE="2025-12-31" # Changed Q date format for consistency
TASK_POINTS=0
# Check user exists
if id "$USER_MAX" &>/dev/null; then TASK_POINTS=$((TASK_POINTS + 4)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t User '$USER_MAX' exists."; else useradd "$USER_MAX"; echo -e "${COLOR_FAIL}[INFO]${COLOR_RESET}\t User '$USER_MAX' created."; fi
# Check group exists
if getent group "$GROUP_SYSADMIN" &>/dev/null; then TASK_POINTS=$((TASK_POINTS + 4)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Group '$GROUP_SYSADMIN' exists."; else groupadd "$GROUP_SYSADMIN"; echo -e "${COLOR_FAIL}[INFO]${COLOR_RESET}\t Group '$GROUP_SYSADMIN' created."; fi
# Check sudoers entry for user (complex to parse exactly, check for NOPASSWD rule)
SUDO_USER_OK=false
if visudo -c -f /etc/sudoers &>/dev/null && grep -Eq "^\s*${USER_MAX}\s+ALL\s*=\s*\(ALL\)\s+NOPASSWD:\s*ALL" /etc/sudoers; then SUDO_USER_OK=true; fi
if ! $SUDO_USER_OK && [ -d /etc/sudoers.d ]; then
    if grep -Eq "^\s*${USER_MAX}\s+ALL\s*=\s*\(ALL\)\s+NOPASSWD:\s*ALL" /etc/sudoers.d/* &>/dev/null; then SUDO_USER_OK=true; fi
fi
if $SUDO_USER_OK; then TASK_POINTS=$((TASK_POINTS + 7)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Sudo NOPASSWD rule found for user '$USER_MAX'."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Sudo NOPASSWD rule for user '$USER_MAX' not found."; fi
# Check sudoers entry for group
SUDO_GROUP_OK=false
if visudo -c -f /etc/sudoers &>/dev/null && grep -Eq "^\s*%${GROUP_SYSADMIN}\s+ALL\s*=\s*\(ALL\)\s+NOPASSWD:\s*ALL" /etc/sudoers; then SUDO_GROUP_OK=true; fi
if ! $SUDO_GROUP_OK && [ -d /etc/sudoers.d ]; then
    if grep -Eq "^\s*%${GROUP_SYSADMIN}\s+ALL\s*=\s*\(ALL\)\s+NOPASSWD:\s*ALL" /etc/sudoers.d/* &>/dev/null; then SUDO_GROUP_OK=true; fi
fi
if $SUDO_GROUP_OK; then TASK_POINTS=$((TASK_POINTS + 7)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Sudo NOPASSWD rule found for group '$GROUP_SYSADMIN'."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Sudo NOPASSWD rule for group '$GROUP_SYSADMIN' not found."; fi
# Check expiry date
if chage -l "$USER_MAX" | grep -q "Account expires\s*:\s*Dec 31, 2025"; then # Format depends on locale, basic check
    TASK_POINTS=$((TASK_POINTS + 8))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Account expiry date for '$USER_MAX' appears correct."
else
    echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Account expiry date for '$USER_MAX' incorrect or not set (Found: $(chage -l $USER_MAX | grep 'Account expires')).";
fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 2: /etc/skel File and Max's Cron Job
CURRENT_TASK=2; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: /etc/skel File and Max's Cron Job${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
SKEL_FILE="/etc/skel/Todo.txt"
CRON_CMD_2='logger "Ex200 Testing"' # More precise check
CRON_SCHED_2="* * * * *"
CRON_USER_2="Max" # Assume user exists from Task 1
TASK_POINTS=0
# Check skel file
check_file_exists "$SKEL_FILE" 15 0; T_SUB_SCORE=$?; TASK_POINTS=$((TASK_POINTS + T_SUB_SCORE))
# Check Max's crontab
if crontab -l -u $CRON_USER_2 2>/dev/null | grep -Fq "$CRON_SCHED_2 $CRON_CMD_2"; then
    TASK_POINTS=$((TASK_POINTS + 15))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Found scheduled task for '$CRON_USER_2': '$CRON_SCHED_2 $CRON_CMD_2'"
else
    echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Did not find '$CRON_SCHED_2 $CRON_CMD_2' in '$CRON_USER_2''s crontab."
fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 3: Start firewalld and Allow HTTP
CURRENT_TASK=3; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Start firewalld and Allow HTTP${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
TASK_POINTS=0
check_service_status firewalld active 10 0; T_SUB_SCORE=$?; TASK_POINTS=$((TASK_POINTS + T_SUB_SCORE))
check_service_status firewalld enabled 5 0; T_SUB_SCORE=$?; TASK_POINTS=$((TASK_POINTS + T_SUB_SCORE))
# Check firewall rule for http service
if firewall-cmd --list-services --permanent 2>/dev/null | grep -qw http ; then
    TASK_POINTS=$((TASK_POINTS + 15))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Firewall permanently allows 'http' service."
else
    echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Firewall does not appear to allow 'http' service permanently."
fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 4: symlink.sh Script
CURRENT_TASK=4; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: symlink.sh Script${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
SCRIPT_PATH_4="/home/symlink.sh"
LINK_PATH="/home/jerry"
TARGET_PATH="/etc/passwd"
TASK_POINTS=0
rm -f $LINK_PATH # Ensure link doesn't exist initially for testing 'Created'
check_file_exists "$SCRIPT_PATH_4" 5 0; T_SUB_SCORE=$?
if [[ $T_SUB_SCORE -eq 5 ]]; then
    TASK_POINTS=$((TASK_POINTS + T_SUB_SCORE))
    if [ -x "$SCRIPT_PATH_4" ]; then
        TASK_POINTS=$((TASK_POINTS + 5))
        echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Script '$SCRIPT_PATH_4' is executable."
        # Test 'Created' case
        OUTPUT_CREATE=$("$SCRIPT_PATH_4" 2>&1)
        if [[ "$OUTPUT_CREATE" == "Created" ]] && [[ -L "$LINK_PATH" ]] && [[ $(readlink "$LINK_PATH") == "$TARGET_PATH" ]]; then
            TASK_POINTS=$((TASK_POINTS + 10))
            echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Script correctly output 'Created' and created the link."
            # Test 'Already existed' case
            OUTPUT_EXISTS=$("$SCRIPT_PATH_4" 2>&1)
            if [[ "$OUTPUT_EXISTS" == "Already existed" ]]; then
                 TASK_POINTS=$((TASK_POINTS + 10))
                 echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Script correctly output 'Already existed'."
            else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Script output incorrect when link exists (Output: $OUTPUT_EXISTS)."; fi
        else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Script did not output 'Created' or create link correctly (Output: $OUTPUT_CREATE)."; fi
    else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Script '$SCRIPT_PATH_4' is not executable."; fi
fi
rm -f $LINK_PATH # Cleanup link
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 5: Stratis Pool Create and Extend
CURRENT_TASK=5; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Stratis Pool Create and Extend${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
POOL_NAME="mypool"
DISK1="nvme1n1" # Assumes /dev/ prefix if needed by stratis command
DISK2="nvme2n1" # Assumes /dev/ prefix if needed by stratis command
TASK_POINTS=0
# Check stratisd service
if systemctl is-active stratisd --quiet && systemctl is-enabled stratisd --quiet; then
    TASK_POINTS=$((TASK_POINTS + 5))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t stratisd service is active and enabled."
else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t stratisd service is not active or enabled."; fi
# Check pool exists
if stratis pool list | grep -qw "$POOL_NAME"; then
    TASK_POINTS=$((TASK_POINTS + 10))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Stratis pool '$POOL_NAME' exists."
    # Check block devices in the pool
    BLOCKDEVS=$(stratis blockdev list "$POOL_NAME" --output=json 2>/dev/null | jq -r '.[].Devnode')
    DISK1_FOUND=false; DISK2_FOUND=false
    if echo "$BLOCKDEVS" | grep -q "$DISK1"; then DISK1_FOUND=true; fi
    if echo "$BLOCKDEVS" | grep -q "$DISK2"; then DISK2_FOUND=true; fi

    if $DISK1_FOUND && $DISK2_FOUND; then
        TASK_POINTS=$((TASK_POINTS + 15))
        echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Both '$DISK1' and '$DISK2' found in pool '$POOL_NAME'."
    elif $DISK1_FOUND; then
         echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Initial disk '$DISK1' found, but extension disk '$DISK2' not found in pool '$POOL_NAME'."
    else
        echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Required block devices ('$DISK1', '$DISK2') not found in pool '$POOL_NAME'."
    fi
else
    echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Stratis pool '$POOL_NAME' not found."
fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}


### TASK 6: Container as Systemd Service (logserver)
CURRENT_TASK=6; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Container as Systemd Service (logserver)${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
CONTAINER_NAME="logserver"
IMAGE_NAME="rhcsaguru/rsyslog" # Using exact name from Q
SERVICE_FILE="/etc/systemd/system/container-${CONTAINER_NAME}.service"
TASK_POINTS=0
# Check image pulled (allow for docker.io prefix)
if podman image exists "docker.io/${IMAGE_NAME}" || podman image exists "$IMAGE_NAME"; then
    TASK_POINTS=$((TASK_POINTS + 10))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Container image '$IMAGE_NAME' found locally."
else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Container image '$IMAGE_NAME' not found locally."; fi
# Check systemd unit file exists
check_file_exists "$SERVICE_FILE" 10 0; T_SUB_SCORE=$?; TASK_POINTS=$((TASK_POINTS + T_SUB_SCORE))
# Check service enabled and active
check_service_status "container-${CONTAINER_NAME}.service" enabled 5 0; T_SUB_SCORE=$?; TASK_POINTS=$((TASK_POINTS + T_SUB_SCORE))
check_service_status "container-${CONTAINER_NAME}.service" active 5 0; T_SUB_SCORE=$?; TASK_POINTS=$((TASK_POINTS + T_SUB_SCORE))
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 7: Container Local Repo
CURRENT_TASK=7; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Container Local Repo${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
IMAGE_REPO="rhcsaguru/local-repo"
CONTAINER_REPO="repo_server"
REPO_ID="local"
REPO_URL="http://localhost:80/"
PKG_TO_INSTALL="ngrep"
TASK_POINTS=0
# Check image pulled
if podman image exists "docker.io/${IMAGE_REPO}" || podman image exists "$IMAGE_REPO"; then TASK_POINTS=$((TASK_POINTS + 5)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Image '$IMAGE_REPO' exists."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Image '$IMAGE_REPO' not found."; fi
# Check container running and port mapped
if podman ps --filter name="^${CONTAINER_REPO}$" --format "{{.Names}}" | grep -q "$CONTAINER_REPO"; then
     if podman port "$CONTAINER_REPO" | grep -q '80/tcp -> 0.0.0.0:80'; then
         TASK_POINTS=$((TASK_POINTS + 5)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Container '$CONTAINER_REPO' running with port 80 mapped.";
     else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Container '$CONTAINER_REPO' running but port 80 not mapped correctly."; fi
else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Container '$CONTAINER_REPO' not running."; fi
# Check repo file configured
REPO_FILE="/etc/yum.repos.d/${REPO_ID}.repo" # Assuming simple name
if [ -f "$REPO_FILE" ] && grep -Eq "baseurl\s*=\s*${REPO_URL}" "$REPO_FILE" && grep -Eq "gpgcheck\s*=\s*0" "$REPO_FILE"; then
    TASK_POINTS=$((TASK_POINTS + 10)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Repo file '$REPO_FILE' configured correctly.";
else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Repo file '$REPO_FILE' missing or incorrect."; fi
# Check package installed
if rpm -q "$PKG_TO_INSTALL" &>/dev/null; then TASK_POINTS=$((TASK_POINTS + 10)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Package '$PKG_TO_INSTALL' is installed."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Package '$PKG_TO_INSTALL' not installed."; fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 8: Dummy Network Interface
CURRENT_TASK=8; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Dummy Network Interface${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
CONN_NAME="dummy0"; IFACE_NAME="dummy0"; IP4="192.168.1.42/24"; GW4="192.168.1.1"; DNS4="8.8.8.8"; HOSTNAME="dev.example.com"
TASK_POINTS=0
# Check hostname
if hostnamectl status | grep -q "Static hostname: ${HOSTNAME}"; then TASK_POINTS=$((TASK_POINTS + 5)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Hostname set to '$HOSTNAME'."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Hostname not set to '$HOSTNAME'."; fi
# Check connection profile exists
if nmcli con show "$CONN_NAME" &>/dev/null; then
    TASK_POINTS=$((TASK_POINTS + 5))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Connection profile '$CONN_NAME' exists."
    # Check settings within profile
    if nmcli -g connection.interface-name con show "$CONN_NAME" | grep -q "$IFACE_NAME"; then TASK_POINTS=$((TASK_POINTS + 3)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Interface name '$IFACE_NAME' correct."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Interface name incorrect."; fi
    if nmcli -g ipv4.method con show "$CONN_NAME" | grep -q "manual"; then TASK_POINTS=$((TASK_POINTS + 2)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t IPv4 method is manual."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t IPv4 method not manual."; fi
    if nmcli -g ipv4.addresses con show "$CONN_NAME" | grep -q "$IP4"; then TASK_POINTS=$((TASK_POINTS + 3)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t IP address '$IP4' correct."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t IP address incorrect."; fi
    if nmcli -g ipv4.gateway con show "$CONN_NAME" | grep -q "$GW4"; then TASK_POINTS=$((TASK_POINTS + 3)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Gateway '$GW4' correct."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Gateway incorrect."; fi
    if nmcli -g ipv4.dns con show "$CONN_NAME" | grep -q "$DNS4"; then TASK_POINTS=$((TASK_POINTS + 3)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t DNS '$DNS4' correct."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t DNS incorrect."; fi
    # Check if connection is active
    if nmcli con show --active | grep -q "$CONN_NAME"; then TASK_POINTS=$((TASK_POINTS + 6)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Connection '$CONN_NAME' is active."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Connection '$CONN_NAME' is not active."; fi
else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Connection profile '$CONN_NAME' not found."; fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 9: Create LVM vg/lv and mount
CURRENT_TASK=9; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Create LVM vg/lv and mount${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
VG_NAME="guruvg"; LV_NAME="gurulv"; PV_DEVICE="/dev/nvme1n1"; LV_SIZE="5100M"; MOUNT_POINT="/mymount"; FS_TYPE="ext4"
TASK_POINTS=0
# Check VG
if vgs "$VG_NAME" &>/dev/null; then TASK_POINTS=$((TASK_POINTS + 5)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t VG '$VG_NAME' exists."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t VG '$VG_NAME' not found."; fi
# Check LV
LV_PATH="/dev/${VG_NAME}/${LV_NAME}"
if lvs "$LV_PATH" &>/dev/null; then TASK_POINTS=$((TASK_POINTS + 5)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t LV '$LV_NAME' exists."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t LV '$LV_NAME' not found."; fi
# Check LV Size (approx 5100M -> 5000-5200M)
if [[ $TASK_POINTS -ge 10 ]]; then # Only check if LV exists
    LV_SIZE_MB=$(lvs --noheadings --units m -o lv_size $LV_PATH | sed 's/[^0-9.]*//g' | cut -d. -f1)
    if [[ $LV_SIZE_MB -ge 5000 ]] && [[ $LV_SIZE_MB -le 5200 ]]; then TASK_POINTS=$((TASK_POINTS + 5)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t LV size ${LV_SIZE_MB}M is correct."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t LV size ${LV_SIZE_MB}M is incorrect."; fi
fi
# Check Filesystem
if blkid "$LV_PATH" 2>/dev/null | grep -q "TYPE=\"${FS_TYPE}\""; then TASK_POINTS=$((TASK_POINTS + 5)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Filesystem is $FS_TYPE."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Filesystem is not $FS_TYPE."; fi
# Check Mount Point and Mount
check_mount "$MOUNT_POINT" "$LV_PATH" "$FS_TYPE" "defaults" 10 0; T_SUB_SCORE=$?; TASK_POINTS=$((TASK_POINTS + T_SUB_SCORE))
# Check fstab entry
if grep -Fw "$MOUNT_POINT" /etc/fstab | grep "$LV_PATH" | grep -w "$FS_TYPE" &>/dev/null; then echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Found fstab entry."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t fstab entry missing or incorrect."; TASK_POINTS=$((TASK_POINTS > 10 ? TASK_POINTS - 5 : 0)); fi # Deduct points if mount is OK but fstab wrong

T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 10: Extend LVM vg/lv
CURRENT_TASK=10; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Extend LVM vg/lv${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
VG_NAME="guruvg"; LV_NAME="gurulv"; PV_DEVICE_EXT="/dev/nvme2n1"; TARGET_LV_SIZE_GB=8; MOUNT_POINT="/mymount" # Reuse from Q9
TASK_POINTS=0
# Check PV added to VG
if pvs -o pv_name,vg_name | grep "$PV_DEVICE_EXT" | grep -qw "$VG_NAME"; then TASK_POINTS=$((TASK_POINTS + 10)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t PV '$PV_DEVICE_EXT' is part of VG '$VG_NAME'."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t PV '$PV_DEVICE_EXT' not found in VG '$VG_NAME'."; fi
# Check LV size (Exactly 8G)
LV_PATH="/dev/${VG_NAME}/${LV_NAME}"
if lvs "$LV_PATH" &>/dev/null; then
    LV_SIZE_GB=$(lvs --noheadings --units g -o lv_size "$LV_PATH" | sed 's/[^0-9.]*//g' | cut -d. -f1)
    if [[ "$LV_SIZE_GB" == "$TARGET_LV_SIZE_GB" ]]; then TASK_POINTS=$((TASK_POINTS + 10)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t LV size is correctly ${TARGET_LV_SIZE_GB}G."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t LV size is ${LV_SIZE_GB}G, expected ${TARGET_LV_SIZE_GB}G."; fi
    # Check Filesystem resize (approximate)
    if findmnt "$MOUNT_POINT" | grep -q "$LV_PATH"; then
        FS_SIZE_GB=$(df -BG --output=size ${MOUNT_POINT} 2>/dev/null | tail -n 1 | sed 's/[^0-9]*//g')
        if [[ $FS_SIZE_GB -ge $((TARGET_LV_SIZE_GB - 1)) ]] && [[ $FS_SIZE_GB -le $TARGET_LV_SIZE_GB ]]; then TASK_POINTS=$((TASK_POINTS + 10)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Filesystem appears resized (${FS_SIZE_GB}G)."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Filesystem size (${FS_SIZE_GB}G) doesn't match LV size."; fi
    else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t LV not mounted at '$MOUNT_POINT' to check FS size."; fi
else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t LV '$LV_NAME' not found."; fi

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
# Use accumulated total possible if less than MAX_SCORE
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
