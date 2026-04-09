<template>
  <div class="page">
    <header class="page-header">
      <button class="back-btn" @click="router.back()">←</button>
      <div class="breadcrumb">
        <span @click="navigateTo('')" class="crumb">{{ route.params.repo }}</span>
        <template v-for="(seg, i) in pathSegments" :key="i">
          <span class="sep">/</span>
          <span @click="navigateTo(pathSegments.slice(0, i+1).join('/'))" class="crumb">{{ seg }}</span>
        </template>
      </div>
    </header>

    <div v-if="loading" class="loading">加载中...</div>
    <div v-else-if="error" class="error-msg">{{ error }}</div>
    <div v-else-if="items.length === 0" class="empty">此目录为空或没有 .md 文件</div>

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
const route = useRoute()
const { getToken } = useStorage()

const items = ref([])
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
    if (e.message.startsWith('RATE_LIMIT:')) {
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
