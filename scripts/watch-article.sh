#!/usr/bin/env bash
# watch-article.sh — 从 mnote-data 拉取文章改编任务并执行
#
# 用法：watch-article.sh <mnote-data 路径> [工作目录]
# 示例：watch-article.sh ~/rw/mnote-data
#
# 任务文件格式（tasks/pending/YYYYMMDD-HHMMSS.md）：
#   ---
#   target: once        # 可选：snow / system / once / toutiao
#   no_publish: false   # 可选：true 则只生成文件不发布
#   no_cover: false     # 可选：true 则不生成头图
#   ---
#
#   https://mp.weixin.qq.com/s/xxx
#   （或其他文章 URL）

set -euo pipefail

MNOTE_DATA="${1:?需要传入 mnote-data 仓库路径}"
WORK_DIR="${2:-$HOME}"
MONITOR_PY="${MONITOR_PY:-$HOME/gitnotes/article/engine/monitor.py}"
LOG_FILE="${LOG_FILE:-$MNOTE_DATA/watch-article.log}"
PYTHON="${PYTHON:-python3}"

PENDING_DIR="$MNOTE_DATA/tasks/pending"
DONE_DIR="$MNOTE_DATA/tasks/done"

# ── 工具函数 ──────────────────────────────────────────────────

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

die() {
  log "ERROR: $*"
  exit 1
}

# 从任务文件提取 frontmatter 字段值
get_field() {
  local file="$1" key="$2"
  # 匹配 frontmatter 中的 key: value（--- 之间）
  awk '/^---/{f=!f; next} f && /^'"$key"':/{
    sub(/^[^:]+:[[:space:]]*/, ""); print; exit
  }' "$file"
}

# 从任务文件提取 URL（去掉 frontmatter 后的第一个非空行）
get_url() {
  local file="$1"
  awk '
    /^---/{f=!f; next}
    !f && /https?:\/\//{print; exit}
  ' "$file"
}

# ── 主流程 ────────────────────────────────────────────────────

cd "$MNOTE_DATA" || die "无法进入 $MNOTE_DATA"

# 1. 拉取最新任务
log "git pull..."
git pull --ff-only 2>&1 | tee -a "$LOG_FILE" || {
  log "WARNING: git pull 失败，继续处理本地任务"
}

# 2. 创建 done 目录
mkdir -p "$DONE_DIR"

# 3. 扫描 pending 任务
shopt -s nullglob
TASKS=("$PENDING_DIR"/*.md)

if [[ ${#TASKS[@]} -eq 0 ]]; then
  log "没有待处理任务"
  exit 0
fi

log "发现 ${#TASKS[@]} 个任务"

# 4. 逐个处理
for TASK_FILE in "${TASKS[@]}"; do
  TASK_NAME="$(basename "$TASK_FILE")"
  log "--- 开始处理: $TASK_NAME ---"

  # 提取 URL
  URL="$(get_url "$TASK_FILE")"
  if [[ -z "$URL" ]]; then
    log "未找到 URL，跳过: $TASK_NAME"
    continue
  fi
  log "URL: $URL"

  # 提取可选参数
  TARGET="$(get_field "$TASK_FILE" target)"
  NO_PUBLISH="$(get_field "$TASK_FILE" no_publish)"
  NO_COVER="$(get_field "$TASK_FILE" no_cover)"

  # 构造 monitor.py 参数
  MONITOR_ARGS=("--url" "$URL")
  [[ -n "$TARGET" ]] && MONITOR_ARGS+=("--target" "$TARGET")
  [[ "$NO_PUBLISH" == "true" ]] && MONITOR_ARGS+=("--no-publish")
  [[ "$NO_COVER" == "true" ]] && MONITOR_ARGS+=("--no-cover")

  log "执行: monitor.py ${MONITOR_ARGS[*]}"

  # 执行改编流程
  START_TS="$(date '+%Y-%m-%d %H:%M:%S')"
  EXIT_CODE=0
  RESULT_OUTPUT=""

  RESULT_OUTPUT="$(
    cd "$WORK_DIR"
    "$PYTHON" "$MONITOR_PY" "${MONITOR_ARGS[@]}" 2>&1
  )" || EXIT_CODE=$?

  END_TS="$(date '+%Y-%m-%d %H:%M:%S')"
  log "完成: $TASK_NAME (exit=$EXIT_CODE)"

  # 5. 写入 done 文件
  DONE_FILE="$DONE_DIR/$TASK_NAME"
  cat > "$DONE_FILE" <<EOF
---
status: $([ "$EXIT_CODE" -eq 0 ] && echo "done" || echo "error")
created: $(get_field "$TASK_FILE" created || date '+%Y-%m-%d %H:%M')
completed: $END_TS
exit_code: $EXIT_CODE
url: $URL
target: ${TARGET:-auto}
---

## 任务

$URL

## 结果

\`\`\`
$RESULT_OUTPUT
\`\`\`
EOF

  # 6. 移除 pending 文件并提交
  git rm "$TASK_FILE" 2>&1 | tee -a "$LOG_FILE"
  git add "$DONE_FILE" 2>&1 | tee -a "$LOG_FILE"
  git commit -m "done: $TASK_NAME (exit=$EXIT_CODE)" 2>&1 | tee -a "$LOG_FILE"
  git push 2>&1 | tee -a "$LOG_FILE" || log "WARNING: git push 失败，结果已保存本地"

  log "--- 任务完成: $TASK_NAME ---"
done
