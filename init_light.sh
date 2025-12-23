#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# Script Name: Screen Timeout Manager (Light) Installer
# Platform   : Android (Termux)
# Dependency : Shizuku (rish)
# ==============================================================================

# --- 1. Global Config & Utility Functions ---

# Variable Definitions
BIN_DIR="/data/data/com.termux/files/usr/bin"
TARGET_FILE="${BIN_DIR}/light"
TOTAL_STEPS=3

# Color Definitions (Safe for Termux)
if command -v tput >/dev/null 2>&1; then
    RED=$(tput setaf 1; tput bold)
    GREEN=$(tput setaf 2; tput bold)
    YELLOW=$(tput setaf 3; tput bold)
    BLUE=$(tput setaf 4; tput bold)
    CYAN=$(tput setaf 6; tput bold)
    WHITE=$(tput setaf 7; tput bold)
    NC=$(tput sgr0)
else
    RED=$(printf '\033[1;31m')
    GREEN=$(printf '\033[1;32m')
    YELLOW=$(printf '\033[1;33m')
    BLUE=$(printf '\033[1;34m')
    CYAN=$(printf '\033[1;36m')
    WHITE=$(printf '\033[1;37m')
    NC=$(printf '\033[0m')
fi

# Logging Tools (Aligned & Colored)
log_info()    { printf "${BLUE} 🔵 [INFO]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN} 🟢 [PASS]${NC} %s\n" "$1"; }
log_warn()    { printf "${YELLOW} 🟡 [WARN]${NC} %s\n" "$1"; }
log_error()   { printf "${RED} 🔴 [FAIL]${NC} %s\n" "$1"; }

# Step Divider
print_step() {
    echo ""
    printf "${CYAN}┌──────────────────────────────────────────────────────────────┐${NC}\n"
    printf "${CYAN}│ 🚀 STEP %d/%d : %-43s │${NC}\n" "$1" "$2" "$3"
    printf "${CYAN}└──────────────────────────────────────────────────────────────┘${NC}\n"
}

# --- 2. Environment Check ---

check_env() {
    print_step 1 $TOTAL_STEPS "Environment Check"

    log_info "Checking target directory..."
    if [ ! -d "$BIN_DIR" ]; then
        log_error "Target directory not found: $BIN_DIR"
        exit 1
    fi
    log_success "Directory exists."

    log_info "Checking for Shizuku (rish)..."
    if ! command -v rish >/dev/null 2>&1; then
        log_warn "Command 'rish' not found!"
        log_info "The 'light' tool requires Shizuku to function."
        log_info "You can proceed, but please ensure rish is installed later."
    else
        log_success "Shizuku (rish) is available."
    fi
}

# --- 3. Generate Light Script ---

gen_light_script() {
    print_step 2 $TOTAL_STEPS "Generating 'light' Utility"

    log_info "Writing script to: ${WHITE}${TARGET_FILE}${NC}"

    # Use quoted 'EOF' to prevent variable expansion during generation
    tee "${TARGET_FILE}" > /dev/null << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash

# --- Internal Configuration ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

ARG=$1
VAL=$2

# --- Dependency Check ---
if ! command -v rish &> /dev/null; then
    echo -e "${RED} [ERROR] Command 'rish' not found.${NC}"
    echo " Please install Shizuku/rish first."
    exit 1
fi

# --- Help Menu ---
if [ -z "$ARG" ]; then
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}    Screen Timeout Manager (Light)      ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "  light <min>      : Set timeout in minutes"
    echo -e "  light s <sec>    : Set timeout in seconds"
    echo -e "  light never      : Keep screen always on"
    echo -e "  light check      : Show current settings"
    echo ""
    echo -e "${GREEN}Examples:${NC}"
    echo "  light 5          (Screen off after 5 mins)"
    echo "  light s 30       (Screen off after 30 secs)"
    echo "  light never      (Never sleep)"
    exit 0
fi

# --- Logic Processing ---
TARGET_MS=0
DISPLAY_TEXT=""

if [ "$ARG" == "never" ]; then
    # Max Integer value in Android ~24 days
    TARGET_MS=2147483647
    DISPLAY_TEXT="Never Sleep"

elif [ "$ARG" == "check" ]; then
    echo -e "${BLUE}Checking system settings...${NC}"
    CURRENT=$(rish -c "settings get system screen_off_timeout" | tr -d '\r')
    
    if [ "$CURRENT" == "2147483647" ]; then
        echo -e "Current Status: ${GREEN}Never Sleep${NC}"
    elif [[ "$CURRENT" =~ ^[0-9]+$ ]]; then
        SEC=$(($CURRENT / 1000))
        if [ $SEC -ge 60 ]; then
            MIN=$(($SEC / 60))
            echo -e "Current Status: ${GREEN}${MIN} min${NC} (${CURRENT} ms)"
        else
            echo -e "Current Status: ${GREEN}${SEC} sec${NC} (${CURRENT} ms)"
        fi
    else
        echo -e "${RED}Error: Could not retrieve settings.${NC}"
    fi
    exit 0

elif [ "$ARG" == "s" ]; then
    # Seconds Mode
    if [[ ! "$VAL" =~ ^[0-9]+$ ]]; then
        echo -e "${RED} [ERROR] Please provide valid seconds.${NC}"
        exit 1
    fi
    TARGET_MS=$(($VAL * 1000))
    DISPLAY_TEXT="${VAL} seconds"

else
    # Minutes Mode (Default)
    if [[ ! "$ARG" =~ ^[0-9]+$ ]]; then
        echo -e "${RED} [ERROR] Argument must be a number (min) or 'never'.${NC}"
        exit 1
    fi
    TARGET_MS=$(($ARG * 60 * 1000))
    DISPLAY_TEXT="${ARG} minutes"
fi

# --- Execution ---
echo -e "Setting screen timeout to: ${YELLOW}${DISPLAY_TEXT}${NC} ..."
rish -c "settings put system screen_off_timeout ${TARGET_MS}"

if [ $? -eq 0 ]; then
    echo -e "${GREEN} [SUCCESS] Settings updated.${NC}"
else
    echo -e "${RED} [FAIL] Failed to update settings.${NC}"
    echo " Check if Shizuku is running."
fi
EOF

    log_success "Script content written."
}

# --- 4. Finalize ---

finalize() {
    print_step 3 $TOTAL_STEPS "Finalizing Installation"

    log_info "Setting executable permissions..."
    chmod +x "${TARGET_FILE}"
    
    if [ -x "${TARGET_FILE}" ]; then
        log_success "Permission granted."
    else
        log_error "Failed to set permissions."
        exit 1
    fi
}

# --- Main Entry Point ---

main() {
    clear
    printf "${BLUE}====================================================${NC}\n"
    printf "${BLUE}   ✨ Screen Timeout Tool (Light) Installer ✨     ${NC}\n"
    printf "${BLUE}====================================================${NC}\n"

    check_env
    gen_light_script
    finalize

    echo ""
    log_success "🎉 Installation Complete!"
    echo ""
    printf "${CYAN}Try it now:${NC}\n"
    printf "  Type ${WHITE}light${NC} to see the help menu.\n"
    printf "  Type ${WHITE}light 10${NC} to set timeout to 10 minutes.\n"
}

main