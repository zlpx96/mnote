// src/composables/useStorage.js
const TOKEN_KEY = 'mnote_token'
const REPOS_KEY = 'mnote_repos'
const FAVORITES_KEY = 'mnote_favorites'

export function useStorage() {
  function getToken() {
    return localStorage.getItem(TOKEN_KEY) || null
  }

  function setToken(token) {
    localStorage.setItem(TOKEN_KEY, token)
  }

  function clearToken() {
    localStorage.removeItem(TOKEN_KEY)
    // 清除文件缓存和滚动记录，防止旧用户内容残留
    Object.keys(localStorage)
      .filter(k => k.startsWith('mnote_cache_') || k.startsWith('mnote_scroll_'))
      .forEach(k => localStorage.removeItem(k))
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

  return { getToken, setToken, clearToken, getRepos, addRepo, removeRepo, getFavorites, isFavorite, toggleFavorite }
}
