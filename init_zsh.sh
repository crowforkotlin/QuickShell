#!/bin/bash

# 定义颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}   Zsh + OMZ + QuickShell 配置脚本    ${NC}"
echo -e "${YELLOW}========================================${NC}"

# ==========================================
# 0. 环境与包管理器检测
# ==========================================
OS_TYPE=$(uname -o 2>/dev/null || uname -s)
INSTALL_CMD=""
UPDATE_CMD=""
SUDO=""

detect_pm_linux_mac() {
    echo -e "${BLUE}检测到 Linux/Mac 环境，请选择包管理器：${NC}"
    echo "1) pkg (Termux)"
    echo "2) apt (Debian/Ubuntu/Kali)"
    echo "3) choco (Linux?)"
    echo "4) pacman (Arch/Manjaro)"
    echo "5) brew (macOS/Linux)"
    read -p "请输入选项 [1-5]: " pm_choice
    case $pm_choice in
        1) INSTALL_CMD="pkg install -y"; UPDATE_CMD="pkg update -y";;
        2) INSTALL_CMD="apt install -y"; UPDATE_CMD="apt update -y"; SUDO="sudo";;
        3) INSTALL_CMD="choco install -y"; UPDATE_CMD="choco upgrade all -y";;
        4) INSTALL_CMD="pacman -S --noconfirm"; UPDATE_CMD="pacman -Sy"; SUDO="sudo";;
        5) INSTALL_CMD="brew install"; UPDATE_CMD="brew update";;
        *) echo "无效，默认 apt"; INSTALL_CMD="apt install -y"; UPDATE_CMD="apt update -y"; SUDO="sudo";;
    esac
}

detect_pm_windows() {
    echo -e "${BLUE}检测到 Windows 环境，请选择包管理器：${NC}"
    echo "1) choco"
    echo "2) pacman (MSYS2)"
    read -p "请输入选项 [1-2]: " pm_choice
    case $pm_choice in
        1) INSTALL_CMD="choco install -y"; UPDATE_CMD="choco upgrade all -y";;
        2) INSTALL_CMD="pacman -S --noconfirm"; UPDATE_CMD="pacman -Sy";;
        *) echo "无效，默认 choco"; INSTALL_CMD="choco install -y"; UPDATE_CMD="choco upgrade all -y";;
    esac
}

# --- 开始 OS 检测 ---
case "$OS_TYPE" in
    *Android*)
        echo -e "${GREEN}-> 检测到 Android 系统 (Termux)${NC}"
        INSTALL_CMD="pkg install -y"
        UPDATE_CMD="pkg update -y"
        ;;
    *Msys*|*Cygwin*|*Mingw*|*Windows*)
        detect_pm_windows
        ;;
    *)
        detect_pm_linux_mac
        ;;
esac

# ==========================================
# 1. 安装基础软件
# ==========================================
echo -e "${GREEN}-> 正在更新源并安装 zsh, git, curl, lsd, bat, fzf...${NC}"

# 执行更新
eval "$SUDO $UPDATE_CMD"

# 执行安装
echo -e "执行安装命令: $SUDO $INSTALL_CMD zsh curl git lsd bat fzf"
eval "$SUDO $INSTALL_CMD zsh curl git lsd bat fzf"

# --- 修复点 1: 刷新命令缓存 ---
# 防止刚安装完 zsh，shell 缓存里还认为没有 zsh
hash -r 2>/dev/null

# 特殊处理：Ubuntu 下 bat 可能叫 batcat
# --- 修复点 2: 兼容性写法 ---
if command -v batcat > /dev/null 2>&1 && ! command -v bat > /dev/null 2>&1; then
    echo "检测到 batcat，创建 bat 别名目录..."
    mkdir -p ~/.local/bin
    ln -s $(which batcat) ~/.local/bin/bat
    export PATH=$HOME/.local/bin:$PATH
fi

# 检查 Zsh 是否安装成功
# --- 修复点 3: 使用 > /dev/null 2>&1 替代 &>，兼容 dash ---
if ! command -v zsh > /dev/null 2>&1; then
    echo -e "${RED}错误：Zsh 安装失败！${NC}"
    echo "调试信息: 尝试手动运行 'zsh --version' 查看是否安装。"
    exit 1
fi

# ==========================================
# 2. 用户交互菜单 (安装模式)
# ==========================================
echo -e "请选择安装模式："
echo -e "${GREEN}1)${NC} ${RED}全新安装${NC} (删除旧配置)"
echo -e "${GREEN}2)${NC} ${BLUE}保留配置，仅更新${NC}"
echo -e "${GREEN}3)${NC} ${YELLOW}保留配置，强制重装插件${NC}"
read -p "请输入选项 [1-3] (其他键退出): " choice

CLEAN_INSTALL=false
FORCE_RECLONE=false
SKIP_ZSHRC=false

case "$choice" in
    1) CLEAN_INSTALL=true ;;
    2) SKIP_ZSHRC=true; FORCE_RECLONE=false ;;
    3) SKIP_ZSHRC=true; FORCE_RECLONE=true ;;
    *) exit 1 ;;
esac

# ==========================================
# 3. 处理配置文件 (.zshrc)
# ==========================================
# 定义 Quick Shell 目录，适配非 Android 环境
if [[ "$OS_TYPE" == *"Android"* ]]; then
    TARGET_DIR="/sdcard/0.file/shell"
else
    TARGET_DIR="$HOME/quick_shell"
fi

if [ "$CLEAN_INSTALL" = true ]; then
    echo -e "${GREEN}-> 清理旧配置...${NC}"
    rm -rf ~/.zshrc ~/.oh-my-zsh
    
    echo -e "${GREEN}-> 创建 Quick Shell 目录: ${TARGET_DIR}...${NC}"
    mkdir -p "$TARGET_DIR"

    echo -e "${GREEN}-> 生成 ~/.zshrc...${NC}"
    cat > ~/.zshrc << EOF
export ZSH="\$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git zsh-syntax-highlighting zsh-autosuggestions z extract fzf)
source \$ZSH/oh-my-zsh.sh

# 常用别名
alias ls=lsd
alias ll='lsd -l'
alias la='lsd -a'

# Quick Shell 自动加载
QS_DIR="${TARGET_DIR}"
if [ -d "\$QS_DIR" ]; then
    for script in "\$QS_DIR"/*; do
        if [ -f "\$script" ]; then
            filename=\$(basename "\$script")
            alias_name="\${filename%.*}"
            alias "\$alias_name"="bash '\$script'"
        fi
    done
fi
EOF
else
    echo -e "${BLUE}-> 跳过 .zshrc 生成。${NC}"
fi

# ==========================================
# 4. 安装/更新 Oh My Zsh & 插件
# ==========================================
echo -e "${GREEN}-> 处理 Oh My Zsh...${NC}"
export RUNZSH=no
export KEEP_ZSHRC=yes
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

install_plugin() {
    local url=$1
    local path=$2
    if [ -d "$path" ]; then
        if [ "$FORCE_RECLONE" = true ] || [ "$CLEAN_INSTALL" = true ]; then
            rm -rf "$path"
            git clone --depth=1 "$url" "$path"
        else
            git -C "$path" pull || echo "更新失败"
        fi
    else
        git clone --depth=1 "$url" "$path"
    fi
}

install_plugin "https://github.com/romkatv/powerlevel10k.git" "${ZSH_CUSTOM}/themes/powerlevel10k"
install_plugin "https://github.com/zsh-users/zsh-syntax-highlighting" "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"
install_plugin "https://github.com/zsh-users/zsh-autosuggestions" "${ZSH_CUSTOM}/plugins/zsh-autosuggestions"

# ==========================================
# 5. 结尾
# ==========================================
echo -e "${GREEN}-> 设置默认 Shell...${NC}"
if [[ "$OS_TYPE" == *"Android"* ]]; then
    chsh -s zsh
else
    # Linux 上尝试自动切换，如果失败提示手动
    if which zsh > /dev/null 2>&1; then
        chsh -s $(which zsh) || echo -e "${YELLOW}提示：可能需要手动输入密码或运行: chsh -s $(which zsh)${NC}"
    fi
fi

echo -e "${GREEN}安装完成！Quick Shell 目录: ${TARGET_DIR}${NC}"
exec zsh -l