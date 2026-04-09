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
