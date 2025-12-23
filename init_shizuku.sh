#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# Script Name: Shizuku + Rish + ADB Setup Script
# Platform   : Android (Termux)
# Description: Automates the deployment of Shizuku startup scripts and Rish shell.
# ==============================================================================

# --- 1. Global Config & Utility Functions ---

# Variable Definitions
BASEDIR=$(dirname "${0}")
BIN_DIR="/data/data/com.termux/files/usr/bin"
HOME_DIR="/data/data/com.termux/files/home"
SOURCE_DEX="${BASEDIR}/rish_shizuku.dex"
TARGET_DEX="${HOME_DIR}/rish_shizuku.dex"
TOTAL_STEPS=4

# Color Definitions (Safe for Termux/Bash)
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

# Logging Tools
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
    print_step 1 $TOTAL_STEPS "Environment & Dependency Check"

    log_info "Verifying 'rish_shizuku.dex' file..."
    if [ ! -f "${SOURCE_DEX}" ]; then
        log_error "File not found: ${WHITE}${SOURCE_DEX}${NC}"
        log_warn "Please export 'rish_shizuku.dex' from the Shizuku App and place it in this folder."
        exit 1
    fi
    log_success "Dex file found."

    log_info "Installing/Updating ADB (android-tools)..."
    # -y to avoid prompts
    pkg update -y > /dev/null 2>&1
    if pkg install android-tools -y > /dev/null 2>&1; then
        log_success "ADB installed successfully."
    else
        log_error "Failed to install android-tools. Check your internet connection."
        exit 1
    fi

    # Verify command
    if ! command -v adb > /dev/null 2>&1; then
        log_error "ADB command not found in PATH."
        exit 1
    fi
}

# --- 3. Generate Startup Script (shizuku) ---

gen_shizuku_script() {
    print_step 2 $TOTAL_STEPS "Generating Service Launcher (shizuku)"

    local TARGET_FILE="${BIN_DIR}/shizuku"
    log_info "Creating script: ${WHITE}${TARGET_FILE}${NC}"

    tee "${TARGET_FILE}" > /dev/null << EOF
#!/data/data/com.termux/files/usr/bin/bash

# Port argument
PORT=\$1

# Validation
if [ -z "\$PORT" ]; then
    echo -e "\033[1;31m[ERROR]\033[0m Missing port number!"
    echo "Usage: shizuku <PORT>"
    echo "Tip: Run 'wf' first to check Wireless Debugging settings."
    exit 1
fi

# Fix /tmp permission issues in Termux
export TMPDIR=${HOME_DIR}/tmp
mkdir -p \$TMPDIR

echo "🔄 Attempting to connect to localhost:\${PORT} ..."

# Try to connect
result=\$( adb connect "localhost:\${PORT}" )

# Check result
if [[ "\$result" =~ "connected" || "\$result" =~ "already" ]]; then
    echo -e "\033[1;32m[SUCCESS]\033[0m ADB Connected: \${result}"
    
    # Reconnect offline devices just in case
    adb reconnect offline > /dev/null 2>&1
    
    echo "⚙️ Setting TCP/IP to 5555..."
    adb tcpip 5555
    adb connect localhost:5555 > /dev/null 2>&1

    # --- Start Shizuku Service ---
    echo "🚀 Sending start command..."
    
    # Note: This path is hardcoded. If Shizuku updates, this might need changing.
    adb -s localhost:5555 shell /data/app/~~5IFLghd3vFZ3-rrE9-6cZA==/moe.shizuku.privileged.api-9kEZhlx2wGLOjURUtgFdvw==/lib/arm64/libshizuku.so

    echo "✅ Start command sent."
    exit 0
else
    echo -e "\033[1;31m[FAIL]\033[0m Could not connect to localhost:\${PORT}"
    echo "ADB Output: \${result}"
    echo "Tip: Wireless debugging port changes every time you toggle it."
    exit 1
fi
EOF
    log_success "Launcher script created."
}

# --- 4. Generate Shortcut Script (wf) ---

gen_wf_script() {
    print_step 3 $TOTAL_STEPS "Generating Settings Shortcut (wf)"
    
    local TARGET_FILE="${BIN_DIR}/wf"
    log_info "Creating script: ${WHITE}${TARGET_FILE}${NC}"

    tee "${TARGET_FILE}" > /dev/null << EOF
#!/data/data/com.termux/files/usr/bin/bash

echo "⚙️  Opening Wireless Debugging Settings..."
am start -a android.settings.APPLICATION_DEVELOPMENT_SETTINGS \\
  --es ":settings:fragment_args_key" "toggle_adb_wireless" > /dev/null 2>&1

if [ \$? -eq 0 ]; then
    echo "✅ Request sent."
else
    echo "❌ Failed to open settings. Please open manually."
fi
EOF
    log_success "Shortcut script created."
}

# --- 5. Generate Rish Shell & Finalize ---

finalize_setup() {
    print_step 4 $TOTAL_STEPS "Deploying Rish & Finalizing"

    # 1. Generate 'rish' script
    local RISH_FILE="${BIN_DIR}/rish"
    log_info "Generating wrapper: ${WHITE}${RISH_FILE}${NC}"
    
    tee "${RISH_FILE}" > /dev/null << EOF
#!/data/data/com.termux/files/usr/bin/bash

export RISH_APPLICATION_ID="com.termux"

/system/bin/app_process -Djava.class.path="${TARGET_DEX}" /system/bin --nice-name=rish rikka.shizuku.shell.ShizukuShellLoader "\${@}"
EOF

    # 2. Deploy Dex File
    log_info "Deploying Dex file to: ${WHITE}${TARGET_DEX}${NC}"
    cp -f "${SOURCE_DEX}" "${TARGET_DEX}"
    chmod -w "${TARGET_DEX}" # Read-only protection

    # 3. Set Permissions
    log_info "Setting executable permissions..."
    chmod +x "${BIN_DIR}/shizuku" "${BIN_DIR}/rish" "${BIN_DIR}/wf"

    log_success "All scripts installed."
}

# --- Main Entry Point ---

main() {
    printf "${MAGENTA}====================================================${NC}\n"
    printf "${MAGENTA}   ✨ Shizuku + Rish + ADB Deployment Tool ✨      ${NC}\n"
    printf "${MAGENTA}====================================================${NC}\n"

    check_env
    gen_shizuku_script
    gen_wf_script
    finalize_setup

    echo ""
    log_success "🎉 Deployment Completed Successfully!"
    echo ""
    printf "${CYAN}Usage Guide:${NC}\n"
    printf "  1. Type ${WHITE}wf${NC}            -> Go to Settings, enable Wireless Debugging.\n"
    printf "                          (Remember the port, e.g., 41234)\n"
    printf "  2. Type ${WHITE}shizuku <PORT>${NC} -> Connect ADB & Start Service.\n"
    printf "                          (e.g., shizuku 41234)\n"
    printf "  3. Type ${WHITE}rish${NC}          -> Enter Shizuku Root Shell.\n"
}

main