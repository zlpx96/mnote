#!/usr/bin/env bash
# watch.sh — 检测 mnote-data 新任务并用 Claude Code 执行
# 用法：watch.sh <mnote-data 本地路径> [工作目录]
# 示例：watch.sh ~/mnote-data ~/projects

set -euo pipefail

MNOTE_DATA="${1:?需要传入 mnote-data 仓库路径}"
WORK_DIR="${2:-$HOME}"
CLAUDE_BIN="${CLAUDE_BIN:-opencode run}"
LOG_FILE="${LOG_FILE:-$MNOTE_DATA/watch.log}"
ARTICLE_DIR="${ARTICLE_DIR:-$HOME/gitnotes/article}"

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

  # 判断是否是公众号写作任务：article 目录存在则注入写作上下文
  FULL_PROMPT="$PROMPT"
  if [[ -d "$ARTICLE_DIR" ]]; then
    README="$ARTICLE_DIR/README.md"
    AGENTS="$ARTICLE_DIR/AGENTS.md"
    REQ="$ARTICLE_DIR/config/requirement.md"
    REQ_ONCE="$ARTICLE_DIR/config/requirement_once.md"
    TMPL="$ARTICLE_DIR/config/template.md"
    TMPL_SNOW="$ARTICLE_DIR/config/template_snow.md"

    FULL_PROMPT="$(cat <<TASK_EOF
你是一位公众号写作助手。用户通过手机发来了一段素材，请根据素材内容自动判断最适合的文章类型和目标公众号，然后完整创作一篇文章并保存到正确目录。

## 用户素材

$PROMPT

## 目录结构与规范

$(cat "$README" 2>/dev/null || echo '（README 不存在）')

## 写作经验（AGENTS.md）

$(cat "$AGENTS" 2>/dev/null || echo '（AGENTS 不存在）')

## 飘雪思考 / 思维体系写作要求

$(cat "$REQ" 2>/dev/null || echo '（requirement.md 不存在）')

## 从前的事写作要求

$(cat "$REQ_ONCE" 2>/dev/null || echo '（requirement_once.md 不存在）')

## 飘雪思考文章模板

$(cat "$TMPL_SNOW" 2>/dev/null || echo '（template_snow.md 不存在）')

## 思维体系文章模板

$(cat "$TMPL" 2>/dev/null || echo '（template.md 不存在）')

## 执行要求

**重要：这是全自动无人值守模式，不能暂停等待用户确认，必须一次性完成所有步骤。**

1. 判断素材适合哪个公众号（飘雪思考 / 思维体系 / 从前的事 stories/mini/essay）及对应分类子目录
2. 自主选定一个最合适的方向和标题，不要列出选项等待确认
3. 按对应写作要求完整创作文章正文（不少于要求字数，不要只列大纲）
4. 将文章保存到 $ARTICLE_DIR 下的正确目录（参考 README.md 中的归档规则）
5. 文件名用文章主标题命名（.md 后缀）
6. 飘雪思考 / 思维体系的新文章先放 $ARTICLE_DIR/temp/ 目录
7. 从前的事的新文章直接放对应分类目录
8. 最后输出：文章类型、保存路径、文章标题
TASK_EOF
)"
  fi

  # 执行 Claude Code，输出写入临时文件
  RESULT_TMP="$(mktemp)"
  START_TS="$(date '+%Y-%m-%d %H:%M:%S')"
  EXIT_CODE=0

  (
    cd "$WORK_DIR"
    $CLAUDE_BIN "$FULL_PROMPT" 2>&1
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
