#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

readonly TERMUX_PACKAGE=com.termux
readonly TERMUX_PREFIX_DEFAULT="/data/data/$TERMUX_PACKAGE/files/usr"
readonly TERMUX_HOME_DEFAULT="/data/data/$TERMUX_PACKAGE/files/home"

TERMUX_PREFIX="${PREFIX:-$TERMUX_PREFIX_DEFAULT}"
TERMUX_HOME="${HOME:-$TERMUX_HOME_DEFAULT}"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/$(basename "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
SOURCE_DIR=""
ACTION=install
RISH_ARGS=()

case "$TERMUX_PREFIX" in
  /data/data/*/files/usr|/data/user/*/*/files/usr) ;;
  *) TERMUX_PREFIX="$TERMUX_PREFIX_DEFAULT" ;;
esac

case "$TERMUX_HOME" in
  /data/data/*/files/home|/data/user/*/*/files/home) ;;
  *) TERMUX_HOME="$TERMUX_HOME_DEFAULT" ;;
esac

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
  init_termux.sh [选项]

选项:
  --source-dir PATH
      指定包含 init_shizuku.sh、init_light.sh 和 bin 目录的来源目录
  --source auto|installed|latest
      传递给 init_shizuku.sh
  --apk PATH
      传递给 init_shizuku.sh
  --no-install-dependencies
      不通过 pkg 安装缺失依赖
  --uninstall
      删除已安装的命令
  -h, --help
      显示帮助
USAGE
}

is_termux_user() {
  local uid

  uid="$(id -u)"
  [[ "$uid" -ge 10000 ]] 2>/dev/null \
    && [[ -x "$TERMUX_PREFIX/bin/bash" ]]
}

enter_termux_user() {
  command -v run-as >/dev/null 2>&1 \
    || fail '此环境不是 Termux，且找不到 Android run-as 命令。'
  [[ -x "$TERMUX_PREFIX_DEFAULT/bin/bash" ]] \
    || fail 'Termux 尚未安装或尚未完成初始化。'

  exec run-as "$TERMUX_PACKAGE" "$TERMUX_PREFIX_DEFAULT/bin/bash" \
    "$SCRIPT_PATH" "$@"
}

prepare_termux_environment() {
  export PREFIX="$TERMUX_PREFIX"
  export HOME="$TERMUX_HOME"
  export PATH="$PREFIX/bin:$PATH"

  if [[ -f "$PREFIX/lib/libtermux-exec.so" ]]; then
    export LD_PRELOAD="$PREFIX/lib/libtermux-exec.so"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source-dir)
        [[ $# -ge 2 ]] || fail '--source-dir 缺少参数。'
        SOURCE_DIR="$2"
        shift 2
        ;;
      --source-dir=*)
        SOURCE_DIR="${1#*=}"
        shift
        ;;
      --source)
        [[ $# -ge 2 ]] || fail '--source 缺少参数。'
        RISH_ARGS+=(--source "$2")
        shift 2
        ;;
      --source=*)
        RISH_ARGS+=(--source "${1#*=}")
        shift
        ;;
      --apk)
        [[ $# -ge 2 ]] || fail '--apk 缺少参数。'
        RISH_ARGS+=(--apk "$2")
        shift 2
        ;;
      --apk=*)
        RISH_ARGS+=(--apk "${1#*=}")
        shift
        ;;
      --no-install-dependencies)
        RISH_ARGS+=(--no-install-dependencies)
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
}

resolve_source_dir() {
  local candidate

  if [[ -n "$SOURCE_DIR" ]]; then
    candidate="$SOURCE_DIR"
  elif [[ -f "$SCRIPT_DIR/init_shizuku.sh" ]]; then
    candidate="$SCRIPT_DIR"
  else
    candidate="$(cd "$SCRIPT_DIR/.." && pwd -P)"
  fi

  [[ -f "$candidate/init_shizuku.sh" ]] \
    || fail "找不到 init_shizuku.sh: $candidate"
  [[ -f "$candidate/init_light.sh" ]] \
    || fail "找不到 init_light.sh: $candidate"
  printf '%s\n' "$candidate"
}

copy_file() {
  local source_file="$1"
  local target_file="$2"

  [[ "$source_file" == "$target_file" ]] && return 0
  cp "$source_file" "$target_file" \
    || fail "无法复制文件: $source_file"
  chmod 755 "$target_file" \
    || fail "无法设置文件权限: $target_file"
}

copy_bundle() {
  local source_root="$1"
  local command_root install_root command_name termux_entry

  install_root="$HOME/.local/share/quick-shell"
  command_root="$source_root/bin"
  if [[ ! -d "$command_root" ]]; then
    command_root="$source_root/termux-init/bin"
  fi
  [[ -d "$command_root" ]] || fail "找不到命令目录: $command_root"

  mkdir -p "$install_root/bin"
  copy_file "$source_root/init_shizuku.sh" "$install_root/init_shizuku.sh"
  copy_file "$source_root/init_light.sh" "$install_root/init_light.sh"
  copy_file "$SCRIPT_PATH" "$install_root/init_termux.sh"

  termux_entry="$source_root/termux.sh"
  if [[ ! -f "$termux_entry" ]]; then
    termux_entry="$source_root/termux-init/termux.sh"
  fi
  if [[ -f "$termux_entry" ]]; then
    copy_file "$termux_entry" "$install_root/termux.sh"
  fi

  for command_name in adb-connect shizuku wf light; do
    [[ -f "$command_root/$command_name" ]] \
      || fail "找不到命令模板: $command_root/$command_name"
    copy_file "$command_root/$command_name" "$install_root/bin/$command_name"
  done

  printf '%s\n' "$install_root"
}

uninstall_commands() {
  local source_root install_root

  source_root="$(resolve_source_dir)"
  install_root="$(copy_bundle "$source_root")"
  "$install_root/init_light.sh" --uninstall
  "$install_root/init_shizuku.sh" --uninstall
  info '已删除 quick-shell 命令。'
}

install_commands() {
  local source_root install_root

  source_root="$(resolve_source_dir)"
  install_root="$(copy_bundle "$source_root")"
  QUICK_SHELL_COMMAND_DIR="$install_root/bin" \
    "$install_root/init_shizuku.sh" "${RISH_ARGS[@]}"
  QUICK_SHELL_COMMAND_DIR="$install_root/bin" \
    "$install_root/init_light.sh"
  info 'Termux 命令安装完成。'
}

main() {
  parse_args "$@"

  if ! is_termux_user; then
    enter_termux_user "$@"
  fi

  prepare_termux_environment
  if [[ "$ACTION" == uninstall ]]; then
    uninstall_commands
  else
    install_commands
  fi
}

main "$@"
