#!/bin/sh
# /spec:propose 前置检查的 macOS/Linux 入口。

set -u

script_dir=${0%/*}
if [ "$script_dir" = "$0" ]; then
  script_dir=.
fi

if command -v python3 >/dev/null 2>&1; then
  python_bin=python3
elif [ -x /opt/homebrew/bin/python3 ]; then
  python_bin=/opt/homebrew/bin/python3
elif [ -x /usr/local/bin/python3 ]; then
  python_bin=/usr/local/bin/python3
elif [ -x /usr/bin/python3 ]; then
  python_bin=/usr/bin/python3
else
  cat >&2 <<'EOF'
SDD check-tbd hook: 未找到 python3，无法执行硬约束检查，已阻断。

macOS 可选安装方式：
  brew install python
  # 或安装 Xcode Command Line Tools
  xcode-select --install

Linux 可选安装方式：
  sudo apt-get install python3
  # 或使用当前发行版的软件包管理器安装 python3

也可以主动运行本插件提供的安装辅助脚本：
  sh "$CLAUDE_PLUGIN_ROOT/hooks/install-python3.sh"
EOF
  exit 2
fi

exec "$python_bin" "$script_dir/check-tbd.py"
