import { useState } from 'react'

export function ChatInput({ onSend, disabled, isPending }) {
  const [draft, setDraft] = useState('')

  const handleSubmit = (event) => {
    event.preventDefault()
    if (disabled || isPending || !draft.trim()) return
    onSend(draft)
    setDraft('')
  }

  const handleKeyDown = (event) => {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault()
      handleSubmit(event)
    }
  }

  return (
    <form
      onSubmit={handleSubmit}
      className="border-t border-zinc-200 bg-white px-4 py-4 dark:border-zinc-800 dark:bg-zinc-900"
      aria-busy={isPending}
    >
      <div className="mx-auto flex max-w-3xl gap-2">
        <label htmlFor="chat-input" className="sr-only">
          Message
        </label>
        <textarea
          id="chat-input"
          rows={2}
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onKeyDown={handleKeyDown}
          disabled={disabled || isPending}
          placeholder={
            disabled
              ? 'Waiting for backend…'
              : 'Type a message… (Enter to send, Shift+Enter for newline)'
          }
          className="min-h-[44px] flex-1 resize-none rounded-xl border border-zinc-300 bg-zinc-50 px-3 py-2 text-sm text-zinc-900 placeholder:text-zinc-400 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-violet-600 disabled:cursor-not-allowed disabled:opacity-60 dark:border-zinc-600 dark:bg-zinc-800 dark:text-zinc-100 dark:placeholder:text-zinc-500"
          aria-disabled={disabled || isPending}
        />
        <button
          type="submit"
          disabled={disabled || isPending || !draft.trim()}
          className="self-end rounded-xl bg-violet-600 px-4 py-2 text-sm font-medium text-white hover:bg-violet-500 disabled:cursor-not-allowed disabled:opacity-50 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-violet-600"
          aria-label="Send message"
        >
          {isPending ? 'Sending…' : 'Send'}
        </button>
      </div>
    </form>
  )
}
