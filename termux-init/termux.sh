#!/system/bin/sh

set -eu

TERMUX_PACKAGE=com.termux
TERMUX_PREFIX=/data/data/com.termux/files/usr
TERMUX_HOME=/data/data/com.termux/files/home
TERMUX_EXEC=/data/data/com.termux/files/usr/lib/libtermux-exec.so

usage() {
  printf '%s\n' \
    '用法:' \
    '  termux.sh' \
    '  termux.sh --command <命令>'
}

if [ "$#" -eq 0 ]; then
  command -v run-as >/dev/null 2>&1 || {
    printf '[error] 找不到 Android run-as 命令。\n' >&2
    exit 1
  }
  [ -x "$TERMUX_PREFIX/bin/bash" ] || {
    printf '[error] Termux 尚未安装或尚未完成初始化。\n' >&2
    exit 1
  }
  exec run-as "$TERMUX_PACKAGE" "$TERMUX_PREFIX/bin/bash" -lic \
    "export PREFIX=$TERMUX_PREFIX; export HOME=$TERMUX_HOME; export PATH=$TERMUX_PREFIX/bin:\$PATH; export LD_PRELOAD=$TERMUX_EXEC; exec bash -i"
fi

case "$1" in
  -h|--help)
    usage
    ;;
  --command)
    [ "$#" -eq 2 ] || { usage >&2; exit 2; }
    command -v run-as >/dev/null 2>&1 || {
      printf '[error] 找不到 Android run-as 命令。\n' >&2
      exit 1
    }
    [ -x "$TERMUX_PREFIX/bin/bash" ] || {
      printf '[error] Termux 尚未安装或尚未完成初始化。\n' >&2
      exit 1
    }
    exec run-as "$TERMUX_PACKAGE" "$TERMUX_PREFIX/bin/bash" -lc \
      "export PREFIX=$TERMUX_PREFIX; export HOME=$TERMUX_HOME; export PATH=$TERMUX_PREFIX/bin:\$PATH; export LD_PRELOAD=$TERMUX_EXEC; $2"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
