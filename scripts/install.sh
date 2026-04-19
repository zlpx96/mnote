#!/usr/bin/env bash
# install.sh — 一键安装 launchd 定时任务
# 用法：./install.sh <mnote-data路径> <工作目录>
# 示例：./install.sh ~/mnote-data ~/projects

set -euo pipefail

MNOTE_DATA="${1:?用法: $0 <mnote-data路径> [工作目录]}"
WORK_DIR="${2:-$HOME}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WATCH_SH="$SCRIPT_DIR/watch.sh"
PLIST_SRC="$SCRIPT_DIR/com.mnote.watch.plist"
PLIST_DST="$HOME/Library/LaunchAgents/com.mnote.watch.plist"
LABEL="com.mnote.watch"

# 展开路径
MNOTE_DATA="$(eval echo "$MNOTE_DATA")"
WORK_DIR="$(eval echo "$WORK_DIR")"

CLAUDE_BIN="$(which claude 2>/dev/null || echo '/usr/local/bin/claude')"
USERNAME="$(whoami)"

echo "安装配置："
echo "  mnote-data : $MNOTE_DATA"
echo "  工作目录   : $WORK_DIR"
echo "  watch.sh   : $WATCH_SH"
echo "  claude     : $CLAUDE_BIN"
echo ""

# 验证路径
[[ -d "$MNOTE_DATA/.git" ]] || { echo "错误：$MNOTE_DATA 不是 git 仓库"; exit 1; }
[[ -f "$WATCH_SH" ]] || { echo "错误：找不到 $WATCH_SH"; exit 1; }
chmod +x "$WATCH_SH"

# 生成 plist
sed \
  -e "s|WATCH_SH_PATH|$WATCH_SH|g" \
  -e "s|MNOTE_DATA_PATH|$MNOTE_DATA|g" \
  -e "s|WORK_DIR_PATH|$WORK_DIR|g" \
  -e "s|/usr/local/bin/claude|$CLAUDE_BIN|g" \
  -e "s|/Users/YOUR_USERNAME|/Users/$USERNAME|g" \
  "$PLIST_SRC" > "$PLIST_DST"

echo "已写入 $PLIST_DST"

# 卸载旧的再装
launchctl unload "$PLIST_DST" 2>/dev/null || true
launchctl load -w "$PLIST_DST"

echo "已启动 launchd job: $LABEL"
echo "每 2 分钟检查一次新任务"
echo ""
echo "查看日志：tail -f $MNOTE_DATA/watch.log"
echo "手动触发：launchctl start $LABEL"
echo "卸载：    launchctl unload $PLIST_DST && rm $PLIST_DST"
