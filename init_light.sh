#!/data/data/com.termux/files/usr/bin/bash

BIN=/data/data/com.termux/files/usr/bin

# ==========================================
# 创建屏幕超时设置脚本 (light)
# ==========================================
echo "正在生成 light 脚本..."

tee "${BIN}/light" > /dev/null << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash

# 定义颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ARG=$1

# 检查是否安装了 rish
if ! command -v rish &> /dev/null; then
    echo -e "${RED}错误：未找到 rish 命令。${NC}"
    echo "请先运行安装脚本配置 Shizuku 环境。"
    exit 1
fi

# 显示帮助信息
if [ -z "$ARG" ]; then
    echo -e "${YELLOW}用法说明：${NC}"
    echo -e "  light <数字>   : 设置息屏时间 (单位：分钟)"
    echo -e "  light s <数字> : 设置息屏时间 (单位：秒)"
    echo -e "  light never    : 设置为永不息屏"
    echo -e "  light check    : 查看当前设置"
    echo ""
    echo -e "${GREEN}示例：${NC}"
    echo "  light 5       (5分钟后息屏)"
    echo "  light s 30    (30秒后息屏)"
    echo "  light never   (保持常亮)"
    exit 0
fi

# 逻辑处理
TARGET_MS=0
DISPLAY_TEXT=""

if [ "$ARG" == "never" ]; then
    # Android 允许的最大整数值，通常代表永不息屏 (约24天)
    TARGET_MS=2147483647
    DISPLAY_TEXT="永不息屏"
elif [ "$ARG" == "check" ]; then
    # 获取当前值
    CURRENT=$(rish -c "settings get system screen_off_timeout")
    # 去除回车符
    CURRENT=$(echo $CURRENT | tr -d '\r')
    
    if [ "$CURRENT" == "2147483647" ]; then
        echo -e "当前设置：${GREEN}永不息屏${NC}"
    else
        SEC=$(($CURRENT / 1000))
        if [ $SEC -ge 60 ]; then
            MIN=$(($SEC / 60))
            echo -e "当前设置：${GREEN}${MIN} 分钟${NC} ($CURRENT ms)"
        else
            echo -e "当前设置：${GREEN}${SEC} 秒${NC} ($CURRENT ms)"
        fi
    fi
    exit 0
elif [ "$ARG" == "s" ]; then
    # 处理秒模式: light s 30
    SEC=$2
    if [[ ! "$SEC" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}错误：请输入有效的秒数。${NC}"
        exit 1
    fi
    TARGET_MS=$(($SEC * 1000))
    DISPLAY_TEXT="${SEC} 秒"
else
    # 默认模式：分钟
    if [[ ! "$ARG" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}错误：参数必须是数字(分钟) 或 'never'。${NC}"
        exit 1
    fi
    TARGET_MS=$(($ARG * 60 * 1000))
    DISPLAY_TEXT="${ARG} 分钟"
fi

# 执行修改 (使用 rish 权限)
echo -e "正在将屏幕超时设置为：${YELLOW}${DISPLAY_TEXT}${NC} ..."
rish -c "settings put system screen_off_timeout ${TARGET_MS}"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}设置成功！${NC}"
else
    echo -e "${RED}设置失败。${NC}请检查 Shizuku 是否正在运行 (输入 rish 测试)。"
fi
EOF

# 添加执行权限
chmod +x "${BIN}/light"

echo "脚本安装完成！现在您可以输入 light 查看帮助。"