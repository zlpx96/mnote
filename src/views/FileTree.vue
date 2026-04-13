<template>
  <div class="page">
    <header class="page-header">
      <button class="back-btn" @click="handleBack">←</button>
      <div class="breadcrumb">
        <span @click="navigateTo('')" class="crumb">{{ route.params.repo }}</span>
        <template v-for="(seg, i) in pathSegments" :key="i">
          <span class="sep">/</span>
          <span @click="navigateTo(pathSegments.slice(0, i+1).join('/'))" class="crumb">{{ seg }}</span>
        </template>
      </div>
      <button class="new-btn" @click="showNew = true">＋</button>
    </header>

    <!-- 新建文档弹窗 -->
    <div v-if="showNew" class="modal-overlay" @click.self="closeNew">
      <div class="modal">
        <h2>新建文档</h2>
        <div class="modal-path">位置：{{ currentPath || '根目录' }}</div>
        <input
          v-model="newFileName"
          placeholder="文件名（无需加 .md）"
          :disabled="newSaving"
          @keyup.enter="newContent ? null : null"
        />
        <textarea
          v-model="newContent"
          placeholder="内容（可选，支持 Markdown）"
          class="new-textarea"
          :disabled="newSaving"
        />
        <p v-if="newError" class="error">{{ newError }}</p>
        <div class="modal-actions">
          <button class="cancel-btn" @click="closeNew" :disabled="newSaving">取消</button>
          <button @click="handleCreate" :disabled="newSaving || !newFileName.trim()">
            {{ newSaving ? '创建中...' : '创建' }}
          </button>
        </div>
      </div>
    </div>

    <div v-if="loading" class="loading">加载中...</div>
    <div v-else-if="error" class="error-msg">{{ error }}</div>
    <div v-else-if="items.length === 0" class="empty">此目录为空</div>

    <ul v-else class="file-list">
      <li
        v-for="item in sortedItems"
        :key="item.path"
        class="file-item"
        :class="{ disabled: item.type === 'file' && !item.name.endsWith('.md') }"
        @click="handleClick(item)"
      >
        <span class="file-icon">{{ item.type === 'dir' ? '📁' : item.name.endsWith('.md') ? '📄' : '·' }}</span>
        <span class="file-name">{{ item.name }}</span>
      </li>
    </ul>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useStorage } from '../composables/useStorage.js'
import { useGitHub } from '../composables/useGitHub.js'

const router = useRouter()

function handleBack() {
  if (window.history.state?.back?.startsWith('/')) {
    router.back()
  } else {
    router.push('/')
  }
}
const route = useRoute()
const { getToken } = useStorage()

const items = ref([])
const showNew = ref(false)
const newFileName = ref('')
const newContent = ref('')
const newSaving = ref(false)
const newError = ref('')

function closeNew() {
  showNew.value = false
  newFileName.value = ''
  newContent.value = ''
  newError.value = ''
}

async function handleCreate() {
  const name = newFileName.value.trim()
  const fileName = name.endsWith('.md') ? name : `${name}.md`
  const filePath = currentPath.value ? `${currentPath.value}/${fileName}` : fileName

  newSaving.value = true
  newError.value = ''
  try {
    const { putFile } = useGitHub(getToken())
    await putFile(route.params.owner, route.params.repo, filePath, newContent.value)
    closeNew()
    await loadContents(currentPath.value)
    router.push(`/repo/${route.params.owner}/${route.params.repo}/file/${filePath}`)
  } catch (e) {
    if (e.message === 'UNAUTHORIZED') {
      router.push('/setup')
    } else {
      newError.value = '创建失败：' + e.message
    }
  } finally {
    newSaving.value = false
  }
}
const loading = ref(false)
const error = ref('')
const currentPath = ref('')

const pathSegments = computed(() =>
  currentPath.value ? currentPath.value.split('/') : []
)

const sortedItems = computed(() => {
  const dirs = items.value.filter(i => i.type === 'dir')
  const files = items.value.filter(i => i.type === 'file')
  return [...dirs, ...files]
})

async function loadContents(path) {
  loading.value = true
  error.value = ''
  items.value = []
  try {
    const { getContents } = useGitHub(getToken())
    const data = await getContents(route.params.owner, route.params.repo, path)
    items.value = Array.isArray(data) ? data : [data]
  } catch (e) {
    if (e.message === 'UNAUTHORIZED') {
      router.push('/setup')
    } else if (e.message.startsWith('RATE_LIMIT:')) {
      const reset = new Date(parseInt(e.message.split(':')[1]) * 1000)
      error.value = `API 限流，请在 ${reset.toLocaleTimeString()} 后重试`
    } else {
      error.value = '加载失败：' + e.message
    }
  } finally {
    loading.value = false
  }
}

function navigateTo(path) {
  currentPath.value = path
  loadContents(path)
}

function handleClick(item) {
  if (item.type === 'dir') {
    navigateTo(item.path)
  } else if (item.name.endsWith('.md')) {
    router.push(`/repo/${route.params.owner}/${route.params.repo}/file/${item.path}`)
  }
}

onMounted(() => loadContents(''))
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

.back-btn {
  background: none;
  border: none;
  font-size: 20px;
  color: #0969da;
  padding: 4px;
}

.new-btn {
  background: none;
  border: none;
  font-size: 22px;
  color: #0969da;
  padding: 4px;
  margin-left: auto;
  flex-shrink: 0;
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
  max-height: 85vh;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.modal h2 {
  font-size: 18px;
  font-weight: 700;
}

.modal-path {
  font-size: 13px;
  color: #999;
}

.modal input {
  width: 100%;
  padding: 10px 12px;
  border: 1px solid #d0d7de;
  border-radius: 8px;
  font-size: 15px;
  outline: none;
}

.modal input:focus {
  border-color: #0969da;
  box-shadow: 0 0 0 3px rgba(9,105,218,0.1);
}

.new-textarea {
  width: 100%;
  min-height: 200px;
  padding: 10px 12px;
  border: 1px solid #d0d7de;
  border-radius: 8px;
  font-size: 15px;
  line-height: 1.6;
  resize: vertical;
  outline: none;
  font-family: inherit;
}

.new-textarea:focus {
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

.modal-actions button:disabled {
  opacity: 0.5;
}

.cancel-btn {
  background: #f0f0f0 !important;
  color: #333 !important;
}

.breadcrumb {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 2px;
  font-size: 14px;
  overflow: hidden;
}

.crumb {
  color: #0969da;
  cursor: pointer;
  white-space: nowrap;
  max-width: 120px;
  overflow: hidden;
  text-overflow: ellipsis;
}

.sep {
  color: #999;
}

.loading, .error-msg, .empty {
  text-align: center;
  padding: 48px 24px;
  color: #666;
}

.error-msg {
  color: #d1242f;
}

.file-list {
  list-style: none;
  background: white;
  margin: 12px;
  border-radius: 10px;
  overflow: hidden;
  box-shadow: 0 1px 4px rgba(0,0,0,0.06);
}

.file-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 14px 16px;
  border-bottom: 1px solid #f0f0f0;
  cursor: pointer;
}

.file-item:last-child {
  border-bottom: none;
}

.file-item.disabled {
  cursor: default;
  opacity: 0.4;
}

.file-icon {
  font-size: 18px;
  flex-shrink: 0;
}

.file-name {
  font-size: 15px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>
