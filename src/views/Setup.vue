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
