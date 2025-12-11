#!/bin/bash

# 设置遇到错误不立即退出，由逻辑控制
set -u

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}    Termux自动架构检测安装脚本 (Linux/Mac版)${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# 1. 检查ADB是否可用
echo "正在检查ADB连接..."
if ! command -v adb &> /dev/null; then
    echo -e "${RED}[错误] ADB未找到或未添加到系统PATH中${NC}"
    echo "请确保Android SDK已安装并配置环境变量 (platform-tools)"
    echo ""
    exit 1
fi

# 2. 获取连接的设备
echo "检查连接的设备..."
# 获取设备列表，去除第一行List of...，去除空行
devices=$(adb devices | grep -w "device")

if [ -z "$devices" ]; then
    echo -e "${RED}[错误] 未找到已连接的设备${NC}"
    echo "请确保设备已连接并开启USB调试"
    echo ""
    exit 1
fi

device_count=$(echo "$devices" | wc -l | tr -d ' ')
device_id=$(echo "$devices" | head -n 1 | awk '{print $1}')

echo -e "${GREEN}[成功] 找到 $device_count 个设备连接正常${NC}"
echo "设备ID: $device_id"
echo ""

# 3. 获取设备架构
echo "正在获取设备架构信息..."
# tr -d '\r' 非常重要，Windows/DOS换行符在Linux下会导致字符串比较失败
arch_raw=$(adb shell getprop ro.product.cpu.abi | tr -d '\r')

if [ -z "$arch_raw" ]; then
    echo -e "${RED}[错误] 无法获取设备架构信息${NC}"
    exit 1
fi

echo -e "[信息] 原始架构信息: ${YELLOW}$arch_raw${NC}"

# 4. 架构标准化处理
arch="$arch_raw"
apk_file=""
file_size_info=""

version="v0.118.3"
base_url="https://gh.llkk.cc/https://github.com/termux/termux-app/releases/latest/download"

# 使用 case 语句处理架构映射
case "$arch_raw" in
    arm64-v8a|arm64-v8|aarch64)
        arch="arm64-v8a"
        apk_file="termux-app_${version}+github-debug_arm64-v8a.apk"
        file_size_info="33.5 MB"
        echo -e "${GREEN}[匹配] 64位ARM架构 - 现代Android设备${NC}"
        ;;
    armeabi-v7a|armeabi-v7|arm)
        arch="armeabi-v7a"
        apk_file="termux-app_${version}+github-debug_armeabi-v7a.apk"
        file_size_info="30.8 MB"
        echo -e "${GREEN}[匹配] 32位ARM架构 - 较老Android设备${NC}"
        ;;
    x86)
        arch="x86"
        apk_file="termux-app_${version}+github-debug_x86.apk"
        file_size_info="32.8 MB"
        echo -e "${GREEN}[匹配] 32位x86架构 - 模拟器${NC}"
        ;;
    x86_64|x64)
        arch="x86_64"
        apk_file="termux-app_${version}+github-debug_x86_64.apk"
        file_size_info="33.6 MB"
        echo -e "${GREEN}[匹配] 64位x86架构 - 模拟器${NC}"
        ;;
    *)
        echo -e "${YELLOW}[警告] 无法识别的架构: $arch_raw${NC}"
        echo ""
        echo "常见架构映射:"
        echo "  arm64-v8, arm64-v8a, aarch64  -> arm64-v8a   (64位ARM)"
        echo "  armeabi-v7, armeabi-v7a, arm  -> armeabi-v7a (32位ARM)"
        echo "  x86                           -> x86         (32位x86)"
        echo "  x86_64, x64                   -> x86_64      (64位x86)"
        echo ""
        read -p "是否下载通用版本 (支持所有架构, 112 MB)? [y/N]: " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            apk_file="termux-app_${version}+github-debug_universal.apk"
            file_size_info="112 MB"
            echo -e "${GREEN}[选择] 通用版本: $apk_file${NC}"
        else
            echo ""
            echo "请手动下载：https://github.com/termux/termux-app/releases/latest"
            exit 1
        fi
        ;;
esac

echo -e "[信息] 标准化架构: ${YELLOW}$arch${NC}"

# 获取其他设备信息
device_model=$(adb shell getprop ro.product.model | tr -d '\r')
android_version=$(adb shell getprop ro.build.version.release | tr -d '\r')

echo "[信息] 设备型号: $device_model"
echo "[信息] Android版本: $android_version"
echo ""

download_url="${base_url}/${apk_file}"

echo "[目标] 文件: $apk_file"
echo "[大小] 预计: $file_size_info"
echo "[地址] $download_url"
echo ""

# 5. 下载文件
if [ -f "$apk_file" ]; then
    echo -e "${GREEN}[信息] 本地文件已存在，跳过下载${NC}"
else
    echo "========================================"
    echo "开始下载 Termux APK"
    echo "========================================"
    echo ""
    
    if command -v curl &> /dev/null; then
        echo "使用 curl 下载..."
        curl -L --progress-bar -o "$apk_file" "$download_url"
    elif command -v wget &> /dev/null; then
        echo "curl不可用，使用 wget 下载..."
        wget -O "$apk_file" "$download_url"
    else
        echo -e "${RED}[错误] 未找到 curl 或 wget，无法自动下载${NC}"
        echo "请手动下载: $download_url"
        echo "保存为: $apk_file"
        exit 1
    fi

    if [ $? -ne 0 ]; then
        echo ""
        echo -e "${RED}[错误] 下载失败${NC}"
        echo "请检查网络或尝试手动下载。"
        exit 1
    fi
    echo ""
    echo -e "${GREEN}[成功] 下载完成${NC}"
fi

# 6. 安装检查
if [ ! -f "$apk_file" ]; then
    echo -e "${RED}[错误] APK文件不存在${NC}"
    exit 1
fi

# 获取文件大小 (Linux/Mac兼容写法)
if [[ "$OSTYPE" == "darwin"* ]]; then
    file_size=$(stat -f%z "$apk_file") # macOS
else
    file_size=$(stat -c%s "$apk_file") # Linux
fi
file_size_mb=$(echo "scale=1; $file_size / 1024 / 1024" | bc)
echo "[文件] 大小: $file_size_mb MB"
echo ""

# 检查现有安装
echo "检查现有Termux安装..."
if adb shell pm list packages com.termux 2>/dev/null | grep -q "com.termux"; then
    echo -e "${YELLOW}[发现] 设备上已安装Termux${NC}"
    
    current_version=$(adb shell dumpsys package com.termux | grep "versionName" | head -n 1 | awk -F= '{print $2}' | tr -d '\r')
    echo "[版本] $current_version"

    read -p "是否卸载旧版本后重新安装? [Y/n]: " uninstall_choice
    if [[ ! "$uninstall_choice" =~ ^[Nn]$ ]]; then
        echo "正在卸载旧版本..."
        if adb uninstall com.termux; then
            echo -e "${GREEN}[成功] 旧版本已卸载${NC}"
        else
            echo -e "${YELLOW}[警告] 卸载失败，继续尝试覆盖安装${NC}"
        fi
    fi
fi

# 7. 安装APK
echo ""
echo "========================================"
echo "开始安装 Termux"
echo "========================================"
echo ""
echo "[安装] 正在安装到设备..."
echo "[架构] 原始: $arch_raw -> 标准: $arch"
echo "[文件] $apk_file"

install_success=false

# 尝试方法1: 普通安装
adb install "$apk_file" > install.log 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}[成功] Termux 安装完成！${NC}"
    install_success=true
fi

# 尝试方法2: 替换安装 (-r)
if [ "$install_success" = false ]; then
    echo "[重试] 尝试替换安装..."
    adb install -r "$apk_file" > install.log 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[成功] Termux 替换安装完成！${NC}"
        install_success=true
    fi
fi

# 尝试方法3: 授权安装 (-g)
if [ "$install_success" = false ]; then
    echo "[重试] 尝试授权安装..."
    adb install -r -g "$apk_file" > install.log 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[成功] Termux 授权安装完成！${NC}"
        install_success=true
    fi
fi

if [ "$install_success" = false ]; then
    echo -e "${RED}[失败] 自动安装失败${NC}"
    echo ""
    echo "错误信息:"
    cat install.log
    echo ""
    echo "========================================"
    echo "手动安装方案:"
    echo "========================================"
    echo "方法1: adb install -r -g \"$apk_file\""
    echo "方法2: adb push \"$apk_file\" /sdcard/Download/ 然后手机上手动安装"
    echo "方法3: adb uninstall com.termux 然后重装"
    echo ""
    echo "手动安装后，请继续执行后续的初始化步骤。"
    rm install.log 2>/dev/null
    exit 1
fi

rm install.log 2>/dev/null

echo ""
echo "========================================"
echo "安装成功！"
echo "========================================"
echo ""
echo "应用信息:"
echo "  名称: Termux Terminal Emulator"
echo "  版本: $version"
echo "  架构: $arch_raw (标准化: $arch)"
echo "  包名: com.termux"
echo "  文件: $apk_file"
echo ""

# 8. 推送初始化脚本
echo "检查 init_termux.sh 初始化脚本..."
# 获取脚本所在目录，防止因在其他目录运行脚本导致找不到文件
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INIT_SCRIPT="$SCRIPT_DIR/init_termux.sh"

if [ ! -f "$INIT_SCRIPT" ]; then
    echo -e "${RED}[错误] 未找到 init_termux.sh 文件${NC}"
    echo "请确保 init_termux.sh 文件与此脚本在同一目录: $SCRIPT_DIR"
    exit 1
fi

echo "[推送] 正在推送 init_termux.sh 到设备..."
# 使用 -p 创建多级目录
adb shell "mkdir -p /sdcard/0.file/shell"
if adb push "$INIT_SCRIPT" /sdcard/0.file/shell/init_termux.sh > /dev/null 2>&1; then
    echo -e "${GREEN}[成功] init_termux.sh 已推送到设备: /sdcard/0.file/shell/init_termux.sh${NC}"
else
    # 备选路径，如果上面的路径失败
    adb push "$INIT_SCRIPT" /sdcard/init_termux.sh > /dev/null 2>&1
    echo -e "${YELLOW}[警告] 推送到标准路径失败，已尝试推送到 /sdcard/init_termux.sh${NC}"
    echo "请手动检查文件位置。"
fi

# 9. 自动启动
echo ""
echo "========================================"
echo "自动启动 Termux 应用"
echo "========================================"
echo ""
echo "[启动] 正在打开 Termux 应用..."

adb shell am start -n com.termux/.HomeActivity > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}[成功] Termux 应用已启动${NC}"
    echo "请观察设备屏幕，等待初始化完成"
else
    echo -e "${YELLOW}[警告] 无法自动启动 Termux，请手动打开${NC}"
fi

# 10. 结束语
echo ""
echo "========================================"
echo "重要使用步骤:"
echo "========================================"
echo ""
echo "第1步: 等待 Termux 初始化"
echo "  - Termux 应用已自动启动"
echo "  - 首次打开会显示\"正在初始化\""
echo "  - 等待初始化完全完成 (约30-60秒)"
echo "  - 直到看到终端提示符 ($)"
echo ""
echo "第2步: 执行初始化配置"
echo "  打开新的终端窗口，输入:"
echo "  adb shell"
echo "  sh /sdcard/0.file/shell/init_termux.sh"
echo ""
echo "第3步: 选择对应的机型选项"
echo "  根据设备型号选择相应选项 (1-5)"
echo ""
echo "注意事项:"
echo "- 确保 Termux 完成初始化后再执行初始化脚本"
echo "- root 环境下 pkg 包管理器不可用"
echo ""

echo "========================================"
echo "脚本执行完成"
echo "当前时间: $(date)"
echo "用户: $USER"
echo "========================================"