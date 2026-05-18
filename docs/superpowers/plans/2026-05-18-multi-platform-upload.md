# Multi-Platform + Image Upload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Gitee support alongside GitHub (both platforms configured independently, switchable via UI button) and add image upload to the FileTree page.

**Architecture:** Replace `useGitHub` with a unified `useGitProvider(platform, token)` adapter that routes to GitHub or Gitee APIs. `useStorage` is extended to store per-platform tokens, repos, and cache keys. Views are updated to read the active platform from storage and pass it to the provider.

**Tech Stack:** Vue 3 Composition API, Vite, localStorage, GitHub REST API v3, Gitee REST API v5, browser FileReader API

---

## File Map

| File | Action | What changes |
|---|---|---|
| `src/composables/useStorage.js` | Modify | Add platform support, migrate old keys, per-platform token/repos/cache |
| `src/composables/useGitProvider.js` | Create | Unified API adapter replacing useGitHub |
| `src/composables/useGitHub.js` | Delete (Task 5) | Replaced by useGitProvider |
| `src/views/Setup.vue` | Modify | Two-tab token config (GitHub + Gitee) |
| `src/views/RepoList.vue` | Modify | Platform switcher, use useGitProvider |
| `src/views/FileTree.vue` | Modify | Use useGitProvider, add upload button |
| `src/views/MarkdownView.vue` | Modify | Use useGitProvider, fix cache key prefix |
| `src/views/TaskList.vue` | Modify | Use useGitProvider |

---

## Task 1: Extend `useStorage` for multi-platform

**Files:**
- Modify: `src/composables/useStorage.js`

- [ ] **Step 1: Replace the file entirely with the new multi-platform version**

```js
// src/composables/useStorage.js
const PLATFORM_KEY = 'mnote_platform'
const FAVORITES_KEY = 'mnote_favorites'

function tokenKey(platform) { return `mnote_token_${platform}` }
function reposKey(platform) { return `mnote_repos_${platform}` }
function cacheKey(platform, path) { return `mnote_cache_${platform}_${path}` }
function scrollKey(platform, path) { return `mnote_scroll_${platform}_${path}` }

export function useStorage() {
  // Migrate legacy keys on first call
  function migrate() {
    const oldToken = localStorage.getItem('mnote_token')
    if (oldToken) {
      localStorage.setItem(tokenKey('github'), oldToken)
      localStorage.removeItem('mnote_token')
    }
    const oldRepos = localStorage.getItem('mnote_repos')
    if (oldRepos) {
      localStorage.setItem(reposKey('github'), oldRepos)
      localStorage.removeItem('mnote_repos')
    }
    // Migrate old cache keys (no platform prefix) to github prefix
    Object.keys(localStorage)
      .filter(k => k.startsWith('mnote_cache_') && !k.startsWith('mnote_cache_github_') && !k.startsWith('mnote_cache_gitee_'))
      .forEach(k => {
        const val = localStorage.getItem(k)
        const newKey = k.replace('mnote_cache_', 'mnote_cache_github_')
        localStorage.setItem(newKey, val)
        localStorage.removeItem(k)
      })
    Object.keys(localStorage)
      .filter(k => k.startsWith('mnote_scroll_') && !k.startsWith('mnote_scroll_github_') && !k.startsWith('mnote_scroll_gitee_'))
      .forEach(k => {
        const val = localStorage.getItem(k)
        const newKey = k.replace('mnote_scroll_', 'mnote_scroll_github_')
        localStorage.setItem(newKey, val)
        localStorage.removeItem(k)
      })
  }
  migrate()

  function getPlatform() {
    return localStorage.getItem(PLATFORM_KEY) || 'github'
  }

  function setPlatform(platform) {
    localStorage.setItem(PLATFORM_KEY, platform)
  }

  function getToken(platform) {
    return localStorage.getItem(tokenKey(platform || getPlatform())) || null
  }

  function setToken(token, platform) {
    localStorage.setItem(tokenKey(platform || getPlatform()), token)
  }

  function clearToken(platform) {
    const p = platform || getPlatform()
    localStorage.removeItem(tokenKey(p))
    Object.keys(localStorage)
      .filter(k => k.startsWith(`mnote_cache_${p}_`) || k.startsWith(`mnote_scroll_${p}_`))
      .forEach(k => localStorage.removeItem(k))
  }

  function getRepos(platform) {
    try {
      return JSON.parse(localStorage.getItem(reposKey(platform || getPlatform()))) || []
    } catch {
      return []
    }
  }

  function saveRepos(repos, platform) {
    localStorage.setItem(reposKey(platform || getPlatform()), JSON.stringify(repos))
  }

  function addRepo(repo, platform) {
    const p = platform || getPlatform()
    const repos = getRepos(p)
    if (!repos.find(r => r.full_name === repo.full_name)) {
      repos.push(repo)
      saveRepos(repos, p)
    }
  }

  function removeRepo(fullName, platform) {
    const p = platform || getPlatform()
    const repos = getRepos(p).filter(r => r.full_name !== fullName)
    saveRepos(repos, p)
  }

  function getCacheKey(path) {
    return cacheKey(getPlatform(), path)
  }

  function getScrollKey(path) {
    return scrollKey(getPlatform(), path)
  }

  function getFavorites() {
    try {
      return JSON.parse(localStorage.getItem(FAVORITES_KEY)) || []
    } catch {
      return []
    }
  }

  function isFavorite(owner, repo, path) {
    return getFavorites().some(f => f.owner === owner && f.repo === repo && f.path === path)
  }

  function toggleFavorite(item) {
    const favs = getFavorites()
    const idx = favs.findIndex(f => f.owner === item.owner && f.repo === item.repo && f.path === item.path)
    if (idx >= 0) {
      favs.splice(idx, 1)
    } else {
      favs.unshift(item)
    }
    localStorage.setItem(FAVORITES_KEY, JSON.stringify(favs))
  }

  return {
    getPlatform, setPlatform,
    getToken, setToken, clearToken,
    getRepos, addRepo, removeRepo,
    getCacheKey, getScrollKey,
    getFavorites, isFavorite, toggleFavorite,
  }
}
```

- [ ] **Step 2: Verify the file saved correctly**

```bash
grep -n "getPlatform\|setPlatform\|getCacheKey\|migrate" /Users/fusong/ClaudeCode/mnote/src/composables/useStorage.js
```
Expected: lines showing all four functions defined.

- [ ] **Step 3: Commit**

```bash
git add src/composables/useStorage.js
git commit -m "feat: extend useStorage for multi-platform (github/gitee)"
```

---

## Task 2: Create `useGitProvider`

**Files:**
- Create: `src/composables/useGitProvider.js`

- [ ] **Step 1: Create the file**

```js
// src/composables/useGitProvider.js

function _base(platform) {
  return platform === 'gitee'
    ? 'https://gitee.com/api/v5'
    : 'https://api.github.com'
}

function _headers(platform, token) {
  const auth = platform === 'gitee'
    ? `token ${token}`
    : `Bearer ${token}`
  if (platform === 'gitee') {
    return { Authorization: auth, 'Content-Type': 'application/json' }
  }
  return {
    Authorization: auth,
    Accept: 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'Content-Type': 'application/json',
  }
}

export function useGitProvider(platform, token) {
  const BASE = _base(platform)
  const headers = _headers(platform, token)

  async function request(url) {
    const res = await fetch(url, { headers })
    if (res.status === 401) throw new Error('UNAUTHORIZED')
    if (res.status === 403 || res.status === 429) {
      const data = await res.clone().json().catch(() => ({}))
      const msg = data.message || ''
      if (platform === 'github' && msg.includes('rate limit')) {
        const reset = res.headers.get('X-RateLimit-Reset')
        throw new Error(`RATE_LIMIT:${reset}`)
      }
      throw new Error('RATE_LIMIT:0')
    }
    return res
  }

  async function validateToken() {
    const url = platform === 'gitee'
      ? `${BASE}/user?access_token=${token}`
      : `${BASE}/user`
    const res = await fetch(url, { headers })
    if (!res.ok) throw new Error('Invalid token')
    return await res.json()
  }

  async function searchRepos(query) {
    let url
    if (platform === 'gitee') {
      url = `${BASE}/repos/search?q=${encodeURIComponent(query)}&limit=10`
    } else {
      url = `${BASE}/search/repositories?q=${encodeURIComponent(query)}&per_page=10`
    }
    const res = await request(url)
    if (!res.ok) throw new Error('Search failed')
    const data = await res.json()
    // GitHub returns { items: [...] }, Gitee returns an array directly
    const items = Array.isArray(data) ? data : (data.items || [])
    return items.map(r => ({
      full_name: r.full_name,
      description: r.description,
      private: r.private,
    }))
  }

  async function getContents(owner, repo, path = '') {
    const url = platform === 'gitee'
      ? `${BASE}/repos/${owner}/${repo}/contents/${path}?access_token=${token}`
      : `${BASE}/repos/${owner}/${repo}/contents/${path}`
    const res = await request(url)
    if (!res.ok) throw new Error(`Failed to get contents: ${res.status}`)
    return await res.json()
  }

  async function getFileContent(owner, repo, path) {
    const data = await getContents(owner, repo, path)
    if (data.encoding !== 'base64') throw new Error('Unexpected encoding')
    const binary = atob(data.content.replace(/\n/g, ''))
    const bytes = Uint8Array.from(binary, c => c.charCodeAt(0))
    return new TextDecoder('utf-8').decode(bytes)
  }

  async function getFileSha(owner, repo, path) {
    const url = platform === 'gitee'
      ? `${BASE}/repos/${owner}/${repo}/contents/${path}?access_token=${token}`
      : `${BASE}/repos/${owner}/${repo}/contents/${path}`
    const res = await request(url)
    if (res.status === 404) return null
    if (!res.ok) throw new Error(`Failed to get file sha: ${res.status}`)
    const data = await res.json()
    return data.sha
  }

  async function _writeFile(owner, repo, path, base64Content, sha, message) {
    const body = { message, content: base64Content }
    if (sha) body.sha = sha
    // Gitee requires access_token in body for PUT
    if (platform === 'gitee') body.access_token = token
    const url = `${BASE}/repos/${owner}/${repo}/contents/${path}`
    const res = await fetch(url, {
      method: 'PUT',
      headers,
      body: JSON.stringify(body),
    })
    if (res.status === 401) throw new Error('UNAUTHORIZED')
    if (!res.ok) throw new Error(`Failed to write file: ${res.status}`)
    return await res.json()
  }

  async function putFile(owner, repo, path, content, sha = null) {
    const base64 = btoa(unescape(encodeURIComponent(content)))
    const message = sha ? `update: ${path}` : `create: ${path}`
    return _writeFile(owner, repo, path, base64, sha, message)
  }

  async function uploadFile(owner, repo, path, base64, sha = null) {
    const message = sha ? `update: ${path}` : `upload: ${path}`
    return _writeFile(owner, repo, path, base64, sha, message)
  }

  return { validateToken, searchRepos, getContents, getFileContent, putFile, getFileSha, uploadFile }
}
```

- [ ] **Step 2: Verify the file**

```bash
grep -n "export function\|uploadFile\|_writeFile\|_base\|_headers" /Users/fusong/ClaudeCode/mnote/src/composables/useGitProvider.js
```
Expected: lines for all five names.

- [ ] **Step 3: Commit**

```bash
git add src/composables/useGitProvider.js
git commit -m "feat: add useGitProvider adapter for github and gitee"
```

---

## Task 3: Update `Setup.vue` for two-platform token config

**Files:**
- Modify: `src/views/Setup.vue`

- [ ] **Step 1: Replace Setup.vue entirely**

```vue
<template>
  <div class="setup-page">
    <div class="setup-card">
      <h1>mnote</h1>

      <div class="platform-tabs">
        <button
          :class="['tab', activeTab === 'github' && 'active']"
          @click="activeTab = 'github'"
        >
          GitHub <span v-if="githubConfigured" class="check">✓</span>
        </button>
        <button
          :class="['tab', activeTab === 'gitee' && 'active']"
          @click="activeTab = 'gitee'"
        >
          Gitee <span v-if="giteeConfigured" class="check">✓</span>
        </button>
      </div>

      <div v-if="activeTab === 'github'">
        <p class="subtitle">输入 GitHub Personal Access Token</p>
        <div class="form-group">
          <input
            v-model="githubToken"
            type="password"
            placeholder="ghp_xxxxxxxxxxxx"
            :disabled="loading"
          />
          <p class="hint">
            需要 <code>repo</code> 权限。
            <a href="https://github.com/settings/tokens/new" target="_blank">生成 Token</a>
          </p>
        </div>
        <p v-if="error && activeTab === 'github'" class="error">{{ error }}</p>
        <button @click="handleSave('github')" :disabled="loading || !githubToken.trim()">
          {{ loading ? '验证中...' : '保存 GitHub Token' }}
        </button>
      </div>

      <div v-if="activeTab === 'gitee'">
        <p class="subtitle">输入 Gitee 私人令牌</p>
        <div class="form-group">
          <input
            v-model="giteeToken"
            type="password"
            placeholder="xxxxxxxxxxxxxxxxxxxx"
            :disabled="loading"
          />
          <p class="hint">
            需要 projects、pull_requests 权限。
            <a href="https://gitee.com/profile/personal_access_tokens/new" target="_blank">生成令牌</a>
          </p>
        </div>
        <p v-if="error && activeTab === 'gitee'" class="error">{{ error }}</p>
        <button @click="handleSave('gitee')" :disabled="loading || !giteeToken.trim()">
          {{ loading ? '验证中...' : '保存 Gitee Token' }}
        </button>
      </div>

      <button
        class="start-btn"
        :disabled="!githubConfigured && !giteeConfigured"
        @click="handleStart"
      >
        开始使用
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useStorage } from '../composables/useStorage.js'
import { useGitProvider } from '../composables/useGitProvider.js'

const router = useRouter()
const storage = useStorage()

const activeTab = ref('github')
const githubToken = ref(storage.getToken('github') || '')
const giteeToken = ref(storage.getToken('gitee') || '')
const loading = ref(false)
const error = ref('')

const githubConfigured = computed(() => !!storage.getToken('github'))
const giteeConfigured = computed(() => !!storage.getToken('gitee'))

async function handleSave(platform) {
  const tok = platform === 'github' ? githubToken.value.trim() : giteeToken.value.trim()
  loading.value = true
  error.value = ''
  try {
    const { validateToken } = useGitProvider(platform, tok)
    await validateToken()
    storage.setToken(tok, platform)
    // Trigger computed reactivity by re-reading token
    if (platform === 'github') githubToken.value = tok
    else giteeToken.value = tok
  } catch {
    error.value = 'Token 无效，请检查后重试'
  } finally {
    loading.value = false
  }
}

function handleStart() {
  const platform = githubConfigured.value ? 'github' : 'gitee'
  storage.setPlatform(platform)
  router.push('/')
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
  display: flex;
  flex-direction: column;
  gap: 16px;
}

h1 {
  font-size: 28px;
  font-weight: 700;
}

.platform-tabs {
  display: flex;
  gap: 0;
  border: 1px solid #d0d7de;
  border-radius: 8px;
  overflow: hidden;
}

.tab {
  flex: 1;
  padding: 9px;
  border: none;
  background: #f6f8fa;
  font-size: 14px;
  font-weight: 500;
  color: #666;
  cursor: pointer;
}

.tab.active {
  background: white;
  color: #0969da;
  font-weight: 600;
}

.check {
  color: #1a7f37;
  margin-left: 4px;
}

.subtitle {
  color: #666;
  font-size: 14px;
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 6px;
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
}

.error {
  color: #d1242f;
  font-size: 14px;
}

button {
  width: 100%;
  padding: 12px;
  background: #0969da;
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 15px;
  font-weight: 500;
}

button:disabled {
  opacity: 0.5;
}

.start-btn {
  background: #1a7f37;
  margin-top: 8px;
}

.start-btn:disabled {
  opacity: 0.5;
}
</style>
```

- [ ] **Step 2: Verify build**

```bash
cd /Users/fusong/ClaudeCode/mnote && npm run build 2>&1 | tail -20
```
Expected: `✓ built in` with no errors.

- [ ] **Step 3: Commit**

```bash
git add src/views/Setup.vue
git commit -m "feat: update Setup for two-platform token config (github + gitee)"
```

---

## Task 4: Update `RepoList.vue` — platform switcher + useGitProvider

**Files:**
- Modify: `src/views/RepoList.vue`

- [ ] **Step 1: Replace the `<script setup>` block**

Replace the entire `<script setup>` section (lines 75–136) with:

```vue
<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useStorage } from '../composables/useStorage.js'
import { useGitProvider } from '../composables/useGitProvider.js'

const router = useRouter()
const storage = useStorage()

const platform = ref(storage.getPlatform())
const repos = ref([])
const showSearch = ref(false)
const showFavorites = ref(false)
const favorites = ref([])
const searchQuery = ref('')
const searchResults = ref([])
const searching = ref(false)
const searchError = ref('')

function loadData() {
  platform.value = storage.getPlatform()
  repos.value = storage.getRepos()
  favorites.value = storage.getFavorites()
}

onMounted(loadData)

function switchPlatform(p) {
  const token = storage.getToken(p)
  if (!token) {
    router.push('/setup')
    return
  }
  storage.setPlatform(p)
  loadData()
}

function handleRemove(fullName) {
  storage.removeRepo(fullName)
  repos.value = storage.getRepos()
}

function handleReset() {
  if (confirm('重置 Token 后需要重新登录，确认吗？')) {
    storage.clearToken()
    router.push('/setup')
  }
}

async function handleSearch() {
  searching.value = true
  searchError.value = ''
  searchResults.value = []
  try {
    const { searchRepos } = useGitProvider(platform.value, storage.getToken())
    searchResults.value = await searchRepos(searchQuery.value.trim())
  } catch (e) {
    if (e.message === 'UNAUTHORIZED') {
      storage.clearToken()
      router.push('/setup')
    } else {
      searchError.value = '搜索失败，请重试'
    }
  } finally {
    searching.value = false
  }
}

function handleAdd(repo) {
  storage.addRepo(repo)
  repos.value = storage.getRepos()
  showSearch.value = false
  searchQuery.value = ''
  searchResults.value = []
}
</script>
```

- [ ] **Step 2: Add platform switcher to the header template**

Find the `<header class="page-header">` block in the template and replace it with:

```html
    <header class="page-header">
      <h1>我的仓库</h1>
      <div class="header-actions">
        <div class="platform-switch">
          <button
            :class="['plat-btn', platform === 'github' && 'active']"
            @click="switchPlatform('github')"
          >GitHub</button>
          <button
            :class="['plat-btn', platform === 'gitee' && 'active']"
            @click="switchPlatform('gitee')"
          >Gitee</button>
        </div>
        <button class="icon-btn" @click="router.push('/tasks')" title="任务">✦</button>
        <button class="icon-btn" @click="showFavorites = !showFavorites" title="收藏">★</button>
        <button class="icon-btn" @click="showSearch = true">＋</button>
        <button class="icon-btn" @click="handleReset" title="重置 Token">⚙</button>
      </div>
    </header>
```

- [ ] **Step 3: Add platform switcher styles** at the end of the `<style scoped>` block (before closing `</style>`):

```css
.platform-switch {
  display: flex;
  border: 1px solid #d0d7de;
  border-radius: 6px;
  overflow: hidden;
}

.plat-btn {
  padding: 4px 10px;
  border: none;
  background: #f6f8fa;
  font-size: 12px;
  font-weight: 500;
  color: #666;
  cursor: pointer;
}

.plat-btn.active {
  background: #0969da;
  color: white;
}
```

- [ ] **Step 4: Verify build**

```bash
cd /Users/fusong/ClaudeCode/mnote && npm run build 2>&1 | tail -20
```
Expected: `✓ built in` with no errors.

- [ ] **Step 5: Commit**

```bash
git add src/views/RepoList.vue
git commit -m "feat: add platform switcher to RepoList, use useGitProvider"
```

---

## Task 5: Update `FileTree.vue` — useGitProvider + image upload

**Files:**
- Modify: `src/views/FileTree.vue`

- [ ] **Step 1: Replace the `<script setup>` import lines** (lines 62–66) with:

```js
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useStorage } from '../composables/useStorage.js'
import { useGitProvider } from '../composables/useGitProvider.js'
```

- [ ] **Step 2: Replace the `<script setup>` body** — after imports, replace the full body (from `const router = useRouter()` to end of `</script>`) with:

```js
const router = useRouter()

function handleBack() {
  if (window.history.state?.back?.startsWith('/')) {
    router.back()
  } else {
    router.push('/')
  }
}
const route = useRoute()
const storage = useStorage()

const items = ref([])
const showNew = ref(false)
const newFileName = ref('')
const newContent = ref('')
const newSaving = ref(false)
const newError = ref('')

// Image upload state
const uploadInput = ref(null)
const uploading = ref(false)
const uploadError = ref('')

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
    const { putFile } = useGitProvider(storage.getPlatform(), storage.getToken())
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

function triggerUpload() {
  uploadError.value = ''
  uploadInput.value.click()
}

async function handleUpload(event) {
  const file = event.target.files[0]
  if (!file) return
  // Reset input so same file can be re-selected
  event.target.value = ''

  // Gitee base64 limit ~1MB (raw file should be well under that)
  const platform = storage.getPlatform()
  if (platform === 'gitee' && file.size > 1024 * 1024) {
    uploadError.value = 'Gitee 限制文件不能超过 1MB'
    return
  }
  if (file.size > 50 * 1024 * 1024) {
    uploadError.value = '文件不能超过 50MB'
    return
  }

  uploading.value = true
  uploadError.value = ''
  try {
    const base64 = await fileToBase64(file)
    const filePath = currentPath.value ? `${currentPath.value}/${file.name}` : file.name
    const { getFileSha, uploadFile } = useGitProvider(platform, storage.getToken())
    const sha = await getFileSha(route.params.owner, route.params.repo, filePath)
    await uploadFile(route.params.owner, route.params.repo, filePath, base64, sha)
    await loadContents(currentPath.value)
  } catch (e) {
    if (e.message === 'UNAUTHORIZED') {
      router.push('/setup')
    } else {
      uploadError.value = '上传失败：' + e.message
    }
  } finally {
    uploading.value = false
  }
}

function fileToBase64(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => {
      // result is "data:image/png;base64,XXXX" — strip the prefix
      const base64 = reader.result.split(',')[1]
      resolve(base64)
    }
    reader.onerror = reject
    reader.readAsDataURL(file)
  })
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
    const { getContents } = useGitProvider(storage.getPlatform(), storage.getToken())
    const data = await getContents(route.params.owner, route.params.repo, path)
    items.value = Array.isArray(data) ? data : [data]
  } catch (e) {
    if (e.message === 'UNAUTHORIZED') {
      router.push('/setup')
    } else if (e.message.startsWith('RATE_LIMIT:')) {
      const ts = e.message.split(':')[1]
      if (ts === '0') {
        error.value = '请求过于频繁，请稍后再试'
      } else {
        const reset = new Date(parseInt(ts) * 1000)
        error.value = `API 限流，请在 ${reset.toLocaleTimeString()} 后重试`
      }
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
```

- [ ] **Step 3: Add upload button and hidden file input to the template**

Find the header line `<button class="new-btn" @click="showNew = true">＋</button>` and replace it with:

```html
      <input
        ref="uploadInput"
        type="file"
        accept="image/*"
        style="display:none"
        @change="handleUpload"
      />
      <button class="upload-btn" @click="triggerUpload" :disabled="uploading" title="上传图片">
        {{ uploading ? '…' : '↑' }}
      </button>
      <button class="new-btn" @click="showNew = true">＋</button>
```

- [ ] **Step 4: Add upload error display** — just after the `</header>` closing tag, add:

```html
    <p v-if="uploadError" class="upload-error">{{ uploadError }}</p>
```

- [ ] **Step 5: Add upload styles** at the end of `<style scoped>` block (before closing `</style>`):

```css
.upload-btn {
  background: none;
  border: none;
  font-size: 20px;
  color: #0969da;
  padding: 4px;
  margin-left: auto;
  flex-shrink: 0;
}

.upload-btn:disabled {
  opacity: 0.5;
}

.upload-error {
  color: #d1242f;
  font-size: 13px;
  padding: 8px 16px 0;
}
```

- [ ] **Step 6: Verify build**

```bash
cd /Users/fusong/ClaudeCode/mnote && npm run build 2>&1 | tail -20
```
Expected: `✓ built in` with no errors.

- [ ] **Step 7: Commit**

```bash
git add src/views/FileTree.vue
git commit -m "feat: add image upload to FileTree, use useGitProvider"
```

---

## Task 6: Update `MarkdownView.vue` — useGitProvider + fix cache keys

**Files:**
- Modify: `src/views/MarkdownView.vue`

- [ ] **Step 1: Replace useGitHub import with useGitProvider**

Find:
```js
import { useGitHub } from '../composables/useGitHub.js'
```
Replace with:
```js
import { useGitProvider } from '../composables/useGitProvider.js'
```

- [ ] **Step 2: Replace storage destructuring** — find:

```js
const { getToken, isFavorite, toggleFavorite } = useStorage()
```
Replace with:
```js
const storage = useStorage()
const { isFavorite, toggleFavorite } = storage
```

- [ ] **Step 3: Fix cache key constants** — find:

```js
const CACHE_PREFIX = 'mnote_cache_'
const SCROLL_PREFIX = 'mnote_scroll_'
```
Delete those two lines (they're replaced by `storage.getCacheKey()` / `storage.getScrollKey()`).

- [ ] **Step 4: Replace all cache key usages** — find all instances of:

```js
`${CACHE_PREFIX}${owner}/${repo}/${path}`
```
Replace with:
```js
storage.getCacheKey(`${owner}/${repo}/${path}`)
```

And find all instances of:
```js
`${SCROLL_PREFIX}${owner}/${repo}/${path}`
```
Replace with:
```js
storage.getScrollKey(`${owner}/${repo}/${path}`)
```

- [ ] **Step 5: Replace all `useGitHub(getToken())` calls** with `useGitProvider(storage.getPlatform(), storage.getToken())`.

There are three in the file (around lines 96, 109, 168). Replace each one.

- [ ] **Step 6: Verify build**

```bash
cd /Users/fusong/ClaudeCode/mnote && npm run build 2>&1 | tail -20
```
Expected: `✓ built in` with no errors.

- [ ] **Step 7: Commit**

```bash
git add src/views/MarkdownView.vue
git commit -m "fix: update MarkdownView to use useGitProvider and per-platform cache keys"
```

---

## Task 7: Update `TaskList.vue` — useGitProvider

**Files:**
- Modify: `src/views/TaskList.vue`

- [ ] **Step 1: Replace useGitHub import**

Find:
```js
import { useGitHub } from '../composables/useGitHub.js'
```
Replace with:
```js
import { useGitProvider } from '../composables/useGitProvider.js'
```

- [ ] **Step 2: Replace storage destructuring** — find:

```js
const { getToken } = useStorage()
```
Replace with:
```js
const storage = useStorage()
```

- [ ] **Step 3: Replace all `useGitHub(getToken())` calls** (there are two, around lines 144 and 202) with:

```js
useGitProvider(storage.getPlatform(), storage.getToken())
```

- [ ] **Step 4: Verify build**

```bash
cd /Users/fusong/ClaudeCode/mnote && npm run build 2>&1 | tail -20
```
Expected: `✓ built in` with no errors.

- [ ] **Step 5: Commit**

```bash
git add src/views/TaskList.vue
git commit -m "fix: update TaskList to use useGitProvider"
```

---

## Task 8: Delete `useGitHub.js` and verify router auth guard

**Files:**
- Delete: `src/composables/useGitHub.js`
- Modify: `src/router/index.js`

- [ ] **Step 1: Verify no remaining references to useGitHub**

```bash
grep -rn "useGitHub" /Users/fusong/ClaudeCode/mnote/src/
```
Expected: no output (zero matches).

- [ ] **Step 2: Delete the old file**

```bash
rm /Users/fusong/ClaudeCode/mnote/src/composables/useGitHub.js
```

- [ ] **Step 3: Update router auth guard** — open `src/router/index.js` and find:

```js
router.beforeEach((to) => {
  const { getToken } = useStorage()
  if (to.meta.requiresAuth && !getToken()) {
    return '/setup'
  }
})
```
Replace with:
```js
router.beforeEach((to) => {
  const storage = useStorage()
  if (to.meta.requiresAuth && !storage.getToken()) {
    return '/setup'
  }
})
```

- [ ] **Step 4: Final build check**

```bash
cd /Users/fusong/ClaudeCode/mnote && npm run build 2>&1 | tail -20
```
Expected: `✓ built in` with no errors.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: remove useGitHub.js, update router guard to use storage.getToken()"
```
