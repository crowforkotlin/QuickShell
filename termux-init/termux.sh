#!/system/bin/sh

set -eu

TERMUX_PACKAGE=com.termux
TERMUX_PREFIX=/data/data/com.termux/files/usr
TERMUX_HOME=/data/data/com.termux/files/home
TERMUX_EXEC=/data/data/com.termux/files/usr/lib/libtermux-exec.so

usage() {
  printf '%s\n' \
    '用法:' \
    '  termux.sh                进入 Zsh，未安装时进入 Bash' \
    '  termux.sh --command <命令>  在 Termux 环境中执行命令'
}

require_termux_access() {
  command -v run-as >/dev/null 2>&1 || {
    printf '[error] 找不到 Android run-as 命令。\n' >&2
    exit 1
  }

  if ! run-as "$TERMUX_PACKAGE" /system/bin/sh -c '[ -x files/usr/bin/bash ]'; then
    printf '%s\n' \
      '[error] 无法通过 run-as 访问 Termux。' \
      '[error] 请确认 Termux 已完成初始化，并使用允许 run-as 的版本。' >&2
    exit 1
  fi
}

if [ "$#" -eq 0 ]; then
  require_termux_access
  exec run-as "$TERMUX_PACKAGE" "$TERMUX_PREFIX/bin/bash" -lc \
    "export PREFIX=$TERMUX_PREFIX; export HOME=$TERMUX_HOME; export PATH=$TERMUX_PREFIX/bin:\$PATH; export LD_PRELOAD=$TERMUX_EXEC; if [ -x $TERMUX_PREFIX/bin/zsh ]; then exec zsh -il; else exec bash -il; fi"
fi

case "$1" in
  -h|--help)
    usage
    ;;
  --command)
    [ "$#" -ge 2 ] || { usage >&2; exit 2; }
    shift
    COMMAND_TEXT="$*"
    require_termux_access
    exec run-as "$TERMUX_PACKAGE" "$TERMUX_PREFIX/bin/bash" -lc \
      "export PREFIX=$TERMUX_PREFIX; export HOME=$TERMUX_HOME; export PATH=$TERMUX_PREFIX/bin:\$PATH; export LD_PRELOAD=$TERMUX_EXEC; $COMMAND_TEXT"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
