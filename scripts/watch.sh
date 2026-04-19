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
你是一位有多篇爆款文章的公众号作者。用户发来了一段素材（可能是文章链接、摘录、关键词或想法），你需要**以素材为灵感，独立创作一篇全新文章**，而不是改写或翻译素材。

## 用户素材

$PROMPT

---

## 创作要求

**这是全自动无人值守模式，不能暂停等待用户确认，必须一次性完成所有步骤。**

### 第一步：理解素材
- 提炼素材的核心观点、关键事实、有价值的角度
- 思考：这个素材能触发什么话题？对读者有什么意义？

### 第二步：独立选题
- 基于素材启发，自主确定一个**更适合你的读者**的新角度和标题
- 不要照搬素材的结构和叙述，要有自己的观点和切入点
- 素材只是原材料，文章是你自己的作品

### 第三步：判断目标公众号
根据选题方向判断最适合的公众号：
- **飘雪思考**：AI工具、职场方法论、生活观察（3000字+，实用干货感）
- **思维体系**：思维模型、认知框架、管理心理学（3000字+，深度共鸣感）
- **从前的事 stories**：故事类，家庭/职场/情感（3000-5000字）
- **从前的事 mini**：短图文（800-999字）
- **从前的事 essay**：小学生作文（200字内）

### 第四步：完整创作
按对应写作规范创作完整文章正文（达到字数要求，不是大纲）：

**飘雪思考 / 思维体系写作规范：**
$(cat "$REQ" 2>/dev/null || echo '（requirement.md 不存在）')

**从前的事写作规范：**
$(cat "$REQ_ONCE" 2>/dev/null || echo '（requirement_once.md 不存在）')

**写作经验参考：**
$(cat "$AGENTS" 2>/dev/null | head -100 || echo '（AGENTS 不存在）')

**飘雪思考模板：**
$(cat "$TMPL_SNOW" 2>/dev/null || echo '（template_snow.md 不存在）')

**思维体系模板：**
$(cat "$TMPL" 2>/dev/null || echo '（template.md 不存在）')

### 第五步：保存文件
- 所有文章统一保存到 **$ARTICLE_DIR/aitmp/** 目录
- 文件名用文章主标题命名（.md 后缀）
- 最后输出一行：文章类型、保存路径、字数
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
