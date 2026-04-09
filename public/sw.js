const CACHE_NAME = 'mnote-v1'

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE_NAME).then(cache =>
      cache.addAll(['./index.html'])
    )
  )
  self.skipWaiting()
})

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
    )
  )
  self.clients.claim()
})

self.addEventListener('fetch', (e) => {
  // 只缓存同源请求，不缓存 GitHub API
  if (!e.request.url.startsWith(self.location.origin)) return

  e.respondWith(
    fetch(e.request)
      .then(res => {
        const clone = res.clone()
        caches.open(CACHE_NAME).then(cache => cache.put(e.request, clone))
        return res
      })
      .catch(() => caches.match(e.request))
  )
})
