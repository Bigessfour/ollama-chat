import { API_BASE_URL } from '../lib/env.js'

export class ApiError extends Error {
  constructor(message, { status = 0, isNetworkError = false } = {}) {
    super(message)
    this.name = 'ApiError'
    this.status = status
    this.isNetworkError = isNetworkError
  }
}

async function parseJson(response) {
  try {
    return await response.json()
  } catch {
    return {}
  }
}

async function request(path, options = {}) {
  const { timeoutMs = 15000, ...fetchOptions } = options
  const controller = new AbortController()
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs)

  try {
    const response = await fetch(`${API_BASE_URL}${path}`, {
      headers: {
        'Content-Type': 'application/json',
        ...fetchOptions.headers,
      },
      ...fetchOptions,
      signal: controller.signal,
    })

    const data = await parseJson(response)

    if (!response.ok) {
      throw new ApiError(data.error ?? `Request failed (${response.status})`, {
        status: response.status,
      })
    }

    return data
  } catch (error) {
    if (error instanceof ApiError) throw error

    if (error.name === 'AbortError') {
      throw new ApiError('Request timed out. Please try again.', {
        isNetworkError: true,
      })
    }

    throw new ApiError(
      'Unable to reach the server. Check your connection and try again.',
      { isNetworkError: true },
    )
  } finally {
    clearTimeout(timeoutId)
  }
}

export function getHealth() {
  return request('/api/health', { timeoutMs: 8000 })
}

export function getReady() {
  return request('/api/ready', { timeoutMs: 10000 })
}

export function getReadyAllowNotReady() {
  const controller = new AbortController()
  const timeoutId = setTimeout(() => controller.abort(), 10000)

  return fetch(`${API_BASE_URL}/api/ready`, {
    headers: { 'Content-Type': 'application/json' },
    signal: controller.signal,
  })
    .then(async (response) => {
      const data = await parseJson(response)
      return { ok: response.ok, status: response.status, data }
    })
    .catch((error) => {
      if (error.name === 'AbortError') {
        throw new ApiError('Readiness check timed out.', { isNetworkError: true })
      }
      throw new ApiError('Unable to reach the server.', { isNetworkError: true })
    })
    .finally(() => clearTimeout(timeoutId))
}

export function sendChatMessage(message) {
  return request('/api/chat', {
    method: 'POST',
    body: JSON.stringify({ message }),
    timeoutMs: 130000,
  })
}
