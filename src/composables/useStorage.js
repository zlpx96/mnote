// src/composables/useStorage.js
const PLATFORM_KEY = 'mnote_platform'
const FAVORITES_KEY = 'mnote_favorites'

function tokenKey(platform) { return `mnote_token_${platform}` }
function reposKey(platform) { return `mnote_repos_${platform}` }
function cacheKey(platform, path) { return `mnote_cache_${platform}_${path}` }
function scrollKey(platform, path) { return `mnote_scroll_${platform}_${path}` }

let _migrated = false

export function useStorage() {
  // Migrate legacy keys on first call
  function migrate() {
    if (_migrated) return
    _migrated = true
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
