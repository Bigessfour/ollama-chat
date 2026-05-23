export function TypingIndicator() {
  return (
    <div
      className="flex items-center gap-1 px-4 py-2"
      role="status"
      aria-label="Assistant is typing"
    >
      <span className="sr-only">Assistant is typing</span>
      {[0, 1, 2].map((i) => (
        <span
          key={i}
          className="h-2 w-2 animate-bounce rounded-full bg-zinc-400 dark:bg-zinc-500"
          style={{ animationDelay: `${i * 150}ms` }}
        />
      ))}
    </div>
  )
}
