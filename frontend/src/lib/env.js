import { z } from 'zod'

const envSchema = z.object({
  VITE_API_URL: z.string().optional(),
  VITE_API_BASE_URL: z.string().optional(),
})

const parsed = envSchema.safeParse(import.meta.env)

if (!parsed.success) {
  const message = parsed.error.errors.map((e) => e.message).join('; ')
  throw new Error(`Invalid environment configuration: ${message}`)
}

function normalizeBaseUrl(raw) {
  const value = (raw ?? '').trim()
  if (!value) return ''
  try {
    const url = new URL(value)
    return url.toString().replace(/\/$/, '')
  } catch {
    throw new Error(
      `VITE_API_URL must be a valid URL or empty for dev proxy mode. Got: "${value}"`,
    )
  }
}

const rawUrl =
  parsed.data.VITE_API_URL ?? parsed.data.VITE_API_BASE_URL ?? ''

export const API_BASE_URL = normalizeBaseUrl(rawUrl)
export const IS_DEV_PROXY = API_BASE_URL === ''
