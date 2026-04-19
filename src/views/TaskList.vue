<template>
  <div class="page">
    <header class="page-header">
      <button class="back-btn" @click="router.push('/')">←</button>
      <h1>任务</h1>
      <button class="new-btn" @click="showNew = true">＋</button>
    </header>

    <!-- 新建任务弹窗 -->
    <div v-if="showNew" class="modal-overlay" @click.self="closeNew">
      <div class="modal">
        <h2>发送任务</h2>
        <textarea
          v-model="newTask"
          placeholder="描述你想让远程电脑执行的任务..."
          class="task-textarea"
          :disabled="sending"
          autofocus
        />
        <p v-if="sendError" class="error">{{ sendError }}</p>
        <div class="modal-actions">
          <button class="cancel-btn" @click="closeNew" :disabled="sending">取消</button>
          <button @click="handleSend" :disabled="sending || !newTask.trim()">
            {{ sending ? '发送中...' : '发送' }}
          </button>
        </div>
      </div>
    </div>

    <div v-if="loading" class="loading">加载中...</div>
    <div v-else-if="loadError" class="error-msg">{{ loadError }}</div>
    <div v-else-if="tasks.length === 0" class="empty">还没有任务</div>

    <div v-else class="task-list">
      <!-- pending -->
      <div v-if="pendingTasks.length" class="section">
        <div class="section-title">待执行（{{ pendingTasks.length }}）</div>
        <ul>
          <li v-for="task in pendingTasks" :key="task.path" class="task-item pending">
            <div class="task-meta">{{ task.created }}</div>
            <div class="task-desc">{{ task.desc }}</div>
          </li>
        </ul>
      </div>

      <!-- done -->
      <div v-if="doneTasks.length" class="section">
        <div class="section-title">已完成（{{ doneTasks.length }}）</div>
        <ul>
          <li
            v-for="task in doneTasks"
            :key="task.path"
            class="task-item done"
            @click="router.push(`/repo/${NOTE_OWNER}/${NOTE_REPO}/file/${task.path}`)"
          >
            <div class="task-meta">{{ task.created }}</div>
            <div class="task-desc">{{ task.desc }}</div>
          </li>
        </ul>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useStorage } from '../composables/useStorage.js'
import { useGitHub } from '../composables/useGitHub.js'

const NOTE_OWNER = 'zlpx96'
const NOTE_REPO = 'mnote-data'

const router = useRouter()
const { getToken } = useStorage()

const tasks = ref([])
const loading = ref(false)
const loadError = ref('')
const showNew = ref(false)
const newTask = ref('')
const sending = ref(false)
const sendError = ref('')

const pendingTasks = computed(() => tasks.value.filter(t => t.status === 'pending'))
const doneTasks = computed(() => tasks.value.filter(t => t.status === 'done'))

function closeNew() {
  showNew.value = false
  newTask.value = ''
  sendError.value = ''
}

function formatDate(d) {
  return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')} ${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`
}

async function loadTasks() {
  loading.value = true
  loadError.value = ''
  tasks.value = []
  try {
    const { getContents, getFileContent } = useGitHub(getToken())

    // 读 pending 和 done 两个目录
    const dirs = ['tasks/pending', 'tasks/done']
    for (const dir of dirs) {
      let files = []
      try {
        const data = await getContents(NOTE_OWNER, NOTE_REPO, dir)
        files = Array.isArray(data) ? data : [data]
      } catch {
        continue // 目录不存在时跳过
      }
      for (const file of files.filter(f => f.name.endsWith('.md'))) {
        try {
          const text = await getFileContent(NOTE_OWNER, NOTE_REPO, file.path)
          const descMatch = text.replace(/^---[\s\S]*?---\n?/, '').trim()
          const createdMatch = text.match(/created:\s*(.+)/)
          tasks.value.push({
            path: file.path,
            status: dir.includes('pending') ? 'pending' : 'done',
            desc: descMatch.split('\n')[0].slice(0, 80),
            created: createdMatch ? createdMatch[1].trim() : file.name,
          })
        } catch {
          // 单个文件读取失败跳过
        }
      }
    }
    // 按时间倒序
    tasks.value.sort((a, b) => b.created.localeCompare(a.created))
  } catch (e) {
    if (e.message === 'UNAUTHORIZED') {
      router.push('/setup')
    } else {
      loadError.value = '加载失败：' + e.message
    }
  } finally {
    loading.value = false
  }
}

async function handleSend() {
  sending.value = true
  sendError.value = ''
  const now = new Date()
  const ts = `${now.getFullYear()}${String(now.getMonth()+1).padStart(2,'0')}${String(now.getDate()).padStart(2,'0')}-${String(now.getHours()).padStart(2,'0')}${String(now.getMinutes()).padStart(2,'0')}${String(now.getSeconds()).padStart(2,'0')}`
  const filePath = `tasks/pending/${ts}.md`
  const fileContent = `---\nstatus: pending\ncreated: ${formatDate(now)}\n---\n\n${newTask.value.trim()}\n`

  try {
    const { putFile } = useGitHub(getToken())
    await putFile(NOTE_OWNER, NOTE_REPO, filePath, fileContent)
    closeNew()
    await loadTasks()
  } catch (e) {
    if (e.message === 'UNAUTHORIZED') {
      router.push('/setup')
    } else {
      sendError.value = '发送失败：' + e.message
    }
  } finally {
    sending.value = false
  }
}

onMounted(loadTasks)
</script>

<style scoped>
.page {
  min-height: 100vh;
  background: #f5f5f5;
}

.page-header {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px 16px;
  background: white;
  border-bottom: 1px solid #e0e0e0;
  position: sticky;
  top: 0;
}

.page-header h1 {
  font-size: 18px;
  font-weight: 700;
  flex: 1;
}

.back-btn, .new-btn {
  background: none;
  border: none;
  font-size: 20px;
  color: #0969da;
  padding: 4px 8px;
}

.loading, .error-msg, .empty {
  text-align: center;
  padding: 48px 24px;
  color: #666;
}

.error-msg { color: #d1242f; }

.task-list {
  padding: 12px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.section-title {
  font-size: 13px;
  font-weight: 600;
  color: #666;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin-bottom: 6px;
}

ul { list-style: none; }

.task-item {
  background: white;
  border-radius: 10px;
  padding: 14px 16px;
  margin-bottom: 8px;
  box-shadow: 0 1px 4px rgba(0,0,0,0.06);
  border-left: 4px solid #e0e0e0;
}

.task-item.pending {
  border-left-color: #e3a008;
}

.task-item.done {
  border-left-color: #1a7f37;
  cursor: pointer;
}

.task-meta {
  font-size: 12px;
  color: #999;
  margin-bottom: 4px;
}

.task-desc {
  font-size: 15px;
  color: #1a1a1a;
  line-height: 1.5;
}

.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.4);
  display: flex;
  align-items: flex-end;
  z-index: 100;
}

.modal {
  background: white;
  border-radius: 16px 16px 0 0;
  padding: 24px 16px;
  width: 100%;
  max-height: 80vh;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.modal h2 {
  font-size: 18px;
  font-weight: 700;
}

.task-textarea {
  width: 100%;
  min-height: 160px;
  padding: 10px 12px;
  border: 1px solid #d0d7de;
  border-radius: 8px;
  font-size: 15px;
  line-height: 1.6;
  resize: vertical;
  outline: none;
  font-family: inherit;
}

.task-textarea:focus {
  border-color: #0969da;
  box-shadow: 0 0 0 3px rgba(9,105,218,0.1);
}

.error {
  color: #d1242f;
  font-size: 14px;
}

.modal-actions {
  display: flex;
  gap: 8px;
}

.modal-actions button {
  flex: 1;
  padding: 11px;
  border: none;
  border-radius: 8px;
  font-size: 15px;
  font-weight: 500;
  background: #0969da;
  color: white;
}

.modal-actions button:disabled { opacity: 0.5; }

.cancel-btn {
  background: #f0f0f0 !important;
  color: #333 !important;
}
</style>
