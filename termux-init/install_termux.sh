#!/usr/bin/env bash

set -Eeuo pipefail

readonly TERMUX_PACKAGE=com.termux
readonly TERMUX_PREFIX="/data/data/$TERMUX_PACKAGE/files/usr"
readonly TERMUX_RELATIVE_DIR="files/home/.local/share/quick-shell"
readonly TERMUX_ABSOLUTE_DIR="/data/data/$TERMUX_PACKAGE/files/home/.local/share/quick-shell"
readonly TERMUX_RELEASE_API="https://api.github.com/repos/termux/termux-app/releases/latest"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"
SERIAL="${ANDROID_SERIAL:-}"
INSTALL_APP=0
RUN_BOOTSTRAP=1
TMP_DIR=""
ADB=()

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
  bash termux-init/install_termux.sh [选项]

选项:
  --serial SERIAL  指定 adb 设备序列号
  --install-app    下载并安装最新的 Termux GitHub debug APK
  --no-run         仅部署文件，不立即执行 Termux 安装器
  -h, --help       显示帮助

默认行为:
  将 quick-shell 部署到已安装的 Termux 私有目录，并执行 init_termux.sh。
USAGE
}

cleanup() {
  if [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --serial)
        [[ $# -ge 2 ]] || fail '--serial 缺少参数。'
        SERIAL="$2"
        shift 2
        ;;
      --serial=*)
        SERIAL="${1#*=}"
        shift
        ;;
      --install-app)
        INSTALL_APP=1
        shift
        ;;
      --no-run)
        RUN_BOOTSTRAP=0
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
}

select_device() {
  local device_id state extra
  local devices=()

  command -v adb >/dev/null 2>&1 \
    || fail '找不到 adb。请安装 Android platform-tools。'

  if [[ -n "$SERIAL" ]]; then
    state="$(adb -s "$SERIAL" get-state 2>/dev/null || true)"
    [[ "$state" == device ]] \
      || fail "设备不可用: $SERIAL"
  else
    while read -r device_id state extra; do
      [[ "$state" == device ]] && devices+=("$device_id")
    done < <(adb devices)

    case "${#devices[@]}" in
      0) fail '未找到已授权的 adb 设备。' ;;
      1) SERIAL="${devices[0]}" ;;
      *) fail '检测到多个 adb 设备，请使用 --serial 指定目标设备。' ;;
    esac
  fi

  ADB=(adb -s "$SERIAL")
  info "使用设备: $SERIAL"
}

termux_is_installed() {
  "${ADB[@]}" shell pm path "$TERMUX_PACKAGE" >/dev/null 2>&1
}

termux_asset_suffix() {
  local abi

  abi="$("${ADB[@]}" shell getprop ro.product.cpu.abi | tr -d '\r\n')"
  case "$abi" in
    arm64-v8a|arm64-v8|aarch64) printf '%s\n' arm64-v8a ;;
    armeabi-v7a|armeabi-v7|arm) printf '%s\n' armeabi-v7a ;;
    x86) printf '%s\n' x86 ;;
    x86_64|x64) printf '%s\n' x86_64 ;;
    *) fail "不支持的 Android ABI: $abi" ;;
  esac
}

install_termux_app() {
  local suffix release_json apk_url apk_file

  command -v curl >/dev/null 2>&1 \
    || fail '--install-app 需要 curl。'

  suffix="$(termux_asset_suffix)"
  TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/quick-shell.XXXXXX")" \
    || fail '无法创建临时目录。'
  trap cleanup EXIT

  info '获取 Termux Release 信息。'
  release_json="$(curl --fail --location --silent --show-error \
    --connect-timeout 15 --max-time 60 "$TERMUX_RELEASE_API")" \
    || fail '无法获取 Termux Release 信息。'
  apk_url="$(printf '%s\n' "$release_json" | awk -F '"' -v suffix="_$suffix.apk" \
    '$2 == "browser_download_url" && index($4, suffix) > 0 { print $4; exit }')"
  [[ -n "$apk_url" ]] || fail "没有找到 $suffix 对应的 Termux APK。"

  apk_file="$TMP_DIR/termux.apk"
  info "下载 Termux APK: $suffix"
  curl --fail --location --silent --show-error --retry 2 \
    --connect-timeout 15 --max-time 180 -o "$apk_file" "$apk_url" \
    || fail '下载 Termux APK 失败。'

  info '安装 Termux APK。'
  "${ADB[@]}" install -r -g "$apk_file" \
    || fail 'Termux APK 安装失败。不会自动卸载现有应用。'
}

verify_run_as() {
  local attempt=0

  while [[ "$attempt" -lt 15 ]]; do
    if "${ADB[@]}" shell run-as "$TERMUX_PACKAGE" id >/dev/null 2>&1; then
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 1
  done

  fail '无法使用 run-as 进入 Termux。请使用 GitHub debug 版 Termux，或在 Termux 内手动执行安装器。'
}

upload_file() {
  local source_file="$1"
  local destination_name="$2"

  [[ -f "$source_file" ]] || fail "部署文件不存在: $source_file"
  "${ADB[@]}" exec-out run-as "$TERMUX_PACKAGE" sh -c \
    "cat > $TERMUX_RELATIVE_DIR/$destination_name" < "$source_file" \
    || fail "无法部署文件: $destination_name"
  "${ADB[@]}" shell run-as "$TERMUX_PACKAGE" chmod 700 \
    "$TERMUX_RELATIVE_DIR/$destination_name" \
    || fail "无法设置文件权限: $destination_name"
}

deploy_bundle() {
  local command_name

  verify_run_as
  "${ADB[@]}" shell run-as "$TERMUX_PACKAGE" mkdir -p \
    "$TERMUX_RELATIVE_DIR/bin" \
    || fail '无法创建 Termux 部署目录。'

  upload_file "$REPO_DIR/init_shizuku.sh" init_shizuku.sh
  upload_file "$REPO_DIR/init_light.sh" init_light.sh
  upload_file "$SCRIPT_DIR/init_termux.sh" init_termux.sh
  upload_file "$SCRIPT_DIR/termux.sh" termux.sh

  for command_name in adb-connect shizuku wf light; do
    upload_file "$SCRIPT_DIR/bin/$command_name" "bin/$command_name"
  done

  info '文件已部署到 Termux 私有目录。'
}

launch_termux() {
  if ! "${ADB[@]}" shell am start -n "$TERMUX_PACKAGE/.HomeActivity" \
    >/dev/null 2>&1; then
    warn '无法自动打开 Termux 应用。'
  fi
}

run_bootstrap() {
  if [[ "$RUN_BOOTSTRAP" -eq 0 ]]; then
    printf '%s\n' \
      '已跳过自动执行。可在主机运行:' \
      "  adb -s $SERIAL shell run-as $TERMUX_PACKAGE $TERMUX_PREFIX/bin/bash $TERMUX_ABSOLUTE_DIR/init_termux.sh"
    return 0
  fi

  info '执行 Termux 安装器。'
  "${ADB[@]}" shell run-as "$TERMUX_PACKAGE" "$TERMUX_PREFIX/bin/bash" \
    "$TERMUX_ABSOLUTE_DIR/init_termux.sh" \
    || fail "Termux 安装器执行失败。可重试: adb -s $SERIAL shell run-as $TERMUX_PACKAGE $TERMUX_PREFIX/bin/bash $TERMUX_ABSOLUTE_DIR/init_termux.sh"
}

main() {
  parse_args "$@"
  select_device

  if [[ "$INSTALL_APP" -eq 1 ]]; then
    install_termux_app
  fi
  termux_is_installed \
    || fail '未检测到 Termux。请先安装 Termux，或使用 --install-app。'

  launch_termux
  deploy_bundle
  run_bootstrap
  info '部署完成。'
}

main "$@"
