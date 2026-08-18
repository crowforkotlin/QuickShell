#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

readonly TERMUX_PREFIX_DEFAULT="/data/data/com.termux/files/usr"
PREFIX="${PREFIX:-$TERMUX_PREFIX_DEFAULT}"
BIN_DIR="${QUICK_SHELL_BIN_DIR:-$PREFIX/bin}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
COMMAND_SOURCE_DIR="${QUICK_SHELL_COMMAND_DIR:-$SCRIPT_DIR/termux-init/bin}"

if [[ ! -d "$COMMAND_SOURCE_DIR" ]]; then
  COMMAND_SOURCE_DIR="$SCRIPT_DIR/bin"
fi
if [[ ! -d "$COMMAND_SOURCE_DIR" ]]; then
  COMMAND_SOURCE_DIR="$SCRIPT_DIR/../termux-init/bin"
fi

info() {
  printf '[info] %s\n' "$*"
}

fail() {
  printf '[error] %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
用法:
  init_light.sh [选项]

选项:
  --uninstall   删除 light 命令
  -h, --help    显示帮助
USAGE
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

atomic_copy() {
  local source_file="$1"
  local target_file="$2"
  local target_dir temp_file

  target_dir="${target_file%/*}"
  mkdir -p "$target_dir"
  temp_file="$(mktemp "$target_dir/.quick-shell.XXXXXX")" \
    || fail "无法创建临时文件: $target_file"

  if ! cp "$source_file" "$temp_file"; then
    rm -f "$temp_file"
    fail "无法写入文件: $target_file"
  fi
  chmod 755 "$temp_file"
  mv -f "$temp_file" "$target_file" \
    || fail "无法安装文件: $target_file"
}

main() {
  case "${1:-}" in
    -h|--help)
      usage
      exit 0
      ;;
    --uninstall)
      require_termux
      rm -f "$BIN_DIR/light"
      info '已删除 light。'
      exit 0
      ;;
    '')
      ;;
    *)
      fail "未知选项: $1"
      ;;
  esac

  require_termux
  command -v rish >/dev/null 2>&1 \
    || fail '找不到 rish，请先执行 init_shizuku.sh。'

  source_file="$COMMAND_SOURCE_DIR/light"
  [[ -f "$source_file" ]] || fail "找不到命令模板: $source_file"
  atomic_copy "$source_file" "$BIN_DIR/light"
  info 'light 安装完成。'
  printf '%s\n' \
    '用法:' \
    '  light <分钟>' \
    '  light seconds <秒>' \
    '  light never' \
    '  light status'
}

main "$@"
