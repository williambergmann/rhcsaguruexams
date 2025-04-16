#!/bin/bash
# Combined Grader Script - 10 Task Practice Set
# Version: 2024-03-10

# --- Practice Tasks ---
# Task 1: Create a cron job for root that appends "Hello_World" to /var/log/messages at 12:00 PM on weekdays (Mon-Fri).
# Task 2: Find the 'root' user entry in /etc/passwd, output it to /home/users_entry. Edit /home/users_entry to change root's shell from /bin/bash to /bin/sh.
# Task 3: Configure sshd to limit MaxAuthTries to 3. Configure /etc/login.defs so new user passwords expire after 20 days (PASS_MAX_DAYS 20). Ensure sshd service reflects changes.
# Task 4: Search for the 'redis' container image and pull the official image from default registries. Verify the image is stored locally.
# Task 5: Enable the SELinux boolean 'container_manage_cgroup' persistently (value 'on').
# Task 6: Add user 'expert' (UID 1500), home directory /home/expertDir, shell /bin/sh. Set a password.
# Task 7: Create group 'panel'. Create user 'dev'. Add 'dev' to 'panel' supplementary group. Set umask 0277 for user 'dev' persistently (e.g., in .bashrc).
# Task 8: Modify the system hostname persistently to 'dev'.
# Task 9: Create directory /home/example. Change its user ownership to 'expert'.
# Task 10: Install httpd. Create /var/www/html/index.html with "Hello World!". Configure httpd to listen on port 82. Allow port 82 via SELinux (http_port_t) and firewall. Ensure httpd is running and enabled.
# --- End Practice Tasks ---

# --- Configuration ---
REPORT_FILE="/tmp/exam-report-10tasks.txt"
PASS_THRESHOLD_PERCENT=70 # Percentage required to pass
MAX_SCORE=300

# --- Color Codes ---
COLOR_OK="\033[32m"
COLOR_FAIL="\033[31m"
COLOR_INFO="\033[1m"
COLOR_RESET="\033[0m"

# --- Objective Mapping ---
# Assign each task to a primary objective category number (1-10)
# 1=Tools, 2=Scripts, 3=Operate, 4=LocalStore, 5=FSConfig,
# 6=Deploy/Maintain, 7=Network, 8=Users/Groups, 9=Security, 10=Containers
declare -A TASK_OBJECTIVE=(
    [1]=6  # Deploy, configure, maintain (cron)
    [2]=1  # Essential tools (grep, sed)
    [3]=9  # Security (ssh config, login.defs)
    [4]=10 # Containers (search, pull)
    [5]=9  # Security (selinux boolean)
    [6]=8  # Users & Groups (useradd)
    [7]=8  # Users & Groups (groupadd, usermod, umask)
    [8]=7  # Networking (hostname)
    [9]=1  # Essential tools (mkdir, chown)
    [10]=6 # Deploy, configure, maintain (httpd, semanage port, firewall)
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

# Function to update scores (overall and by objective)
grade_task() {
    local task_num=$1
    local points_possible=$2
    local points_earned=$3
    local obj_index=${TASK_OBJECTIVE[$task_num]}

    SCORE=$(( SCORE + points_earned ))
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
echo "Starting Grade Evaluation - 10 Task Set - $(date)" | tee -a ${REPORT_FILE}
echo "------------------------------------------------" | tee -a ${REPORT_FILE}

# Initialize score variables
SCORE=0
TOTAL=0 # Total points *attempted* by the script

# --- Pre-check: SELinux ---
echo -e "${COLOR_INFO}Pre-check: SELinux Status${COLOR_RESET}" | tee -a ${REPORT_FILE}
if getenforce | grep -iq enforcing &>/dev/null; then
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t SELinux is in Enforcing mode." | tee -a ${REPORT_FILE}
else
    echo -e "${COLOR_FAIL}[FATAL]${COLOR_RESET}\t Task evaluation cannot proceed reliably because SELinux is not in enforcing mode. Set SELinux to enforcing mode ('setenforce 1' and check /etc/selinux/config) and try again." | tee -a ${REPORT_FILE}
    exit 666
fi
echo -e "\n" | tee -a ${REPORT_FILE}

# --- Task Evaluation ---

### TASK 1: Cron Job
CURRENT_TASK=1; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Cron Job (Hello_World)${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
CRON_CMD_1='echo "Hello_World" >> /var/log/messages'
CRON_SCHED_1="0 12 * * 1-5"
CRON_USER="root"
if crontab -l -u $CRON_USER 2>/dev/null | grep -Fq "$CRON_SCHED_1 $CRON_CMD_1" || \
   grep -Frq "$CRON_SCHED_1 $CRON_USER $CRON_CMD_1" /etc/cron.d/ /etc/crontab; then
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Found scheduled task: '$CRON_SCHED_1 ($CRON_USER) $CRON_CMD_1'" | tee -a ${REPORT_FILE}
    T_SCORE=30
else
    echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Did not find '$CRON_SCHED_1 $CRON_CMD_1' in '$CRON_USER''s crontab or system cron files." | tee -a ${REPORT_FILE}
fi
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 2: Find root entry and edit shell
CURRENT_TASK=2; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Find root entry and edit shell${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
USER_FILE="/home/users_entry"
rm -f $USER_FILE # Clean previous run
# Check file creation with root entry
grep -q '^root:' /etc/passwd > "$USER_FILE" # Simulate user action
if [ -f "$USER_FILE" ] && grep -q '^root:' "$USER_FILE"; then
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t '$USER_FILE' created and contains root entry." | tee -a ${REPORT_FILE}
    T_SCORE=$(( T_SCORE + 15 ))
    # Check if shell was modified to /bin/sh IN THE FILE
    if grep -q '^root:.*:/bin/sh$' "$USER_FILE"; then
         echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Shell for root in '$USER_FILE' is set to /bin/sh." | tee -a ${REPORT_FILE}
         T_SCORE=$(( T_SCORE + 15 ))
    else
         echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Shell for root in '$USER_FILE' was not modified to /bin/sh." | tee -a ${REPORT_FILE}
    fi
else
    echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Failed to create '$USER_FILE' or it doesn't contain root entry." | tee -a ${REPORT_FILE}
fi
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 3: SSH MaxAuthTries and Password Max Days
CURRENT_TASK=3; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: SSH Limits & Password Aging${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
TASK_POINTS=0
if grep -Eq '^\s*MaxAuthTries\s+3' /etc/ssh/sshd_config; then TASK_POINTS=$((TASK_POINTS + 15)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t MaxAuthTries 3 found."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t MaxAuthTries 3 not found."; fi
if grep -Eq '^\s*PASS_MAX_DAYS\s+20' /etc/login.defs; then TASK_POINTS=$((TASK_POINTS + 15)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t PASS_MAX_DAYS 20 found."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t PASS_MAX_DAYS 20 not found."; fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 4: Search and Pull Redis Image
CURRENT_TASK=4; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Search and Pull Redis Image${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
IMAGE_NAME="redis"
TASK_POINTS=0
# Check if podman exists
if ! command -v podman &> /dev/null; then dnf install -y container-tools &>/dev/null; fi
# Cannot reliably check 'search' output, so check pull success only
if podman image exists docker.io/library/redis:latest || podman image exists redis:latest || podman image exists redis; then
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Redis image found locally (pull successful)." | tee -a ${REPORT_FILE}
    TASK_POINTS=30
else
    echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Redis image not found locally." | tee -a ${REPORT_FILE}
fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 5: SELinux Boolean container_manage_cgroup
CURRENT_TASK=5; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: SELinux Boolean container_manage_cgroup${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
BOOLEAN_NAME="container_manage_cgroup"
TASK_POINTS=0
# Check running state
if getsebool "$BOOLEAN_NAME" | grep -q ' --> on$'; then TASK_POINTS=$((TASK_POINTS + 15)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Boolean '$BOOLEAN_NAME' is currently 'on'."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Boolean '$BOOLEAN_NAME' is currently 'off'."; fi
# Check persistent value
if semanage boolean -l | grep "^${BOOLEAN_NAME}\s*(" | grep -q '(on '; then TASK_POINTS=$((TASK_POINTS + 15)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Boolean '$BOOLEAN_NAME' persistent setting is 'on'."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Boolean '$BOOLEAN_NAME' persistent setting is 'off'."; fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 6: Create User expert
CURRENT_TASK=6; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Create User expert${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
USER_NAME="expert"; EXPECTED_UID=1500; EXPECTED_HOME="/home/expertDir"; EXPECTED_SHELL="/bin/sh"
TASK_POINTS=0
if id "$USER_NAME" &>/dev/null; then
    TASK_POINTS=$(( TASK_POINTS + 5 )); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t User '$USER_NAME' exists."
    if [[ $(id -u "$USER_NAME") == "$EXPECTED_UID" ]]; then TASK_POINTS=$(( TASK_POINTS + 5 )); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t UID is $EXPECTED_UID."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t UID is not $EXPECTED_UID."; fi
    if getent passwd "$USER_NAME" | cut -d: -f6 | grep -q "$EXPECTED_HOME"; then TASK_POINTS=$(( TASK_POINTS + 5 )); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Home is $EXPECTED_HOME."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Home is not $EXPECTED_HOME."; fi
    if getent passwd "$USER_NAME" | cut -d: -f7 | grep -q "$EXPECTED_SHELL"; then TASK_POINTS=$(( TASK_POINTS + 5 )); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Shell is $EXPECTED_SHELL."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Shell is not $EXPECTED_SHELL."; fi
    if grep "^${USER_NAME}:" /etc/shadow | cut -d: -f2 | grep -q '^\$.*'; then TASK_POINTS=$(( TASK_POINTS + 10 )); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Password is set."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Password not set."; fi
else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t User '$USER_NAME' does not exist."; fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 7: Group panel, User dev, umask
CURRENT_TASK=7; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Group panel, User dev, umask${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
GROUP_NAME="panel"; USER_NAME="dev"; EXPECTED_UMASK="0277" # umask 0277 gives file=400(r), dir=500(rx) as per Q
TASK_POINTS=0
if getent group "$GROUP_NAME" &>/dev/null; then TASK_POINTS=$(( TASK_POINTS + 5 )); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Group '$GROUP_NAME' exists."; else groupadd "$GROUP_NAME"; echo -e "${COLOR_FAIL}[INFO]${COLOR_RESET}\t Group '$GROUP_NAME' created."; fi
if id "$USER_NAME" &>/dev/null; then TASK_POINTS=$(( TASK_POINTS + 5 )); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t User '$USER_NAME' exists."; else useradd "$USER_NAME"; echo -e "${COLOR_FAIL}[INFO]${COLOR_RESET}\t User '$USER_NAME' created."; fi
if id -nG "$USER_NAME" | grep -qw "$GROUP_NAME"; then TASK_POINTS=$(( TASK_POINTS + 10 )); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t User '$USER_NAME' in group '$GROUP_NAME'."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t User '$USER_NAME' not in group '$GROUP_NAME'."; fi
# Check umask - Needs to run command *as the user* or check config file
if [ -f "/home/${USER_NAME}/.bashrc" ] && grep -Eq "^\s*umask\s+${EXPECTED_UMASK}" "/home/${USER_NAME}/.bashrc"; then
    TASK_POINTS=$(( TASK_POINTS + 10 ))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t umask ${EXPECTED_UMASK} found in /home/${USER_NAME}/.bashrc."
else
    echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t umask ${EXPECTED_UMASK} not found in /home/${USER_NAME}/.bashrc."
fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 8: Set Hostname
CURRENT_TASK=8; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Set Hostname to 'dev'${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
if hostnamectl status | grep -q 'Static hostname: dev'; then T_SCORE=30; echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Hostname is 'dev'."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Hostname is not 'dev'."; fi
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 9: Create directory and change ownership
CURRENT_TASK=9; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Create directory and change ownership${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
DIR_NAME="/home/example"; OWNER_NAME="expert"
TASK_POINTS=0
if [ -d "$DIR_NAME" ]; then
    TASK_POINTS=$(( TASK_POINTS + 15 ))
    echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Directory '$DIR_NAME' exists."
    if [[ $(stat -c %U "$DIR_NAME") == "$OWNER_NAME" ]]; then
         TASK_POINTS=$(( TASK_POINTS + 15 ))
         echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Directory '$DIR_NAME' owner is '$OWNER_NAME'."
    else
         echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Directory '$DIR_NAME' owner is not '$OWNER_NAME'."
    fi
else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Directory '$DIR_NAME' does not exist."; fi
T_SCORE=$TASK_POINTS
grade_task $CURRENT_TASK $T_TOTAL $T_SCORE
echo -e "\n" | tee -a ${REPORT_FILE}

### TASK 10: Configure httpd on Port 82
CURRENT_TASK=10; echo -e "${COLOR_INFO}Evaluating Task $CURRENT_TASK: Configure httpd on Port 82${COLOR_RESET}" | tee -a ${REPORT_FILE}
T_SCORE=0; T_TOTAL=30
TASK_POINTS=0
if ! rpm -q httpd &>/dev/null; then dnf install -y httpd &>/dev/null; fi # Install if needed
if [ -f /var/www/html/index.html ] && grep -q 'Hello World!' /var/www/html/index.html; then TASK_POINTS=$((TASK_POINTS + 5)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t index.html exists with content."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t index.html missing/incorrect."; fi
if grep -Eq '^\s*Listen\s+82' /etc/httpd/conf/httpd.conf; then TASK_POINTS=$((TASK_POINTS + 5)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Listen 82 found."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Listen 82 not found."; fi
if semanage port -l | grep '^http_port_t' | grep -qw 82; then TASK_POINTS=$((TASK_POINTS + 5)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t SELinux port 82 labeled."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t SELinux port 82 not labeled."; fi
if firewall-cmd --list-ports --permanent 2>/dev/null | grep -qw 82/tcp ; then TASK_POINTS=$((TASK_POINTS + 5)); echo -e "${COLOR_OK}[OK]${COLOR_RESET}\t\t Firewall allows 82/tcp."; else echo -e "${COLOR_FAIL}[FAIL]${COLOR_RESET}\t Firewall does not allow 82/tcp."; fi
check_service_status httpd active 5 0; T_SUB_SCORE=$?; TASK_POINTS=$((TASK_POINTS + T_SUB_SCORE))
check_service_status httpd enabled 5 0; T_SUB_SCORE=$?; TASK_POINTS=$((TASK_POINTS + T_SUB_SCORE))
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
for i in {1..10}; do
    OBJ_NAME=${OBJECTIVE_NAMES[$i]:-"Unknown Objective $i"}
    OBJ_SCORE_VAL=${OBJECTIVE_SCORE[$i]:-0}
    OBJ_TOTAL_VAL=${OBJECTIVE_TOTAL[$i]:-0}
    PERCENT=0
    if [[ $OBJ_TOTAL_VAL -gt 0 ]]; then
        PERCENT=$(( OBJ_SCORE_VAL * 100 / OBJ_TOTAL_VAL ))
    fi
    printf " \t%-45s : %s%%\n" "$OBJ_NAME" "$PERCENT" | tee -a ${REPORT_FILE}
done
echo -e "\n------------------------------------------------" | tee -a ${REPORT_FILE}

# --- Calculate Overall Score ---
PASS_SCORE=$(( MAX_SCORE * PASS_THRESHOLD_PERCENT / 100 ))

echo -e "\nPassing score:\t\t${PASS_SCORE} ( ${PASS_THRESHOLD_PERCENT}% of ${MAX_SCORE} points)" | tee -a ${REPORT_FILE}
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
