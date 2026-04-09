<template>
  <div class="page">
    <header class="page-header">
      <h1>我的仓库</h1>
      <div class="header-actions">
        <button class="icon-btn" @click="showSearch = true">＋</button>
        <button class="icon-btn" @click="handleReset" title="重置 Token">⚙</button>
      </div>
    </header>

    <div v-if="repos.length === 0" class="empty">
      <p>还没有添加仓库</p>
      <button @click="showSearch = true">添加仓库</button>
    </div>

    <ul v-else class="repo-list">
      <li v-for="repo in repos" :key="repo.full_name" class="repo-card">
        <div class="repo-info" @click="router.push(`/repo/${repo.full_name.split('/')[0]}/${repo.full_name.split('/')[1]}`)">
          <div class="repo-name">{{ repo.full_name }}</div>
          <div class="repo-desc">{{ repo.description || '无描述' }}</div>
        </div>
        <button class="remove-btn" @click.stop="handleRemove(repo.full_name)">✕</button>
      </li>
    </ul>

    <!-- 搜索弹窗 -->
    <div v-if="showSearch" class="modal-overlay" @click.self="showSearch = false">
      <div class="modal">
        <h2>添加仓库</h2>
        <input
          v-model="searchQuery"
          placeholder="搜索仓库名..."
          @keyup.enter="handleSearch"
          :disabled="searching"
        />
        <button @click="handleSearch" :disabled="searching || !searchQuery.trim()">
          {{ searching ? '搜索中...' : '搜索' }}
        </button>
        <p v-if="searchError" class="error">{{ searchError }}</p>
        <ul v-if="searchResults.length" class="search-results">
          <li
            v-for="r in searchResults"
            :key="r.full_name"
            @click="handleAdd(r)"
            class="search-result-item"
          >
            <span class="result-name">{{ r.full_name }}</span>
            <span v-if="r.private" class="badge">私有</span>
          </li>
        </ul>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useStorage } from '../composables/useStorage.js'
import { useGitHub } from '../composables/useGitHub.js'

const router = useRouter()
const { getToken, clearToken, getRepos, addRepo, removeRepo } = useStorage()

const repos = ref([])
const showSearch = ref(false)
const searchQuery = ref('')
const searchResults = ref([])
const searching = ref(false)
const searchError = ref('')

onMounted(() => {
  repos.value = getRepos()
})

function handleRemove(fullName) {
  removeRepo(fullName)
  repos.value = getRepos()
}

function handleReset() {
  if (confirm('重置 Token 后需要重新登录，确认吗？')) {
    clearToken()
    router.push('/setup')
  }
}

async function handleSearch() {
  searching.value = true
  searchError.value = ''
  searchResults.value = []
  try {
    const { searchRepos } = useGitHub(getToken())
    searchResults.value = await searchRepos(searchQuery.value.trim())
  } catch {
    searchError.value = '搜索失败，请重试'
  } finally {
    searching.value = false
  }
}

function handleAdd(repo) {
  addRepo(repo)
  repos.value = getRepos()
  showSearch.value = false
  searchQuery.value = ''
  searchResults.value = []
}
</script>

<style scoped>
.page {
  min-height: 100vh;
  background: #f5f5f5;
}

.page-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px;
  background: white;
  border-bottom: 1px solid #e0e0e0;
  position: sticky;
  top: 0;
}

.page-header h1 {
  font-size: 20px;
  font-weight: 700;
}

.header-actions {
  display: flex;
  gap: 8px;
}

.icon-btn {
  background: none;
  border: none;
  font-size: 20px;
  padding: 4px 8px;
  color: #0969da;
}

.empty {
  text-align: center;
  padding: 64px 24px;
  color: #666;
}

.empty button {
  margin-top: 16px;
  padding: 10px 24px;
  background: #0969da;
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 15px;
}

.repo-list {
  list-style: none;
  padding: 12px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.repo-card {
  background: white;
  border-radius: 10px;
  padding: 14px 12px;
  display: flex;
  align-items: center;
  box-shadow: 0 1px 4px rgba(0,0,0,0.06);
}

.repo-info {
  flex: 1;
  cursor: pointer;
}

.repo-name {
  font-weight: 600;
  font-size: 15px;
}

.repo-desc {
  font-size: 13px;
  color: #666;
  margin-top: 2px;
}

.remove-btn {
  background: none;
  border: none;
  color: #999;
  font-size: 16px;
  padding: 4px 8px;
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
  max-height: 70vh;
  overflow-y: auto;
}

.modal h2 {
  font-size: 18px;
  margin-bottom: 16px;
}

.modal input {
  width: 100%;
  padding: 10px 12px;
  border: 1px solid #d0d7de;
  border-radius: 8px;
  font-size: 15px;
  margin-bottom: 8px;
  outline: none;
}

.modal button {
  width: 100%;
  padding: 10px;
  background: #0969da;
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 15px;
}

.modal button:disabled {
  opacity: 0.5;
}

.error {
  color: #d1242f;
  font-size: 14px;
  margin-top: 8px;
}

.search-results {
  list-style: none;
  margin-top: 12px;
}

.search-result-item {
  padding: 12px 4px;
  border-bottom: 1px solid #f0f0f0;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 8px;
}

.result-name {
  flex: 1;
  font-size: 15px;
}

.badge {
  font-size: 11px;
  background: #f0f0f0;
  padding: 2px 6px;
  border-radius: 4px;
  color: #666;
}
</style>
