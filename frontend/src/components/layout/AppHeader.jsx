const STATUS_LABEL = {
  online: 'Connected',
  degraded: 'Starting',
  offline: 'Offline',
}

const STATUS_COLOR = {
  online: 'bg-emerald-500',
  degraded: 'bg-amber-500',
  offline: 'bg-red-500',
}

export function AppHeader({ status, model, isLoading }) {
  return (
    <header className="border-b border-zinc-200 bg-white px-4 py-4 dark:border-zinc-800 dark:bg-zinc-900">
      <div className="mx-auto flex max-w-3xl items-center justify-between gap-4">
        <div>
          <h1 className="text-lg font-semibold text-zinc-900 dark:text-zinc-100">
            Ollama Chat
          </h1>
          <p className="text-sm text-zinc-500 dark:text-zinc-400">
            Powered by {model}
          </p>
        </div>
        <div
          className="flex items-center gap-2 text-sm text-zinc-600 dark:text-zinc-300"
          aria-label={`Connection status: ${STATUS_LABEL[status]}`}
        >
          <span
            className={`h-2.5 w-2.5 rounded-full ${STATUS_COLOR[status]} ${isLoading ? 'animate-pulse' : ''}`}
            aria-hidden="true"
          />
          <span>{isLoading ? 'Checking…' : STATUS_LABEL[status]}</span>
        </div>
      </div>
    </header>
  )
}
