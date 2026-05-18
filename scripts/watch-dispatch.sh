#!/usr/bin/env bash
# watch-dispatch.sh — 统一任务入口，自动识别任务类型并分发
#
# 用法：watch-dispatch.sh <mnote-data 路径> [工作目录]
#
# 任务类型自动识别规则：
#   第一行内容是纯 URL（http/https）→ rewrite 流程（monitor.py 改编）
#   其他内容（文字、想法、素材）    → create  流程（opencode 自由创作）
#
# 任务文件格式（tasks/pending/YYYYMMDD-HHMMSS.md）：
#
#   [改编文章]
#   ---
#   target: once          # 可选：snow / system / once / toutiao
#   auto_publish: false   # 可选：true=改编后直接发布到草稿箱；false(默认)=只生成到 draft 目录
#   no_cover: false       # 可选
#   ---
#   https://mp.weixin.qq.com/s/xxx
#
#   [自由创作]
#   ---
#   created: 2026-04-27 18:00
#   ---
#   刚看到一个新闻，OpenAI 三个工程师用 AI 写了 100 万行代码，
#   帮我写一篇飘雪思考风格的文章...

set -euo pipefail

MNOTE_DATA="${1:?需要传入 mnote-data 仓库路径}"
WORK_DIR="${2:-$HOME}"

# ── 防并发锁 ───────────────────────────────────────────────────
LOCK_FILE="/tmp/mnote-watch.lock"
if [ -f "$LOCK_FILE" ]; then
  LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null)
  if kill -0 "$LOCK_PID" 2>/dev/null; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 已有实例在运行 (PID $LOCK_PID)，跳过本次" >> "${1:-/tmp}/watch.log" 2>/dev/null || true
    exit 0
  fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="${LOG_FILE:-$MNOTE_DATA/watch.log}"
PENDING_DIR="$MNOTE_DATA/tasks/pending"
DONE_DIR="$MNOTE_DATA/tasks/done"

MONITOR_PY="${MONITOR_PY:-$HOME/gitnotes/article/engine/monitor.py}"
ARTICLE_DIR="${ARTICLE_DIR:-$HOME/gitnotes/article}"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
PYTHON="${PYTHON:-$HOME/miniconda3/bin/python3}"
export PATH="$HOME/miniconda3/bin:$HOME/.bun/bin:$HOME/.opencode/bin:$HOME/.nvm/versions/node/v23.11.0/bin:$PATH"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# ── 从 frontmatter 提取字段 ───────────────────────────────────

get_field() {
  local file="$1" key="$2"
  awk '/^---/{f=!f; next} f && /^'"$key"':/{
    sub(/^[^:]+:[[:space:]]*/, ""); print; exit
  }' "$file"
}

# ── 提取任务正文（去掉 frontmatter 后的内容）────────────────

get_body() {
  local file="$1"
  awk '/^---/{f=!f; next} !f' "$file" | sed '/^[[:space:]]*$/d'
}

# ── 判断是否是纯 URL ─────────────────────────────────────────

is_url() {
  local text="$1"
  # 第一行是 http/https 开头，且整个正文只有这一行（或第一行是 URL）
  local first_line
  first_line="$(echo "$text" | head -1 | tr -d '[:space:]')"
  [[ "$first_line" =~ ^https?:// ]]
}

# ── 写 done 文件并提交 ────────────────────────────────────────

finish_task() {
  local task_file="$1" exit_code="$2" result_content="$3" end_ts="$4"
  local task_name
  task_name="$(basename "$task_file")"
  local done_file="$DONE_DIR/$task_name"
  local created
  created="$(get_field "$task_file" created || date '+%Y-%m-%d %H:%M')"
  local body
  body="$(get_body "$task_file" | head -5)"

  cat > "$done_file" <<EOF
---
status: $([ "$exit_code" -eq 0 ] && echo "done" || echo "error")
created: $created
completed: $end_ts
exit_code: $exit_code
---

## 任务

$body

## 结果

\`\`\`
$result_content
\`\`\`
EOF

  # Remove pending file — works for both tracked and untracked files
  git rm "$task_file" 2>/dev/null || rm -f "$task_file"
  git add "$done_file" 2>&1 | tee -a "$LOG_FILE"
  git commit -m "done: $task_name (exit=$exit_code)" 2>&1 | tee -a "$LOG_FILE"
  git push 2>&1 | tee -a "$LOG_FILE" || log "WARNING: git push 失败，结果已保存本地"
}

# ── rewrite 流程：调用 monitor.py 改编文章 ────────────────────

run_rewrite() {
  local task_file="$1"
  local body
  body="$(get_body "$task_file")"
  local url
  url="$(echo "$body" | head -1 | tr -d '[:space:]')"

  local target no_publish with_cover auto_publish with_image
  target="$(get_field "$task_file" target)"
  no_publish="$(get_field "$task_file" no_publish)"
  with_cover="$(get_field "$task_file" with_cover)"
  auto_publish="$(get_field "$task_file" auto_publish)"
  with_image="$(get_field "$task_file" with_image)"

  local args=("--url" "$url")
  [[ -n "$target" ]] && args+=("--target" "$target")
  [[ "$with_cover" != "true" ]] && args+=("--no-cover")
  # auto_publish: true → 直接发布到草稿箱；默认不发布，只生成到 draft
  [[ "$auto_publish" != "true" ]] && args+=("--no-publish")
  [[ "$with_image" == "true" ]] && args+=("--illustrate")

  log "[rewrite] URL: $url, args: ${args[*]}"

  local output exit_code=0
  output="$(
    cd "$(dirname "$MONITOR_PY")"
    "$PYTHON" "$MONITOR_PY" "${args[@]}" 2>&1
  )" || exit_code=$?

  echo "$output"
  return $exit_code
}

# ── create 流程：调用 monitor.py --text ──────────────────────

run_create() {
  local task_file="$1"
  local body
  body="$(get_body "$task_file" | head -200)"

  local target
  target="$(get_field "$task_file" target)"
  local auto_publish with_cover with_image
  auto_publish="$(get_field "$task_file" auto_publish)"
  with_cover="$(get_field "$task_file" with_cover)"
  with_image="$(get_field "$task_file" with_image)"

  local args=("--text" "$body")
  [[ -n "$target" ]] && args+=("--target" "$target")
  # 只有明确设置 auto_publish: true 才发布，否则 --no-publish
  [[ "$auto_publish" != "true" ]] && args+=("--no-publish")
  [[ "$with_cover" != "true" ]] && args+=("--no-cover")
  [[ "$with_image" == "true" ]] && args+=("--illustrate")

  log "[create] 调用 monitor.py --text..."

  local output exit_code=0
  output="$(
    cd "$(dirname "$MONITOR_PY")"
    "$PYTHON" "$MONITOR_PY" "${args[@]}" 2>&1
  )" || exit_code=$?

  echo "$output"
  return $exit_code
}

# ── file 流程：处理本地 md 文件 ──────────────────────────────
run_file() {
  local task_file="$1"
  local body
  body="$(get_body "$task_file" | head -1 | tr -d '[:space:]')"
  local file_path
  file_path="$(eval echo "$body")"  # expand ~/

  local target auto_publish with_cover with_image
  target="$(get_field "$task_file" target)"
  auto_publish="$(get_field "$task_file" auto_publish)"
  with_cover="$(get_field "$task_file" with_cover)"
  with_image="$(get_field "$task_file" with_image)"

  local args=("--file" "$file_path")
  [[ -n "$target" ]] && args+=("--target" "$target")
  [[ "$with_cover" != "true" ]] && args+=("--no-cover")
  [[ "$auto_publish" != "true" ]] && args+=("--no-publish")
  [[ "$with_image" == "true" ]] && args+=("--diagram")

  log "[file] 处理本地文件: $file_path, args: ${args[*]}"

  local output exit_code=0
  output="$(
    cd "$(dirname "$MONITOR_PY")"
    "$PYTHON" "$MONITOR_PY" "${args[@]}" 2>&1
  )" || exit_code=$?

  echo "$output"
  return $exit_code
}

# ── mini 流程：生成竖图并发布为微信图文 ──────────────────────
run_mini() {
  local task_file="$1"
  local body
  body="$(get_body "$task_file" | head -1 | tr -d '[:space:]')"
  local file_path
  file_path="$(eval echo "$body")"  # expand ~/

  local target auto_publish
  target="$(get_field "$task_file" target)"
  auto_publish="$(get_field "$task_file" auto_publish)"

  local args=("--mini" "$file_path")
  [[ -n "$target" ]] && args+=("--target" "$target")
  [[ "$auto_publish" != "true" ]] && args+=("--no-publish")

  log "[mini] 处理图文文件: $file_path"

  local output exit_code=0
  output="$(
    cd "$(dirname "$MONITOR_PY")"
    "$PYTHON" "$MONITOR_PY" "${args[@]}" 2>&1
  )" || exit_code=$?

  echo "$output"
  return $exit_code
}

# ── 主流程 ────────────────────────────────────────────────────

cd "$MNOTE_DATA" || { log "ERROR: 无法进入 $MNOTE_DATA"; exit 1; }

log "git pull..."
# 只 stash tracked 文件的改动，不动 untracked 的 pending 任务文件
git stash 2>/dev/null || true
git pull --ff-only 2>&1 | tee -a "$LOG_FILE" || log "WARNING: git pull 失败，继续处理本地任务"
git stash pop 2>/dev/null || true

mkdir -p "$PENDING_DIR" "$DONE_DIR"

shopt -s nullglob
TASKS=("$PENDING_DIR"/*.md)

if [[ ${#TASKS[@]} -eq 0 ]]; then
  log "没有待处理任务"
  exit 0
fi

log "发现 ${#TASKS[@]} 个任务"

for TASK_FILE in "${TASKS[@]}"; do
  TASK_NAME="$(basename "$TASK_FILE")"
  log "--- 开始处理: $TASK_NAME ---"

  BODY="$(get_body "$TASK_FILE")"

  if [[ -z "$BODY" ]]; then
    log "任务内容为空，跳过: $TASK_NAME"
    continue
  fi

  log "内容预览: ${BODY:0:80}..."

  EXIT_CODE=0
  RESULT=""
  END_TS="$(date '+%Y-%m-%d %H:%M:%S')"

  FIRST_LINE="$(echo "$BODY" | head -1 | tr -d '[:space:]')"

  TASK_TYPE="$(get_field "$TASK_FILE" task_type)"

  if [[ "$FIRST_LINE" =~ ^https?:// ]]; then
    log "类型: rewrite（URL 改编）"
    RESULT="$(run_rewrite "$TASK_FILE")" || EXIT_CODE=$?
  elif [[ "$TASK_TYPE" == "mini" || "$FIRST_LINE" =~ ^[/~].*mini ]]; then
    log "类型: mini（图文）"
    RESULT="$(run_mini "$TASK_FILE")" || EXIT_CODE=$?
  elif [[ "$FIRST_LINE" =~ ^[/~] ]]; then
    log "类型: file（本地文件）"
    RESULT="$(run_file "$TASK_FILE")" || EXIT_CODE=$?
  else
    log "类型: create（自由创作）"
    RESULT="$(run_create "$TASK_FILE")" || EXIT_CODE=$?
  fi

  END_TS="$(date '+%Y-%m-%d %H:%M:%S')"
  log "完成: $TASK_NAME (exit=$EXIT_CODE)"

  finish_task "$TASK_FILE" "$EXIT_CODE" "$RESULT" "$END_TS"
  log "--- 任务结束: $TASK_NAME ---"
done
