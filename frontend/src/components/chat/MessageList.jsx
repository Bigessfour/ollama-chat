import { useEffect, useRef } from 'react'
import { MessageBubble } from './MessageBubble.jsx'
import { TypingIndicator } from './TypingIndicator.jsx'

export function MessageList({ messages, onRetry, showTyping }) {
  const bottomRef = useRef(null)

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages, showTyping])

  const getUserContentBefore = (index) => {
    for (let i = index - 1; i >= 0; i -= 1) {
      if (messages[i].role === 'user') return messages[i].content
    }
    return ''
  }

  return (
    <div
      className="flex-1 overflow-y-auto px-4 py-4"
      role="log"
      aria-live="polite"
      aria-relevant="additions"
      aria-label="Chat messages"
    >
      <div className="mx-auto flex max-w-3xl flex-col gap-3">
        {messages.length === 0 && (
          <p className="py-12 text-center text-sm text-zinc-500 dark:text-zinc-400">
            Send a message to start chatting with the local model.
          </p>
        )}
        {messages.map((message, index) => (
          <MessageBubble
            key={message.id}
            message={message}
            userContent={getUserContentBefore(index)}
            onRetry={message.status === 'error' ? onRetry : undefined}
          />
        ))}
        {showTyping && <TypingIndicator />}
        <div ref={bottomRef} />
      </div>
    </div>
  )
}
