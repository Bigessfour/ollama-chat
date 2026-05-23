export function logError(context, error) {
  const payload = {
    context,
    message: error?.message ?? String(error),
    status: error?.status,
    isNetworkError: error?.isNetworkError,
    stack: error?.stack,
    timestamp: new Date().toISOString(),
  }
  console.error('[ollama-chat]', payload)
}
