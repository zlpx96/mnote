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
    // 清除文件缓存，防止旧用户内容残留
    Object.keys(localStorage)
      .filter(k => k.startsWith('mnote_cache_'))
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

  return { getToken, setToken, clearToken, getRepos, addRepo, removeRepo }
}
