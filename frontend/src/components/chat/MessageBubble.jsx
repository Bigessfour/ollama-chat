import { RetryButton } from '../ui/RetryButton.jsx'

export function MessageBubble({ message, userContent, onRetry }) {
  const isUser = message.role === 'user'
  const isError = message.status === 'error'
  const isPending = message.status === 'pending'

  return (
    <article
      className={`flex ${isUser ? 'justify-end' : 'justify-start'}`}
      aria-label={isUser ? 'Your message' : 'Assistant message'}
    >
      <div
        className={`max-w-[85%] rounded-2xl px-4 py-2 text-sm leading-relaxed ${
          isUser
            ? 'bg-violet-600 text-white'
            : isError
              ? 'border border-red-200 bg-red-50 text-red-900 dark:border-red-900 dark:bg-red-950/50 dark:text-red-100'
              : 'border border-zinc-200 bg-white text-zinc-900 dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-100'
        }`}
      >
        {isPending && !message.content ? (
          <span className="text-zinc-500 dark:text-zinc-400">Thinking…</span>
        ) : (
          <p className="whitespace-pre-wrap">{message.content}</p>
        )}
        {isError && onRetry && (
          <div className="mt-2">
            <RetryButton onClick={() => onRetry(message.id, userContent)} />
          </div>
        )}
      </div>
    </article>
  )
}
