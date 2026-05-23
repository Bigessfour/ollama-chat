import { useBackendStatus } from '../../hooks/useBackendStatus.js'
import { useChat } from '../../hooks/useChat.js'
import { useChatStore } from '../../store/chatStore.js'
import { AppHeader } from '../layout/AppHeader.jsx'
import { ConnectionBanner } from '../layout/ConnectionBanner.jsx'
import { ChatInput } from './ChatInput.jsx'
import { MessageList } from './MessageList.jsx'

export function ChatPage() {
  const messages = useChatStore((s) => s.messages)
  const { status, isLoading, isOnline, model, refetch, healthQuery, readyQuery } =
    useBackendStatus()
  const { sendMessage, retryMessage, isPending } = useChat({ enabled: isOnline })

  const isRetrying = healthQuery.isFetching || readyQuery.isFetching

  return (
    <div className="flex min-h-screen flex-col">
      <AppHeader status={status} model={model} isLoading={isLoading} />
      <ConnectionBanner
        status={status}
        onRetry={refetch}
        isRetrying={isRetrying}
      />
      {isLoading ? (
        <div
          className="flex flex-1 items-center justify-center"
          role="status"
          aria-label="Loading connection status"
        >
          <div className="h-8 w-8 animate-spin rounded-full border-2 border-violet-600 border-t-transparent" />
        </div>
      ) : (
        <>
          <MessageList
            messages={messages}
            onRetry={retryMessage}
            showTyping={isPending}
          />
          <ChatInput
            onSend={sendMessage}
            disabled={!isOnline}
            isPending={isPending}
          />
        </>
      )}
    </div>
  )
}
