const STATUS_COPY = {
  offline: {
    title: 'Backend unavailable',
    detail: 'Cannot reach the API. Check that the backend is running and try again.',
  },
  degraded: {
    title: 'Model warming up',
    detail:
      'The API is up but Ollama or the model is not ready yet. Chat will unlock when ready.',
  },
}

export function ConnectionBanner({ status, onRetry, isRetrying }) {
  if (status === 'online') return null

  const copy = STATUS_COPY[status] ?? STATUS_COPY.offline

  return (
    <div
      role="status"
      aria-live="polite"
      className="border-b border-amber-200 bg-amber-50 px-4 py-3 text-amber-950 dark:border-amber-900 dark:bg-amber-950/40 dark:text-amber-100"
    >
      <div className="mx-auto flex max-w-3xl flex-wrap items-center justify-between gap-2">
        <div>
          <p className="text-sm font-semibold">{copy.title}</p>
          <p className="text-sm opacity-90">{copy.detail}</p>
        </div>
        <button
          type="button"
          onClick={onRetry}
          disabled={isRetrying}
          className="rounded-lg bg-amber-800 px-3 py-1.5 text-sm font-medium text-white hover:bg-amber-700 disabled:opacity-60 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-amber-800 dark:bg-amber-700 dark:hover:bg-amber-600"
        >
          {isRetrying ? 'Checking…' : 'Retry connection'}
        </button>
      </div>
    </div>
  )
}
