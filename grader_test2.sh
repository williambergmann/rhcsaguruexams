#!/bin/bash
# Grader script - Batch 12 (Based on Mock Test 2)
# Version: 2024-03-10

# --- Configuration ---
REPORT_FILE="/tmp/exam-report-batch12.txt"
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
    [1]=9  # Security (sshd config)
    [2]=6  # Deploy/Maintain (NTP client)
    [3]=8  # Users/Groups (useradd, passwd) + Scripts (login script)
    [4]=1  # Tools (grep, redirection)
    [5]=1  # Tools (touch, chmod)
    [6]=3  # Operate (timezone) + Tools (tar)
    [7]=9  # Security (SELinux mode) + Operate (tuned)
    [8]=8  # Users/Groups (useradd, chage) + Security (pwquality)
    [9]=8  # Users/Groups (useradd, groupadd, usermod)
    [10]=8 # Users/Groups (groupadd, usermod) + Tools (touch, chown, chmod)
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
echo "Starting Grade Evaluation Batch 12 - $(date)" | tee -a ${REPORT_FILE}
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
    # Continue grading but warn user
fi
echo -e "\n" | tee -a ${REPORT_FILE}
# --- Task Evaluation ---

### TASK 1: Configure SSHD Password Auth
CURRENT_TASK=1; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Configure SSHD Password Auth${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
TASK_POINTS=0
check_service_status sshd active 10 0; T_SUB_SCORE=$?; TASK_POINTS=$((TASK_POINTS + T_SUB_SCORE))
# Check config file setting (uncommented and set to yes)
if grep -Eq '^\s*PasswordAuthentication\s+yes' /etc/ssh/sshd_config; then
    TASK_POINTS=$((TASK_POINTS + 20))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t PasswordAuthentication yes found and uncommented in sshd_config."
else
    echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t PasswordAuthentication yes not found or is commented out in sshd_config."
fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 2: Configure NTP Client (chrony)
CURRENT_TASK=2; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Configure NTP Client (time.google.com)${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
NTP_SERVER="time.google.com" # Needs DNS working
TASK_POINTS=0
check_service_status chronyd active 5 0; T_SUB_SCORE=$?; TASK_POINTS=$((TASK_POINTS + T_SUB_SCORE))
check_service_status chronyd enabled 5 0; T_SUB_SCORE=$?; TASK_POINTS=$((TASK_POINTS + T_SUB_SCORE))
# Check configuration for the specified server
if grep -Eq "^\s*(server|pool)\s+${NTP_SERVER}" /etc/chrony.conf || chronyc sources 2>/dev/null | grep -q "$NTP_SERVER"; then
    TASK_POINTS=$((TASK_POINTS + 20))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Time server '$NTP_SERVER' found in chrony configuration or sources."
else
    echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Time server '$NTP_SERVER' not found in /etc/chrony.conf or active sources."
fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 3: User Micky, Password, Login Script
CURRENT_TASK=3; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: User Micky, Password, Login Script${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
USER_MICKY="Micky" # Case sensitive
SCRIPT_PATH="/usr/local/bin/rhcsa"
TASK_POINTS=0
# Check user exists
if id "$USER_MICKY" &>/dev/null; then
    TASK_POINTS=$((TASK_POINTS + 5))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t User '$USER_MICKY' exists."
else
    useradd "$USER_MICKY" # Create if not exists for later checks
    echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t User '$USER_MICKY' does not exist (created for checks)."
fi
# Check password set
if grep "^${USER_MICKY}:" /etc/shadow | cut -d: -f2 | grep -q '^\$.*'; then
    TASK_POINTS=$((TASK_POINTS + 5))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Password for '$USER_MICKY' appears set."
else
    echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Password for '$USER_MICKY' not set."; fi
# Check script exists and executable
if [ -f "$SCRIPT_PATH" ] && [ -x "$SCRIPT_PATH" ]; then
    TASK_POINTS=$((TASK_POINTS + 10))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Script '$SCRIPT_PATH' exists and is executable."
else
    echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Script '$SCRIPT_PATH' missing or not executable."; fi
# Check .bashrc config
MICKY_BASHRC="/home/${USER_MICKY}/.bashrc"
if [ -f "$MICKY_BASHRC" ] && grep -Fq "$SCRIPT_PATH" "$MICKY_BASHRC"; then
    TASK_POINTS=$((TASK_POINTS + 10))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Script path found in '$MICKY_BASHRC'."
else
    echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Script path not found in '$MICKY_BASHRC'."
fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 4: Grep 'error' from messages log
CURRENT_TASK=4; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Grep 'error' from messages log${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
SOURCE_LOG="/var/log/messages"
TARGET_LOG="/tmp/errors.log"
rm -f $TARGET_LOG # Clean previous
# Create dummy error in source for test
echo "$(date) Host kernel: This is a test error line" >> "$SOURCE_LOG"
# Check target file exists
check_file_exists "$TARGET_LOG" 10 0; T_SUB_SCORE=$?
if [[ $T_SUB_SCORE -eq 10 ]]; then
    T_SCORE=$(( T_SCORE + T_SUB_SCORE ))
    # Check content (contains 'error', does not contain 'info', is not empty)
    if grep -qi 'error' "$TARGET_LOG" && ! grep -qi 'info' "$TARGET_LOG" && [ -s "$TARGET_LOG" ]; then
        echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Target file '$TARGET_LOG' exists and contains 'error' lines." | tee -a ${REPORT_FILE}
        T_SCORE=$(( T_SCORE + 20 ))
    else
        echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Target file '$TARGET_LOG' exists but content seems incorrect or empty." | tee -a ${REPORT_FILE}
    fi
fi
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 5: Create file and set permissions (755)
CURRENT_TASK=5; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Create file and set permissions (755)${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
TARGET_FILE_5="/home/testfile"
rm -f $TARGET_FILE_5 # Clean previous
# Check file existence
check_file_exists "$TARGET_FILE_5" 10 0; T_SUB_SCORE=$?
if [[ $T_SUB_SCORE -eq 10 ]]; then
    T_SCORE=$(( T_SCORE + T_SUB_SCORE ))
    # Check permissions (755 = rwxr-xr-x)
    PERMS_OCT_5=$(stat -c %a "$TARGET_FILE_5")
    if [[ "$PERMS_OCT_5" == "755" ]]; then
        echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Permissions on '$TARGET_FILE_5' are 755." | tee -a ${REPORT_FILE}
        T_SCORE=$(( T_SCORE + 20 ))
    else
         echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Permissions on '$TARGET_FILE_5' are $PERMS_OCT_5, expected 755." | tee -a ${REPORT_FILE}
    fi
fi
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 6: Set Timezone and Archive /var/tmp
CURRENT_TASK=6; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Set Timezone and Archive /var/tmp${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
EXPECTED_TZ="America/New_York"
ARCHIVE_FILE_6="/root/test.tar.gz"
TASK_POINTS=0
# Check timezone
if timedatectl status | grep -q "Time zone: ${EXPECTED_TZ}"; then
    TASK_POINTS=$((TASK_POINTS + 15))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Timezone set correctly to $EXPECTED_TZ."
else
    echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Timezone not set to $EXPECTED_TZ."
fi
# Check archive file
rm -f $ARCHIVE_FILE_6 # Clean previous
mkdir -p /var/tmp/subdir_test # Ensure var/tmp exists and has content
touch /var/tmp/file_test
check_file_exists "$ARCHIVE_FILE_6" 5 0; T_SUB_SCORE=$?
if [[ $T_SUB_SCORE -eq 5 ]]; then
    TASK_POINTS=$(( TASK_POINTS + T_SUB_SCORE ))
    # Check if valid gzip tarball containing var/tmp structure
    if tar tfz "$ARCHIVE_FILE_6" &>/dev/null && tar tfz "$ARCHIVE_FILE_6" | grep -q 'var/tmp/file_test'; then
         TASK_POINTS=$(( TASK_POINTS + 10 ))
         echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Archive '$ARCHIVE_FILE_6' is valid gzip tar and contains expected paths."
    else
         echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Archive '$ARCHIVE_FILE_6' is not valid gzip tar or content structure wrong."
    fi
fi
rm -rf /var/tmp/subdir_test /var/tmp/file_test # Clean dummy content
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 7: SELinux Permissive Mode and Tuned Profile
CURRENT_TASK=7; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: SELinux Permissive Mode and Tuned Profile${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
EXPECTED_TUNED="balanced"
TASK_POINTS=0
# Check SELinux runtime mode
if getenforce | grep -iq permissive; then
    TASK_POINTS=$((TASK_POINTS + 15))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t SELinux is currently in Permissive mode."
else
    echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t SELinux is not currently in Permissive mode (Found: $(getenforce))."
fi
# Check active tuned profile
if tuned-adm active | grep -q "$EXPECTED_TUNED"; then
    TASK_POINTS=$((TASK_POINTS + 15))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Active tuned profile is '$EXPECTED_TUNED'."
else
    echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Active tuned profile is not '$EXPECTED_TUNED' (Found: $(tuned-adm active | awk '/Current active profile:/ {print $4}'))."
fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 8: User coder, Password Expiry, Password Length
CURRENT_TASK=8; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: User coder, Password Expiry, Password Length${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
USER_CODER="coder"
PWQUALITY_CONF="/etc/security/pwquality.conf"
TASK_POINTS=0
# Check user exists
if ! id "$USER_CODER" &>/dev/null; then useradd "$USER_CODER"; echo -e "${COLOR_FAIL}[INFO]${COLOR_RESET}\t User '$USER_CODER' created for check."; else echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t User '$USER_CODER' exists."; fi
# Check password expiry (Max days = 90)
if chage -l "$USER_CODER" | grep -q "Maximum number of days between password change\s*:\s*90"; then
    TASK_POINTS=$((TASK_POINTS + 15))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Password maximum age for '$USER_CODER' is 90 days."
else
     echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Password maximum age for '$USER_CODER' is not 90 days."
fi
# Check password minimum length
if [ -f "$PWQUALITY_CONF" ] && grep -Eq '^\s*minlen\s*=\s*10' "$PWQUALITY_CONF"; then
    TASK_POINTS=$((TASK_POINTS + 15))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Minimum password length (minlen) is set to 10 in '$PWQUALITY_CONF'."
else
     echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Minimum password length (minlen) not found or not set to 10 in '$PWQUALITY_CONF'."
fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 9: Create Users and Groups (dev/mgr)
CURRENT_TASK=9; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Create Users and Groups (dev/mgr)${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
TASK_POINTS=0
# Check users exist
USERS_OK=true
for user in Alex Bob Charlie David; do if ! id "$user" &>/dev/null; then useradd "$user"; echo -e "${COLOR_FAIL}[INFO]${COLOR_RESET}\t User '$user' created."; USERS_OK=false; fi; done
if $USERS_OK; then TASK_POINTS=$((TASK_POINTS + 5)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t All required users exist."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t One or more users missing."; fi
# Check groups exist
GROUPS_OK=true
for group in developers managers; do if ! getent group "$group" &>/dev/null; then groupadd "$group"; echo -e "${COLOR_FAIL}[INFO]${COLOR_RESET}\t Group '$group' created."; GROUPS_OK=false; fi; done
if $GROUPS_OK; then TASK_POINTS=$((TASK_POINTS + 5)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t All required groups exist."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t One or more groups missing."; fi
# Check memberships
MEMBERS_OK=true
if ! id -nG Alex | grep -qw developers; then MEMBERS_OK=false; echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Alex not in developers."; fi
if ! id -nG Bob | grep -qw developers; then MEMBERS_OK=false; echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Bob not in developers."; fi
if ! id -nG Charlie | grep -qw managers; then MEMBERS_OK=false; echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Charlie not in managers."; fi
if ! id -nG David | grep -qw managers; then MEMBERS_OK=false; echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t David not in managers."; fi
if $MEMBERS_OK; then TASK_POINTS=$((TASK_POINTS + 20)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t All group memberships correct."; fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 10: Group friends, File ownership/permissions
CURRENT_TASK=10; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Group friends, File ownership/permissions${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
GROUP_FRIENDS="friends"; USER_ALEX="Alex"; USER_BOB="Bob"; TARGET_FILE_10="/home/friendsCircle"
TASK_POINTS=0
# Check group and users
if ! getent group "$GROUP_FRIENDS" &>/dev/null; then groupadd "$GROUP_FRIENDS"; echo -e "${COLOR_FAIL}[INFO]${COLOR_RESET}\t Group '$GROUP_FRIENDS' created."; fi
if ! id "$USER_ALEX" &>/dev/null; then useradd "$USER_ALEX"; echo -e "${COLOR_FAIL}[INFO]${COLOR_RESET}\t User '$USER_ALEX' created."; fi
if ! id "$USER_BOB" &>/dev/null; then useradd "$USER_BOB"; echo -e "${COLOR_FAIL}[INFO]${COLOR_RESET}\t User '$USER_BOB' created."; fi
# Check memberships
MEMBERS_OK_10=true
if ! id -nG "$USER_ALEX" | grep -qw "$GROUP_FRIENDS"; then MEMBERS_OK_10=false; echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t $USER_ALEX not in $GROUP_FRIENDS."; fi
if ! id -nG "$USER_BOB" | grep -qw "$GROUP_FRIENDS"; then MEMBERS_OK_10=false; echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t $USER_BOB not in $GROUP_FRIENDS."; fi
if $MEMBERS_OK_10; then TASK_POINTS=$((TASK_POINTS + 5)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Users are members of '$GROUP_FRIENDS'."; fi
# Check file exists
check_file_exists "$TARGET_FILE_10" 5 0; T_SUB_SCORE=$?; TASK_POINTS=$((TASK_POINTS + T_SUB_SCORE))
if [[ $T_SUB_SCORE -eq 5 ]]; then
    # Check owner
    if [[ $(stat -c %U "$TARGET_FILE_10") == "$USER_ALEX" ]]; then TASK_POINTS=$((TASK_POINTS + 5)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t File owner is '$USER_ALEX'."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t File owner is not '$USER_ALEX'."; fi
    # Check group owner
    if [[ $(stat -c %G "$TARGET_FILE_10") == "$GROUP_FRIENDS" ]]; then TASK_POINTS=$((TASK_POINTS + 5)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t File group owner is '$GROUP_FRIENDS'."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t File group owner is not '$GROUP_FRIENDS'."; fi
    # Check permissions (770 = rwxrwx--- assuming execute needed, 660 if not)
    PERMS_OCT_10=$(stat -c %a "$TARGET_FILE_10")
    if [[ "$PERMS_OCT_10" == "770" ]] || [[ "$PERMS_OCT_10" == "660" ]]; then TASK_POINTS=$((TASK_POINTS + 10)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t File permissions ($PERMS_OCT_10) grant owner/group access, deny others."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t File permissions ($PERMS_OCT_10) incorrect."; fi
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
        GRAND_TOTAL_POSSIBLE=$(( GRAND_TOTAL_POSSIBLE + OBJ_TOTAL_VAL )) # Accumulate total points possible from graded objectives
    fi
    printf " \t%-45s : %s%%\n" "$OBJ_NAME" "$PERCENT" | tee -a ${REPORT_FILE}
done
echo -e "\n------------------------------------------------" | tee -a ${REPORT_FILE}

# --- Calculate Overall Score ---
# Use accumulated total possible if less than MAX_SCORE (if some objectives had no tasks)
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