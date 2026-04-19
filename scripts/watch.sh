#!/usr/bin/env bash
# watch.sh — 检测 mnote-data 新任务并用 Claude Code 执行
# 用法：watch.sh <mnote-data 本地路径> [工作目录]
# 示例：watch.sh ~/mnote-data ~/projects

set -euo pipefail

MNOTE_DATA="${1:?需要传入 mnote-data 仓库路径}"
WORK_DIR="${2:-$HOME}"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
LOG_FILE="${LOG_FILE:-$MNOTE_DATA/watch.log}"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

die() {
  log "ERROR: $*"
  exit 1
}

cd "$MNOTE_DATA" || die "无法进入 $MNOTE_DATA"

# 拉取最新
log "git pull..."
git pull --ff-only 2>&1 | tee -a "$LOG_FILE" || die "git pull 失败"

PENDING_DIR="$MNOTE_DATA/tasks/pending"
DONE_DIR="$MNOTE_DATA/tasks/done"
mkdir -p "$DONE_DIR"

# 找所有 pending 任务
shopt -s nullglob
TASKS=("$PENDING_DIR"/*.md)

if [[ ${#TASKS[@]} -eq 0 ]]; then
  log "没有待执行任务"
  exit 0
fi

log "发现 ${#TASKS[@]} 个任务"

for TASK_FILE in "${TASKS[@]}"; do
  TASK_NAME="$(basename "$TASK_FILE")"
  log "--- 开始执行任务: $TASK_NAME ---"

  # 读取任务内容（去掉 frontmatter）
  PROMPT="$(awk '/^---/{f=!f; next} !f' "$TASK_FILE" | sed '/^[[:space:]]*$/d' | head -200)"

  if [[ -z "$PROMPT" ]]; then
    log "任务内容为空，跳过: $TASK_NAME"
    continue
  fi

  log "任务内容: ${PROMPT:0:100}..."

  # 执行 Claude Code，输出写入临时文件
  RESULT_TMP="$(mktemp)"
  START_TS="$(date '+%Y-%m-%d %H:%M:%S')"
  EXIT_CODE=0

  (
    cd "$WORK_DIR"
    "$CLAUDE_BIN" --print --dangerously-skip-permissions "$PROMPT" 2>&1
  ) > "$RESULT_TMP" || EXIT_CODE=$?

  END_TS="$(date '+%Y-%m-%d %H:%M:%S')"
  RESULT_CONTENT="$(cat "$RESULT_TMP")"
  rm -f "$RESULT_TMP"

  # 构建 done 文件内容
  DONE_FILE="$DONE_DIR/$TASK_NAME"
  ORIG_FRONT="$(sed -n '/^---/,/^---/p' "$TASK_FILE" | head -20)"

  cat > "$DONE_FILE" <<EOF
---
status: done
created: $(grep 'created:' "$TASK_FILE" | head -1 | sed 's/created: *//')
completed: $END_TS
exit_code: $EXIT_CODE
---

## 任务

$PROMPT

## 结果

\`\`\`
$RESULT_CONTENT
\`\`\`
EOF

  # 移除 pending 文件
  git rm "$TASK_FILE" 2>&1 | tee -a "$LOG_FILE"
  git add "$DONE_FILE" 2>&1 | tee -a "$LOG_FILE"
  git commit -m "done: $TASK_NAME (exit=$EXIT_CODE)" 2>&1 | tee -a "$LOG_FILE"
  git push 2>&1 | tee -a "$LOG_FILE"

  log "--- 任务完成: $TASK_NAME (exit=$EXIT_CODE) ---"
done
