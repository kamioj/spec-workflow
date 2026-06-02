#!/bin/sh
# 用户主动运行的 python3 安装辅助脚本。

set -eu

if command -v python3 >/dev/null 2>&1; then
  printf '%s\n' "python3 已安装：$(command -v python3)"
  exit 0
fi

os_name=$(uname -s)

case "$os_name" in
  Darwin)
    if command -v brew >/dev/null 2>&1; then
      printf '%s\n' '将通过 Homebrew 安装 python3：brew install python'
      brew install python
    else
      printf '%s\n' '未找到 Homebrew。将启动 Xcode Command Line Tools 安装器。'
      printf '%s\n' '安装完成后请重新执行本脚本确认 python3 可用。'
      xcode-select --install
    fi
    ;;
  Linux)
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update
      sudo apt-get install -y python3
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y python3
    elif command -v yum >/dev/null 2>&1; then
      sudo yum install -y python3
    elif command -v pacman >/dev/null 2>&1; then
      sudo pacman -S --needed python
    elif command -v apk >/dev/null 2>&1; then
      sudo apk add python3
    else
      cat >&2 <<'EOF'
未识别当前 Linux 发行版的软件包管理器。
请手动安装 python3 后重试。
EOF
      exit 2
    fi
    ;;
  *)
    printf '暂不支持自动安装当前系统：%s\n' "$os_name" >&2
    exit 2
    ;;
esac

if command -v python3 >/dev/null 2>&1; then
  printf '%s\n' "python3 安装完成：$(command -v python3)"
else
  printf '%s\n' '安装流程已启动，但当前 shell 仍找不到 python3。请重开终端后重试。' >&2
  exit 2
fi
