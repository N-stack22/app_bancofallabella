import axios from 'axios'

export const TOKEN_KEY = 'cm_token'
export const USER_KEY = 'cm_user'

const baseURL = import.meta.env.VITE_BASE_URL || import.meta.env.VITE_API_URL || 'http://localhost:8003'
const cache = new Map()
const inFlight = new Map()

const api = axios.create({
  baseURL,
  headers: { 'Content-Type': 'application/json' },
  timeout: 20000,
})

api.interceptors.request.use((config) => {
  const token = localStorage.getItem(TOKEN_KEY)
  if (token && token !== 'demo-falabella') {
    config.headers = config.headers || {}
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

api.interceptors.response.use(
  (response) => response,
  (error) => Promise.reject(error),
)

export default api

export function isDemoSession() {
  return (localStorage.getItem(TOKEN_KEY) || 'demo-falabella') === 'demo-falabella'
}

export async function cachedGet(url, options = {}, ttlMs = 30000) {
  const params = options.params ? JSON.stringify(options.params) : ''
  const key = `${url}?${params}`
  const hit = cache.get(key)
  if (hit && Date.now() - hit.time < ttlMs) return hit.data
  if (inFlight.has(key)) return inFlight.get(key)

  const request = api.get(url, options)
    .then(({ data }) => {
      cache.set(key, { data, time: Date.now() })
      return data
    })
    .catch((error) => {
      if (hit?.data) return hit.data
      throw error
    })
    .finally(() => inFlight.delete(key))

  inFlight.set(key, request)
  return request
}

export function invalidateApiCache(prefix = '') {
  for (const key of cache.keys()) {
    if (!prefix || key.startsWith(prefix)) cache.delete(key)
  }
}
