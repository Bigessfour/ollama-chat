export function RetryButton({ onClick, label = 'Retry' }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="rounded-md border border-zinc-300 bg-white px-2 py-1 text-xs font-medium text-zinc-700 hover:bg-zinc-50 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-violet-600 dark:border-zinc-600 dark:bg-zinc-800 dark:text-zinc-200 dark:hover:bg-zinc-700"
    >
      {label}
    </button>
  )
}
