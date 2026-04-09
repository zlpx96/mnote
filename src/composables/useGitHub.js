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
    const res = await fetch(
      `${BASE}/search/repositories?q=${encodeURIComponent(query)}+user:@me&per_page=10`,
      { headers }
    )
    if (!res.ok) throw new Error('Search failed')
    const data = await res.json()
    return data.items.map(r => ({ full_name: r.full_name, description: r.description, private: r.private }))
  }

  async function getContents(owner, repo, path = '') {
    const res = await fetch(
      `${BASE}/repos/${owner}/${repo}/contents/${path}`,
      { headers }
    )
    if (res.status === 403) {
      const data = await res.json()
      if (data.message?.includes('rate limit')) {
        const reset = res.headers.get('X-RateLimit-Reset')
        throw new Error(`RATE_LIMIT:${reset}`)
      }
    }
    if (!res.ok) throw new Error(`Failed to get contents: ${res.status}`)
    return await res.json()
  }

  async function getFileContent(owner, repo, path) {
    const data = await getContents(owner, repo, path)
    if (data.encoding !== 'base64') throw new Error('Unexpected encoding')
    return atob(data.content.replace(/\n/g, ''))
  }

  return { validateToken, searchRepos, getContents, getFileContent }
}
