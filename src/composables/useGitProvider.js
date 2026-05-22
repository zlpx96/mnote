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
      url = `${BASE}/repos/search?q=${encodeURIComponent(query)}&per_page=10&access_token=${token}`
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
    // Gitee returns 404 for empty repos; treat root 404 as empty directory
    if (res.status === 404 && path === '') return []
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
    if (platform === 'gitee') body.access_token = token
    const url = `${BASE}/repos/${owner}/${repo}/contents/${path}`
    // Gitee: POST to create (no sha), PUT to update (with sha); GitHub: always PUT
    const method = (platform === 'gitee' && !sha) ? 'POST' : 'PUT'
    const res = await fetch(url, {
      method,
      headers,
      body: JSON.stringify(body),
    })
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

  async function getUserRepos() {
    const url = platform === 'gitee'
      ? `${BASE}/user/repos?access_token=${token}&per_page=100&type=all`
      : `${BASE}/user/repos?per_page=100`
    const res = await request(url)
    if (!res.ok) throw new Error(`Failed to get user repos: ${res.status}`)
    const data = await res.json()
    return data.map(r => ({ full_name: r.full_name, description: r.description, private: r.private }))
  }

  return { validateToken, searchRepos, getUserRepos, getContents, getFileContent, putFile, getFileSha, uploadFile }
}
