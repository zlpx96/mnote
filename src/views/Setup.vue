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
import { ref } from 'vue'
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

const githubConfigured = ref(!!storage.getToken('github'))
const giteeConfigured = ref(!!storage.getToken('gitee'))

async function handleSave(platform) {
  const tok = platform === 'github' ? githubToken.value.trim() : giteeToken.value.trim()
  loading.value = true
  error.value = ''
  try {
    const { validateToken } = useGitProvider(platform, tok)
    await validateToken()
    storage.setToken(tok, platform)
    if (platform === 'github') githubConfigured.value = true
    else giteeConfigured.value = true
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
