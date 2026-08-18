#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly TERMUX_PREFIX_DEFAULT="/data/data/com.termux/files/usr"
readonly SHIZUKU_PACKAGE="moe.shizuku.privileged.api"
readonly SHIZUKU_RELEASE_API="https://api.github.com/repos/RikkaApps/Shizuku/releases/latest"

PREFIX="${PREFIX:-$TERMUX_PREFIX_DEFAULT}"
BIN_DIR="${QUICK_SHELL_BIN_DIR:-$PREFIX/bin}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
COMMAND_SOURCE_DIR="${QUICK_SHELL_COMMAND_DIR:-$SCRIPT_DIR/termux-init/bin}"
SOURCE_MODE="auto"
APK_INPUT=""
INSTALL_DEPENDENCIES=1
ACTION=install
TMP_DIR=""
APP_PACKAGE=""

if [[ ! -d "$COMMAND_SOURCE_DIR" ]]; then
  COMMAND_SOURCE_DIR="$SCRIPT_DIR/bin"
fi
if [[ ! -d "$COMMAND_SOURCE_DIR" ]]; then
  COMMAND_SOURCE_DIR="$SCRIPT_DIR/../termux-init/bin"
fi

info() {
  printf '[info] %s\n' "$*"
}

warn() {
  printf '[warn] %s\n' "$*" >&2
}

fail() {
  printf '[error] %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
用法:
  init_shizuku.sh [选项]

选项:
  --source auto|installed|latest
      auto       优先使用设备中已安装的 Shizuku，失败后下载最新版
      installed  只使用设备中已安装的 Shizuku
      latest     从 Shizuku GitHub Release 下载最新版
  --apk PATH    使用本地 APK 文件
  --no-install-dependencies
               不通过 pkg 安装 android-tools、curl 和 unzip
  --uninstall   删除本脚本安装的 rish、adb-connect、shizuku 和 wf
  -h, --help    显示帮助
USAGE
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

require_termux() {
  case "$PREFIX" in
    /data/data/*/files/usr|/data/user/*/*/files/usr) ;;
    *) fail '此脚本必须在 Termux 中执行。' ;;
  esac

  [[ -d "$PREFIX/bin" && -x "$PREFIX/bin/bash" ]] \
    || fail 'Termux 尚未完成初始化。'
  [[ "$(id -u)" -ne 0 ]] \
    || fail '请使用 Termux 普通用户执行，不能使用 root 用户。'
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source)
        [[ $# -ge 2 ]] || fail '--source 缺少参数。'
        SOURCE_MODE="$2"
        shift 2
        ;;
      --source=*)
        SOURCE_MODE="${1#*=}"
        shift
        ;;
      --apk)
        [[ $# -ge 2 ]] || fail '--apk 缺少参数。'
        APK_INPUT="$2"
        SOURCE_MODE=apk
        shift 2
        ;;
      --apk=*)
        APK_INPUT="${1#*=}"
        SOURCE_MODE=apk
        shift
        ;;
      --no-install-dependencies)
        INSTALL_DEPENDENCIES=0
        shift
        ;;
      --uninstall)
        ACTION=uninstall
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "未知选项: $1"
        ;;
    esac
  done

  case "$SOURCE_MODE" in
    auto|installed|latest|apk) ;;
    *) fail "不支持的来源: $SOURCE_MODE" ;;
  esac

  if [[ "$SOURCE_MODE" == apk && -z "$APK_INPUT" ]]; then
    fail '--apk 路径不能为空。'
  fi
}

detect_application_id() {
  local prefix_path rest package_name

  if [[ -n "${RISH_APPLICATION_ID:-}" ]]; then
    package_name="$RISH_APPLICATION_ID"
  else
    prefix_path="$PREFIX"
    package_name=

    case "$prefix_path" in
      /data/data/*/files/usr)
        rest="${prefix_path#/data/data/}"
        package_name="${rest%/files/usr}"
        ;;
      /data/user/*/*/files/usr)
        rest="${prefix_path#/data/user/}"
        rest="${rest#*/}"
        package_name="${rest%/files/usr}"
        ;;
    esac

    [[ -n "$package_name" ]] || package_name=com.termux
  fi

  [[ "$package_name" =~ ^[A-Za-z0-9._]+$ ]] \
    || fail "无效的 Termux 应用包名: $package_name"
  printf '%s\n' "$package_name"
}

ensure_dependencies() {
  local missing=()
  local package_name

  command_exists adb || missing+=(android-tools)
  command_exists unzip || missing+=(unzip)
  if [[ "$SOURCE_MODE" != installed && "$SOURCE_MODE" != apk ]]; then
    command_exists curl || missing+=(curl)
  fi

  [[ ${#missing[@]} -eq 0 ]] && return 0

  [[ "$INSTALL_DEPENDENCIES" -eq 1 ]] \
    || fail "缺少依赖: ${missing[*]}"

  command_exists pkg || fail '找不到 pkg，无法安装 Termux 依赖。'
  info "安装 Termux 依赖: ${missing[*]}"
  pkg update -y
  pkg install -y "${missing[@]}"
  hash -r

  for package_name in adb unzip; do
    command_exists "$package_name" || fail "依赖安装失败: $package_name"
  done
  if [[ "$SOURCE_MODE" != installed && "$SOURCE_MODE" != apk ]]; then
    command_exists curl || fail '依赖安装失败: curl'
  fi
}

package_path_from_output() {
  local output="$1"
  local line candidate first=

  while IFS= read -r line; do
    line="${line%$'\r'}"
    case "$line" in
      package:*)
        candidate="${line#package:}"
        [[ -n "$first" ]] || first="$candidate"
        if [[ "$candidate" == */base.apk ]]; then
          printf '%s\n' "$candidate"
          return 0
        fi
        ;;
    esac
  done <<< "$output"

  [[ -n "$first" ]] || return 1
  printf '%s\n' "$first"
}

installed_shizuku_apk() {
  local output= path=

  if [[ -x /system/bin/cmd ]]; then
    output=$(/system/bin/cmd package path "$SHIZUKU_PACKAGE" 2>/dev/null || true)
  fi
  if [[ -z "$output" && -x /system/bin/pm ]]; then
    output=$(/system/bin/pm path "$SHIZUKU_PACKAGE" 2>/dev/null || true)
  fi
  if [[ -n "$output" ]]; then
    path="$(package_path_from_output "$output" || true)"
  fi

  [[ -n "$path" && -f "$path" ]] || return 1
  printf '%s\n' "$path"
}

download_latest_apk() {
  local release_json apk_url

  command_exists curl || fail '下载 Shizuku 需要 curl。'
  info '获取 Shizuku 最新版本信息。'
  release_json="$(curl --fail --location --silent --show-error \
    --connect-timeout 15 --max-time 60 "$SHIZUKU_RELEASE_API")" \
    || fail '无法获取 Shizuku Release 信息。'

  apk_url="$(printf '%s\n' "$release_json" | awk -F '"' \
    '$2 == "browser_download_url" && $4 ~ /\.apk($|\?)/ { print $4; exit }')"
  [[ -n "$apk_url" ]] || fail 'Shizuku Release 中没有找到 APK。'

  info '下载 Shizuku APK。'
  curl --fail --location --silent --show-error --retry 2 \
    --connect-timeout 15 --max-time 180 -o "$TMP_DIR/shizuku.apk" "$apk_url" \
    || fail '下载 Shizuku APK 失败。'
  [[ -s "$TMP_DIR/shizuku.apk" ]] || fail '下载的 Shizuku APK 为空。'
}

acquire_apk() {
  local installed_path

  case "$SOURCE_MODE" in
    apk)
      [[ -f "$APK_INPUT" ]] || fail "APK 文件不存在: $APK_INPUT"
      cp "$APK_INPUT" "$TMP_DIR/shizuku.apk" \
        || fail "无法读取 APK 文件: $APK_INPUT"
      ;;
    installed)
      installed_path="$(installed_shizuku_apk || true)"
      [[ -n "$installed_path" ]] \
        || fail '找不到已安装的 Shizuku APK，或当前用户无权读取该 APK。'
      cp "$installed_path" "$TMP_DIR/shizuku.apk" \
        || fail '无法复制已安装的 Shizuku APK。'
      info '使用设备中已安装的 Shizuku APK。'
      ;;
    latest)
      download_latest_apk
      ;;
    auto)
      installed_path="$(installed_shizuku_apk || true)"
      if [[ -n "$installed_path" ]] && cp "$installed_path" "$TMP_DIR/shizuku.apk"; then
        info '使用设备中已安装的 Shizuku APK。'
      else
        warn '无法读取已安装的 Shizuku APK，改用 GitHub Release。'
        download_latest_apk
      fi
      ;;
  esac
}

extract_assets() {
  local extract_dir="$TMP_DIR/extracted"

  mkdir -p "$extract_dir"
  unzip -qq "$TMP_DIR/shizuku.apk" \
    assets/rish assets/rish_shizuku.dex -d "$extract_dir" \
    || fail '无法从 Shizuku APK 提取 rish 文件。'
  [[ -s "$extract_dir/assets/rish" ]] \
    || fail 'Shizuku APK 中缺少 assets/rish。'
  [[ -s "$extract_dir/assets/rish_shizuku.dex" ]] \
    || fail 'Shizuku APK 中缺少 assets/rish_shizuku.dex。'
}

atomic_copy() {
  local source_file="$1"
  local target_file="$2"
  local mode="$3"
  local target_dir temp_file

  target_dir="${target_file%/*}"
  mkdir -p "$target_dir"
  temp_file="$(mktemp "$target_dir/.quick-shell.XXXXXX")" \
    || fail "无法创建临时文件: $target_file"

  if ! cp "$source_file" "$temp_file"; then
    rm -f "$temp_file"
    fail "无法写入文件: $target_file"
  fi
  if ! chmod "$mode" "$temp_file"; then
    rm -f "$temp_file"
    fail "无法设置权限: $target_file"
  fi
  if ! mv -f "$temp_file" "$target_file"; then
    rm -f "$temp_file"
    fail "无法安装文件: $target_file"
  fi
}

install_rish() {
  local source_file="$TMP_DIR/extracted/assets/rish"
  local dex_file="$TMP_DIR/extracted/assets/rish_shizuku.dex"
  local patched_rish="$TMP_DIR/rish"

  {
    printf '#!/system/bin/sh\n'
    sed '1{/^#!/d;}' "$source_file" | sed "s/PKG/$APP_PACKAGE/g"
  } > "$patched_rish" || fail '无法生成 rish 启动脚本。'

  atomic_copy "$dex_file" "$BIN_DIR/rish_shizuku.dex" 400
  atomic_copy "$patched_rish" "$BIN_DIR/rish" 755
}

install_command_files() {
  local command_name source_file

  for command_name in adb-connect shizuku wf; do
    source_file="$COMMAND_SOURCE_DIR/$command_name"
    [[ -f "$source_file" ]] \
      || fail "找不到命令模板: $source_file"
    atomic_copy "$source_file" "$BIN_DIR/$command_name" 755
  done
}

uninstall() {
  local command_name

  for command_name in rish rish_shizuku.dex adb-connect shizuku wf; do
    rm -f "$BIN_DIR/$command_name"
  done
  info '已删除 rish、adb-connect、shizuku 和 wf。'
}

cleanup() {
  if [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}

main() {
  parse_args "$@"
  require_termux

  if [[ "$ACTION" == uninstall ]]; then
    uninstall
    return 0
  fi

  APP_PACKAGE="$(detect_application_id)"
  ensure_dependencies
  mkdir -p "${TMPDIR:-$HOME/tmp}"
  TMP_DIR="$(mktemp -d "${TMPDIR:-$HOME/tmp}/quick-shell.XXXXXX")" \
    || fail '无法创建临时目录。'
  trap cleanup EXIT
  trap 'exit 130' INT

  acquire_apk
  extract_assets
  install_rish
  install_command_files

  info '安装完成。'
  printf '%s\n' \
    '可用命令:' \
    '  adb-connect <无线调试端口>  连接无线调试设备' \
    '  shizuku <无线调试端口>      连接并启动 Shizuku' \
    '  rish                       执行 Shizuku shell' \
    '  wf                         打开无线调试设置'
}

main "$@"
