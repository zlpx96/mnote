# mnote Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个 Vue 3 PWA，通过 GitHub API 浏览私有仓库中的 Markdown 文件，支持多仓库切换，部署到 GitHub Pages。

**Architecture:** 纯前端 SPA，无后端。Token 存储在 localStorage，所有 GitHub API 请求从浏览器直接发出。Vue Router 管理四个页面：Setup → RepoList → FileTree → MarkdownView。

**Tech Stack:** Vue 3, Vite, Vue Router 4, marked.js, GitHub REST API v3

---

## File Map

| 文件 | 职责 |
|------|------|
| `mnote/index.html` | HTML 入口 |
| `mnote/vite.config.js` | Vite 配置（base path for GitHub Pages） |
| `mnote/public/manifest.json` | PWA manifest |
| `mnote/public/sw.js` | Service Worker，缓存 MD 文件 |
| `mnote/src/main.js` | Vue app 入口，挂载 router |
| `mnote/src/App.vue` | 根组件，router-view |
| `mnote/src/router/index.js` | 路由定义，守卫（未设置 token 跳转 setup） |
| `mnote/src/composables/useStorage.js` | localStorage 读写：token、repo 列表 |
| `mnote/src/composables/useGitHub.js` | GitHub API 封装：validateToken、listRepos、getContents、getFileContent |
| `mnote/src/views/Setup.vue` | Token 输入页，验证后跳转 |
| `mnote/src/views/RepoList.vue` | 仓库列表，添加/删除仓库 |
| `mnote/src/views/FileTree.vue` | 文件树，breadcrumb 导航，展开目录 |
| `mnote/src/views/MarkdownView.vue` | MD 渲染页，marked.js |
| `mnote/src/assets/main.css` | 全局样式，手机阅读优化 |

---

## Task 1: 项目脚手架

**Files:**
- Create: `mnote/` (Vite 项目)
- Modify: `mnote/vite.config.js`
- Create: `mnote/src/assets/main.css`

- [ ] **Step 1: 初始化 Vue 3 + Vite 项目**

```bash
cd /Users/fusong/ClaudeCode/mnote
npm create vite@latest . -- --template vue
npm install
npm install vue-router@4 marked
```

Expected: 项目文件生成，`node_modules` 安装完成

- [ ] **Step 2: 配置 vite.config.js（GitHub Pages base path）**

编辑 `mnote/vite.config.js`：

```js
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  base: '/mnote/',
})
```

- [ ] **Step 3: 清理默认文件**

删除 `src/components/HelloWorld.vue`、`src/assets/vue.svg`、`public/vite.svg`。

清空 `src/App.vue` 为：

```vue
<template>
  <router-view />
</template>
```

清空 `src/style.css`（或删除），创建 `src/assets/main.css`：

```css
*, *::before, *::after {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  font-size: 16px;
  line-height: 1.6;
  color: #1a1a1a;
  background: #f5f5f5;
}

a {
  color: #0969da;
  text-decoration: none;
}

button {
  cursor: pointer;
}
```

- [ ] **Step 4: 更新 main.js**

```js
import { createApp } from 'vue'
import App from './App.vue'
import router from './router/index.js'
import './assets/main.css'

createApp(App).use(router).mount('#app')
```

- [ ] **Step 5: 验证项目启动**

```bash
cd /Users/fusong/ClaudeCode/mnote
npm run dev
```

Expected: 浏览器打开 `http://localhost:5173/mnote/`，页面空白无报错

- [ ] **Step 6: 初始化 git 并提交**

```bash
cd /Users/fusong/ClaudeCode/mnote
git init
echo "node_modules\ndist\n.DS_Store" > .gitignore
git add .
git commit -m "feat: init Vue 3 + Vite project for mnote"
```

---

## Task 2: useStorage composable

**Files:**
- Create: `mnote/src/composables/useStorage.js`

- [ ] **Step 1: 创建 useStorage.js**

```js
// src/composables/useStorage.js
const TOKEN_KEY = 'mnote_token'
const REPOS_KEY = 'mnote_repos'

export function useStorage() {
  function getToken() {
    return localStorage.getItem(TOKEN_KEY) || null
  }

  function setToken(token) {
    localStorage.setItem(TOKEN_KEY, token)
  }

  function clearToken() {
    localStorage.removeItem(TOKEN_KEY)
  }

  function getRepos() {
    try {
      return JSON.parse(localStorage.getItem(REPOS_KEY)) || []
    } catch {
      return []
    }
  }

  function saveRepos(repos) {
    localStorage.setItem(REPOS_KEY, JSON.stringify(repos))
  }

  function addRepo(repo) {
    const repos = getRepos()
    if (!repos.find(r => r.full_name === repo.full_name)) {
      repos.push(repo)
      saveRepos(repos)
    }
  }

  function removeRepo(fullName) {
    const repos = getRepos().filter(r => r.full_name !== fullName)
    saveRepos(repos)
  }

  return { getToken, setToken, clearToken, getRepos, addRepo, removeRepo }
}
```

- [ ] **Step 2: 手动验证（浏览器控制台）**

在 `npm run dev` 运行时，打开浏览器控制台执行：

```js
// 临时测试，不需要写测试文件
import('/mnote/src/composables/useStorage.js').then(m => {
  const s = m.useStorage()
  s.setToken('test123')
  console.assert(s.getToken() === 'test123', 'token ok')
  s.addRepo({ full_name: 'user/repo', description: 'test' })
  console.assert(s.getRepos().length === 1, 'repo added')
  s.removeRepo('user/repo')
  console.assert(s.getRepos().length === 0, 'repo removed')
  console.log('useStorage: all checks passed')
})
```

- [ ] **Step 3: 提交**

```bash
cd /Users/fusong/ClaudeCode/mnote
git add src/composables/useStorage.js
git commit -m "feat: add useStorage composable for token and repo persistence"
```

---

## Task 3: useGitHub composable

**Files:**
- Create: `mnote/src/composables/useGitHub.js`

- [ ] **Step 1: 创建 useGitHub.js**

```js
// src/composables/useGitHub.js
const BASE = 'https://api.github.com'

export function useGitHub(token) {
  const headers = {
    Authorization: `Bearer ${token}`,
    Accept: 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
  }

  async function validateToken() {
    const res = await fetch(`${BASE}/user`, { headers })
    if (!res.ok) throw new Error('Invalid token')
    return await res.json()
  }

  async function searchRepos(query) {
    const res = await fetch(
      `${BASE}/search/repositories?q=${encodeURIComponent(query)}+user:@me&per_page=10`,
      { headers }
    )
    if (!res.ok) throw new Error('Search failed')
    const data = await res.json()
    return data.items.map(r => ({ full_name: r.full_name, description: r.description, private: r.private }))
  }

  async function getContents(owner, repo, path = '') {
    const res = await fetch(
      `${BASE}/repos/${owner}/${repo}/contents/${path}`,
      { headers }
    )
    if (res.status === 403) {
      const data = await res.json()
      if (data.message?.includes('rate limit')) {
        const reset = res.headers.get('X-RateLimit-Reset')
        throw new Error(`RATE_LIMIT:${reset}`)
      }
    }
    if (!res.ok) throw new Error(`Failed to get contents: ${res.status}`)
    return await res.json()
  }

  async function getFileContent(owner, repo, path) {
    const data = await getContents(owner, repo, path)
    if (data.encoding !== 'base64') throw new Error('Unexpected encoding')
    return atob(data.content.replace(/\n/g, ''))
  }

  return { validateToken, searchRepos, getContents, getFileContent }
}
```

- [ ] **Step 2: 提交**

```bash
cd /Users/fusong/ClaudeCode/mnote
git add src/composables/useGitHub.js
git commit -m "feat: add useGitHub composable for GitHub API calls"
```

---

## Task 4: Router 配置

**Files:**
- Create: `mnote/src/router/index.js`

- [ ] **Step 1: 创建 router/index.js**

```js
// src/router/index.js
import { createRouter, createWebHashHistory } from 'vue-router'
import { useStorage } from '../composables/useStorage.js'

const routes = [
  {
    path: '/setup',
    component: () => import('../views/Setup.vue'),
  },
  {
    path: '/',
    component: () => import('../views/RepoList.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/repo/:owner/:repo',
    component: () => import('../views/FileTree.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/repo/:owner/:repo/file/:path(.*)',
    component: () => import('../views/MarkdownView.vue'),
    meta: { requiresAuth: true },
  },
]

const router = createRouter({
  history: createWebHashHistory(),
  routes,
})

router.beforeEach((to) => {
  const { getToken } = useStorage()
  if (to.meta.requiresAuth && !getToken()) {
    return '/setup'
  }
})

export default router
```

注意：使用 `createWebHashHistory()` 避免 GitHub Pages 刷新 404 问题。

- [ ] **Step 2: 提交**

```bash
cd /Users/fusong/ClaudeCode/mnote
git add src/router/index.js
git commit -m "feat: add Vue Router with auth guard"
```

---

## Task 5: Setup 页面

**Files:**
- Create: `mnote/src/views/Setup.vue`

- [ ] **Step 1: 创建 Setup.vue**

```vue
<template>
  <div class="setup-page">
    <div class="setup-card">
      <h1>mnote</h1>
      <p class="subtitle">输入 GitHub Personal Access Token 开始使用</p>

      <div class="form-group">
        <label for="token">Personal Access Token</label>
        <input
          id="token"
          v-model="tokenInput"
          type="password"
          placeholder="ghp_xxxxxxxxxxxx"
          :disabled="loading"
        />
        <p class="hint">
          需要 <code>repo</code> 权限。
          <a href="https://github.com/settings/tokens/new" target="_blank">生成 Token</a>
        </p>
      </div>

      <p v-if="error" class="error">{{ error }}</p>

      <button @click="handleSubmit" :disabled="loading || !tokenInput.trim()">
        {{ loading ? '验证中...' : '开始使用' }}
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useStorage } from '../composables/useStorage.js'
import { useGitHub } from '../composables/useGitHub.js'

const router = useRouter()
const { setToken } = useStorage()

const tokenInput = ref('')
const loading = ref(false)
const error = ref('')

async function handleSubmit() {
  loading.value = true
  error.value = ''
  try {
    const { validateToken } = useGitHub(tokenInput.value.trim())
    await validateToken()
    setToken(tokenInput.value.trim())
    router.push('/')
  } catch {
    error.value = 'Token 无效，请检查后重试'
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.setup-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
}

.setup-card {
  background: white;
  border-radius: 12px;
  padding: 32px 24px;
  width: 100%;
  max-width: 400px;
  box-shadow: 0 2px 12px rgba(0,0,0,0.08);
}

h1 {
  font-size: 28px;
  font-weight: 700;
  margin-bottom: 8px;
}

.subtitle {
  color: #666;
  margin-bottom: 24px;
  font-size: 14px;
}

.form-group {
  margin-bottom: 16px;
}

label {
  display: block;
  font-size: 14px;
  font-weight: 500;
  margin-bottom: 6px;
}

input {
  width: 100%;
  padding: 10px 12px;
  border: 1px solid #d0d7de;
  border-radius: 8px;
  font-size: 15px;
  outline: none;
}

input:focus {
  border-color: #0969da;
  box-shadow: 0 0 0 3px rgba(9,105,218,0.1);
}

.hint {
  font-size: 12px;
  color: #666;
  margin-top: 6px;
}

.error {
  color: #d1242f;
  font-size: 14px;
  margin-bottom: 12px;
}

button {
  width: 100%;
  padding: 12px;
  background: #0969da;
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 16px;
  font-weight: 500;
}

button:disabled {
  opacity: 0.5;
}
</style>
```

- [ ] **Step 2: 验证页面**

```bash
npm run dev
```

打开 `http://localhost:5173/mnote/#/setup`，确认：
- 输入框和按钮正常显示
- 输入无效 Token 后显示错误信息
- 输入有效 Token 后跳转到 `/`（此时 RepoList 还未创建，会显示空白，正常）

- [ ] **Step 3: 提交**

```bash
cd /Users/fusong/ClaudeCode/mnote
git add src/views/Setup.vue
git commit -m "feat: add Setup page with token validation"
```

---

## Task 6: RepoList 页面

**Files:**
- Create: `mnote/src/views/RepoList.vue`

- [ ] **Step 1: 创建 RepoList.vue**

```vue
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
```

- [ ] **Step 2: 验证页面**

```bash
npm run dev
```

打开 `http://localhost:5173/mnote/#/`（需要先在 setup 页输入有效 Token），确认：
- 空状态显示"还没有添加仓库"
- 点击"＋"弹出搜索框
- 搜索仓库并添加后，卡片出现在列表中
- 点击"✕"可删除仓库
- 点击"⚙"可重置 Token

- [ ] **Step 3: 提交**

```bash
cd /Users/fusong/ClaudeCode/mnote
git add src/views/RepoList.vue
git commit -m "feat: add RepoList page with search and manage repos"
```

---

## Task 7: FileTree 页面

**Files:**
- Create: `mnote/src/views/FileTree.vue`

- [ ] **Step 1: 创建 FileTree.vue**

```vue
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
import { ref, computed, watch, onMounted } from 'vue'
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
```

- [ ] **Step 2: 验证页面**

打开一个有 `.md` 文件的仓库，确认：
- 文件和目录正常列出，目录排在前面
- 点击目录展开子目录，breadcrumb 更新
- 非 `.md` 文件置灰不可点击
- 点击 `.md` 文件跳转到阅读器（此时阅读器还未创建，路由空白正常）

- [ ] **Step 3: 提交**

```bash
cd /Users/fusong/ClaudeCode/mnote
git add src/views/FileTree.vue
git commit -m "feat: add FileTree page with breadcrumb navigation"
```

---

## Task 8: MarkdownView 页面

**Files:**
- Create: `mnote/src/views/MarkdownView.vue`

- [ ] **Step 1: 创建 MarkdownView.vue**

```vue
<template>
  <div class="page">
    <header class="page-header">
      <button class="back-btn" @click="router.back()">←</button>
      <span class="file-title">{{ fileName }}</span>
    </header>

    <div v-if="loading" class="loading">加载中...</div>
    <div v-else-if="error" class="error-msg">{{ error }}</div>
    <article v-else class="markdown-body" v-html="rendered" />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { marked } from 'marked'
import { useStorage } from '../composables/useStorage.js'
import { useGitHub } from '../composables/useGitHub.js'

const router = useRouter()
const route = useRoute()
const { getToken } = useStorage()

const content = ref('')
const loading = ref(false)
const error = ref('')

const fileName = computed(() => {
  const parts = route.params.path.split('/')
  return parts[parts.length - 1]
})

const rendered = computed(() => marked.parse(content.value))

const CACHE_PREFIX = 'mnote_cache_'

function getCacheKey() {
  return `${CACHE_PREFIX}${route.params.owner}_${route.params.repo}_${route.params.path}`
}

onMounted(async () => {
  // 先尝试读取缓存
  const cached = localStorage.getItem(getCacheKey())
  if (cached) {
    content.value = cached
  }

  loading.value = !cached
  error.value = ''
  try {
    const { getFileContent } = useGitHub(getToken())
    const text = await getFileContent(route.params.owner, route.params.repo, route.params.path)
    content.value = text
    localStorage.setItem(getCacheKey(), text)
  } catch (e) {
    if (!cached) {
      if (e.message.startsWith('RATE_LIMIT:')) {
        const reset = new Date(parseInt(e.message.split(':')[1]) * 1000)
        error.value = `API 限流，请在 ${reset.toLocaleTimeString()} 后重试`
      } else {
        error.value = '加载失败：' + e.message
      }
    }
    // 有缓存时静默失败，继续显示缓存内容
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.page {
  min-height: 100vh;
  background: white;
}

.page-header {
  display: flex;
  align-items: center;
  gap: 10px;
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
  flex-shrink: 0;
}

.file-title {
  font-size: 15px;
  font-weight: 600;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.loading, .error-msg {
  text-align: center;
  padding: 48px 24px;
  color: #666;
}

.error-msg {
  color: #d1242f;
}

.markdown-body {
  padding: 20px 16px 48px;
  font-size: 16px;
  line-height: 1.7;
  color: #1a1a1a;
  max-width: 720px;
  margin: 0 auto;
}
</style>

<style>
/* 非 scoped：markdown 渲染内容的全局样式 */
.markdown-body h1 { font-size: 24px; margin: 24px 0 12px; font-weight: 700; }
.markdown-body h2 { font-size: 20px; margin: 20px 0 10px; font-weight: 700; border-bottom: 1px solid #e0e0e0; padding-bottom: 6px; }
.markdown-body h3 { font-size: 17px; margin: 16px 0 8px; font-weight: 600; }
.markdown-body p { margin: 12px 0; }
.markdown-body ul, .markdown-body ol { padding-left: 24px; margin: 12px 0; }
.markdown-body li { margin: 4px 0; }
.markdown-body code { background: #f0f0f0; padding: 2px 5px; border-radius: 4px; font-size: 14px; font-family: 'SF Mono', Menlo, monospace; }
.markdown-body pre { background: #f6f8fa; border-radius: 8px; padding: 16px; overflow-x: auto; margin: 16px 0; }
.markdown-body pre code { background: none; padding: 0; font-size: 13px; }
.markdown-body blockquote { border-left: 4px solid #d0d7de; padding-left: 16px; color: #666; margin: 16px 0; }
.markdown-body strong { font-weight: 700; }
.markdown-body a { color: #0969da; }
.markdown-body hr { border: none; border-top: 1px solid #e0e0e0; margin: 24px 0; }
</style>
```

- [ ] **Step 2: 验证页面**

点击一个 `.md` 文件，确认：
- Markdown 正常渲染（标题、加粗、列表、代码块）
- 返回按钮正常
- 再次打开同一文件时从缓存加载（断网也能看）

- [ ] **Step 3: 提交**

```bash
cd /Users/fusong/ClaudeCode/mnote
git add src/views/MarkdownView.vue
git commit -m "feat: add MarkdownView with marked.js rendering and cache"
```

---

## Task 9: PWA 配置

**Files:**
- Create: `mnote/public/manifest.json`
- Create: `mnote/public/sw.js`
- Modify: `mnote/index.html`

- [ ] **Step 1: 创建 manifest.json**

```json
{
  "name": "mnote",
  "short_name": "mnote",
  "description": "GitHub Markdown Reader",
  "start_url": "/mnote/#/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#0969da",
  "icons": [
    {
      "src": "data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>📝</text></svg>",
      "sizes": "any",
      "type": "image/svg+xml"
    }
  ]
}
```

- [ ] **Step 2: 创建 sw.js（缓存策略：网络优先，降级到缓存）**

```js
const CACHE_NAME = 'mnote-v1'

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE_NAME).then(cache =>
      cache.addAll(['./index.html'])
    )
  )
  self.skipWaiting()
})

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
    )
  )
  self.clients.claim()
})

self.addEventListener('fetch', (e) => {
  // 只缓存同源请求，不缓存 GitHub API
  if (!e.request.url.startsWith(self.location.origin)) return

  e.respondWith(
    fetch(e.request)
      .then(res => {
        const clone = res.clone()
        caches.open(CACHE_NAME).then(cache => cache.put(e.request, clone))
        return res
      })
      .catch(() => caches.match(e.request))
  )
})
```

- [ ] **Step 3: 在 index.html 注册 Service Worker 和 manifest**

在 `index.html` 的 `<head>` 中添加：

```html
<link rel="manifest" href="/mnote/manifest.json" />
<meta name="theme-color" content="#0969da" />
<meta name="apple-mobile-web-app-capable" content="yes" />
<meta name="apple-mobile-web-app-status-bar-style" content="default" />
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0" />
```

在 `index.html` 的 `</body>` 前添加：

```html
<script>
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('/mnote/sw.js')
    })
  }
</script>
```

- [ ] **Step 4: 提交**

```bash
cd /Users/fusong/ClaudeCode/mnote
git add public/manifest.json public/sw.js index.html
git commit -m "feat: add PWA manifest and service worker"
```

---

## Task 10: 部署到 GitHub Pages

**Files:**
- Create: `mnote/.github/workflows/deploy.yml`

- [ ] **Step 1: 创建 GitHub Actions 部署工作流**

```bash
mkdir -p /Users/fusong/ClaudeCode/mnote/.github/workflows
```

创建 `.github/workflows/deploy.yml`：

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches: [main]

permissions:
  contents: read
  pages: write
  id-token: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npm run build
      - uses: actions/configure-pages@v4
      - uses: actions/upload-pages-artifact@v3
        with:
          path: dist
      - id: deployment
        uses: actions/deploy-pages@v4
```

- [ ] **Step 2: 推送到 GitHub 并启用 Pages**

```bash
cd /Users/fusong/ClaudeCode/mnote
git add .github/workflows/deploy.yml
git commit -m "ci: add GitHub Actions deploy workflow"
```

然后：
1. 在 GitHub 创建名为 `mnote` 的仓库
2. `git remote add origin https://github.com/<你的用户名>/mnote.git`
3. `git push -u origin main`
4. 进入仓库 Settings → Pages → Source 选择 **GitHub Actions**
5. 等待 Actions 完成，访问 `https://<你的用户名>.github.io/mnote/`

- [ ] **Step 3: 手机测试**

用手机浏览器打开部署后的 URL，确认：
- 页面正常加载
- 可以添加到主屏幕（iOS Safari：分享→添加到主屏幕；Android Chrome：菜单→添加到主屏幕）
- Token 输入、仓库浏览、MD 阅读全流程正常

---

## 完成标准

- [ ] 手机浏览器可正常访问并完成全流程：输入 Token → 添加仓库 → 浏览文件树 → 阅读 MD 文件
- [ ] 已添加到主屏幕，以 standalone 模式运行
- [ ] 已读过的 MD 文件断网可查看
- [ ] 私有仓库内容不对外暴露（无 Token 无法访问）
