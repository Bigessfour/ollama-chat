export function ErrorFallback({ error, resetErrorBoundary }) {
  return (
    <div
      className="flex min-h-screen flex-col items-center justify-center gap-4 bg-zinc-50 px-4 dark:bg-zinc-950"
      role="alert"
    >
      <h1 className="text-xl font-semibold text-zinc-900 dark:text-zinc-100">
        Something went wrong
      </h1>
      <p className="max-w-md text-center text-sm text-zinc-600 dark:text-zinc-400">
        {error?.message ?? 'An unexpected error occurred.'}
      </p>
      <button
        type="button"
        onClick={resetErrorBoundary}
        className="rounded-lg bg-violet-600 px-4 py-2 text-sm font-medium text-white hover:bg-violet-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-violet-600"
      >
        Reload application
      </button>
    </div>
  )
}
