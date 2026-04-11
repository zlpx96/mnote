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

// 配置 marked：禁止渲染原始 HTML 标签（防 XSS）
const renderer = new marked.Renderer()
renderer.html = () => ''

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

const rendered = computed(() => marked.parse(content.value, { renderer }))

const CACHE_PREFIX = 'mnote_cache_'

function getCacheKey() {
  return `${CACHE_PREFIX}${route.params.owner}/${route.params.repo}/${route.params.path}`
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
    if (e.message === 'UNAUTHORIZED') {
      router.push('/setup')
    } else if (!cached) {
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
