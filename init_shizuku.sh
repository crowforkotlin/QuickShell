#!/data/data/com.termux/files/usr/bin/bash

# --- 变量定义 ---
BASEDIR=$( dirname "${0}" )
BIN=/data/data/com.termux/files/usr/bin
HOME=/data/data/com.termux/files/home
DEX="${BASEDIR}/rish_shizuku.dex"

# 定义颜色 (可选)
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ==========================================
# 0. 环境检查：确保 ADB 已安装且为最新
# ==========================================
echo -e "${YELLOW}正在检查 ADB 环境...${NC}"

# 无论是否安装，都执行安装/更新命令，确保版本最新
# -y 参数用于自动确认，避免脚本暂停
pkg update -y
pkg install android-tools -y

# 检查 adb 命令是否可用
if ! command -v adb &> /dev/null; then
    echo -e "${RED}错误：ADB (android-tools) 安装失败！${NC}"
    echo "请检查网络连接或 Termux 软件源设置。"
    exit 1
else
    echo -e "${GREEN}ADB 已准备就绪。${NC}"
fi

# 检查 dex 文件是否存在
if [ ! -f "${DEX}" ]; then
  echo -e "${RED}错误：找不到 ${DEX} 文件！${NC}"
  echo "请确认已从 Shizuku App 导出文件 (文件名为 rish_shizuku.dex) 并放在当前目录下。"
  exit 1
fi

# ==========================================
# 1. 创建 Shizuku 启动脚本 (shizuku)
# ==========================================
echo -e "${GREEN}正在生成启动脚本...${NC}"

tee "${BIN}/shizuku" > /dev/null << EOF
#!/data/data/com.termux/files/usr/bin/bash

# 获取用户输入的端口号
PORT=\$1

# 检查是否输入了端口号
if [ -z "\$PORT" ]; then
    echo "错误：未提供端口号！"
    echo "用法: shizuku <端口号>"
    echo "提示：您可以先运行 'wf' 命令跳转设置查看端口。"
    exit 1
fi

# 绕过 /tmp 权限问题
export TMPDIR=/data/data/com.termux/files/home/tmp
mkdir -p \$TMPDIR

echo "正在尝试连接到 localhost:\${PORT} ..."

# 尝试连接指定端口
result=\$( adb connect "localhost:\${PORT}" )

# 检查连接结果
if [[ "\$result" =~ "connected" || "\$result" =~ "already" ]]; then
    echo "ADB连接成功：\${result}"
    
    # 尝试重新连接离线设备
    adb reconnect offline
    
    echo "正在设置 TCP 5555 模式..."
    adb tcpip 5555
    adb connect localhost:5555

    # --- 启动 Shizuku 服务 ---
    echo "正在发送 Shizuku 启动命令..."
    
    # 注意：这里的路径是硬编码的，如果 Shizuku 更新导致路径变化，可能需要重新提取路径
    adb -s localhost:5555 shell /data/app/~~5IFLghd3vFZ3-rrE9-6cZA==/moe.shizuku.privileged.api-9kEZhlx2wGLOjURUtgFdvw==/lib/arm64/libshizuku.so

    echo "Shizuku 启动命令已发送。"
    exit 0
else
    echo "错误：无法连接到 localhost:\${PORT}"
    echo "ADB 返回信息: \${result}"
    echo "请检查端口号是否已变更（无线调试端口每次开关都会变化）。"
    exit 1
fi
EOF

# ==========================================
# 2. 创建快捷跳转脚本 (wf)
# ==========================================
tee "${BIN}/wf" > /dev/null << EOF
#!/data/data/com.termux/files/usr/bin/bash

echo "正在打开无线调试设置..."
am start -a android.settings.APPLICATION_DEVELOPMENT_SETTINGS \\
  --es ":settings:fragment_args_key" "toggle_adb_wireless" > /dev/null 2>&1

if [ \$? -eq 0 ]; then
    echo "已发送跳转请求。"
else
    echo "跳转失败，请手动前往开发者选项。"
fi
EOF

# ==========================================
# 3. 创建 Rish Shell 启动脚本 (rish)
# ==========================================
dex="${HOME}/rish_shizuku.dex"
tee "${BIN}/rish" > /dev/null << EOF
#!/data/data/com.termux/files/usr/bin/bash

export RISH_APPLICATION_ID="com.termux"

/system/bin/app_process -Djava.class.path="${dex}" /system/bin --nice-name=rish rikka.shizuku.shell.ShizukuShellLoader "\${@}"
EOF

# --- 权限设置与文件复制 ---
# 给 shizuku, rish, wf 添加执行权限
chmod +x "${BIN}/shizuku" "${BIN}/rish" "${BIN}/wf"

# 复制 dex 文件
cp -f "${DEX}" "${dex}"
chmod -w "${dex}"

echo -e "${GREEN}--- 脚本安装完成！ ---${NC}"
echo "使用流程："
echo "1. 输入 wf       -> 跳转设置，开启无线调试，记住端口号（例如 41234）"
echo "2. 输入 shizuku 41234 -> 启动服务"
echo "3. 输入 rish     -> 进入 Shizuku Shell"