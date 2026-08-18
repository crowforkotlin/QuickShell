# Quick Shell

用于 Termux、ADB 和 Shizuku 的 Shell 工具。脚本以 Android 设备上的 Termux 为运行目标，主机端支持 Arch Linux、其他 Linux 和 macOS。

Arch Linux 主机需要先安装 Android platform-tools:

```bash
sudo pacman -S android-tools
```

## 功能

- `adb-connect`：连接本机上的无线调试端口。
- `shizuku`：连接无线调试、切换到 `localhost:5555`，并启动 Shizuku。
- `rish`：使用 Shizuku 执行 Shell 命令。
- `light`：设置和查看屏幕息屏时间。
- `wf`：打开开发者选项中的无线调试页面。

## 目录

```text
.
├── init_shizuku.sh
├── init_light.sh
├── termux-init
│   ├── bin
│   │   ├── adb-connect
│   │   ├── light
│   │   ├── shizuku
│   │   └── wf
│   ├── init_termux.sh
│   ├── install_termux.bat
│   ├── install_termux.sh
│   └── termux.sh
└── termux-py
```

仓库不再保存 `rish_shizuku.dex`。安装时会优先从设备中已安装的 Shizuku APK 提取 `assets/rish` 和 `assets/rish_shizuku.dex`，并将运行时 dex 安装到 Termux 的 `$PREFIX/bin`，权限设置为 `0400`。这样可以避免仓库中的 dex 与设备上的 Shizuku 版本不一致。

## 主机部署

先在设备上安装 Termux 和 Shizuku，打开 Termux 完成首次初始化，并通过 USB ADB 授权设备。Arch Linux 上执行:

```bash
bash termux-init/install_termux.sh
```

脚本默认部署到现有 Termux，不卸载应用。若需要下载并安装最新版 Termux GitHub debug APK:

```bash
bash termux-init/install_termux.sh --install-app
```

设备上有多个 ADB 目标时指定序列号:

```bash
bash termux-init/install_termux.sh --serial SERIAL
```

如果 Termux 尚未完成初始化，可以先使用 `--no-run` 完成文件部署，打开 Termux 后再次执行提示中的命令。

主机端部署使用 `run-as com.termux` 写入 Termux 私有目录。使用非 debug 版 Termux 时，如果 `run-as` 被系统拒绝，请在 Termux 内手动执行初始化脚本，或安装 GitHub debug 版 Termux。

## Termux 内手动安装

在 Termux 中进入本仓库目录后执行:

```bash
bash termux-init/init_termux.sh
```

也可以分别执行:

```bash
bash init_shizuku.sh
bash init_light.sh
```

默认来源是设备中已安装的 Shizuku APK。如果 APK 路径无法读取，可以指定本地 APK 或下载最新版:

```bash
bash init_shizuku.sh --apk /sdcard/Download/shizuku.apk
bash init_shizuku.sh --source latest
```

## Termux 命令

在开发者选项中打开无线调试后，使用无线调试端口:

```bash
wf
adb-connect 37123
```

首次使用无线调试配对功能时:

```bash
adb-connect pair 37891 123456
```

连接并启动 Shizuku:

```bash
shizuku 37123
```

启动成功后，需要在 Shizuku 中授权 Termux。随后可以使用:

```bash
rish
rish -c 'settings get system screen_off_timeout'
```

屏幕息屏时间命令:

```bash
light 10
light seconds 30
light never
light status
```

`light 10` 表示十分钟，`light never` 使用 Android 支持的最大超时值。输入值超过 Android `screen_off_timeout` 的范围时脚本会拒绝执行。

## `termux-init` 的作用

`termux-init/init_termux.sh` 是 Termux 部署入口。它可以从 `adb shell` 环境通过 `run-as` 进入 Termux 用户，也可以直接在 Termux 内执行；随后复制脚本到 `$HOME/.local/share/quick-shell`，安装 `rish`、ADB 快捷命令和 `light`。

`termux-init/termux.sh` 是独立的 Termux Shell 入口，用于从 `adb shell` 进入 Termux 用户环境。无参数时优先进入 Zsh，未安装 Zsh 时回退到 Bash；使用 `--command` 可以执行指定命令:

```bash
adb push termux-init/termux.sh /data/local/tmp/termux.sh
adb shell sh /data/local/tmp/termux.sh
adb shell "sh /data/local/tmp/termux.sh --command 'exec zsh -il'"
```

Windows 主机可以执行 `termux-init/install_termux.bat`。该脚本与 Linux/macOS 部署器使用相同的 Termux 私有目录流程，不负责下载 Termux APK。

`rish` 的提取和安装流程参考了 [rish_installer](https://github.com/merbah3266/rish_installer)，但本项目只使用已安装 Shizuku APK 或官方 Release，不把 dex 文件提交到仓库。

## 检查脚本

Arch Linux 或其他 Bash 环境可以执行:

```bash
bash -n init_shizuku.sh init_light.sh
bash -n termux-init/init_termux.sh termux-init/install_termux.sh
for file in termux-init/bin/* termux-init/termux.sh; do sh -n "$file"; done
```

主机端依赖 Bash 和 `adb`；`--install-app` 额外需要 `curl`。`awk`、`tr` 和 `mktemp` 使用系统提供的标准 Unix 工具。Android 侧命令由 Termux 的 `android-tools`、`curl` 和 `unzip` 提供。

仓库中的其他初始化脚本（例如 `init_zsh.sh`、`init_vim.sh`）保持原有用途，与 Termux 部署流程相互独立。
