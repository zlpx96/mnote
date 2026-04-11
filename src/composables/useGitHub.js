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
    const res = await request(`${BASE}/search/repositories?q=${encodeURIComponent(query)}&per_page=10`)
    if (!res.ok) throw new Error('Search failed')
    const data = await res.json()
    return data.items.map(r => ({ full_name: r.full_name, description: r.description, private: r.private }))
  }

  async function request(url) {
    const res = await fetch(url, { headers })
    if (res.status === 401) throw new Error('UNAUTHORIZED')
    if (res.status === 403 || res.status === 429) {
      const data = await res.clone().json().catch(() => ({}))
      if (data.message?.includes('rate limit')) {
        const reset = res.headers.get('X-RateLimit-Reset')
        throw new Error(`RATE_LIMIT:${reset}`)
      }
    }
    return res
  }

  async function getContents(owner, repo, path = '') {
    const res = await request(`${BASE}/repos/${owner}/${repo}/contents/${path}`)
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

  async function putFile(owner, repo, path, content, sha = null) {
    const body = {
      message: sha ? `update: ${path}` : `create: ${path}`,
      content: btoa(unescape(encodeURIComponent(content))),
    }
    if (sha) body.sha = sha
    const res = await fetch(`${BASE}/repos/${owner}/${repo}/contents/${path}`, {
      method: 'PUT',
      headers: { ...headers, 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    })
    if (res.status === 401) throw new Error('UNAUTHORIZED')
    if (!res.ok) throw new Error(`Failed to write file: ${res.status}`)
    return await res.json()
  }

  async function getFileSha(owner, repo, path) {
    const res = await request(`${BASE}/repos/${owner}/${repo}/contents/${path}`)
    if (res.status === 404) return null
    if (!res.ok) throw new Error(`Failed to get file sha: ${res.status}`)
    const data = await res.json()
    return data.sha
  }

  return { validateToken, searchRepos, getContents, getFileContent, putFile, getFileSha }
}
