import { useMutation } from '@tanstack/react-query'
import { toast } from 'sonner'
import { sendChatMessage } from '../api/client.js'
import { logError } from '../lib/logger.js'
import { useChatStore } from '../store/chatStore.js'

export function useChat({ enabled }) {
  const addUserMessage = useChatStore((s) => s.addUserMessage)
  const resolveAssistantMessage = useChatStore((s) => s.resolveAssistantMessage)
  const markAssistantError = useChatStore((s) => s.markAssistantError)

  const mutation = useMutation({
    mutationFn: sendChatMessage,
    retry: 2,
    retryDelay: (attempt) => Math.min(1000 * 2 ** attempt, 8000),
  })

  const runChat = async (trimmed, assistantId) => {
    try {
      const result = await mutation.mutateAsync(trimmed)
      resolveAssistantMessage(assistantId, result.response)
    } catch (error) {
      logError('chat.send', error)
      markAssistantError(
        assistantId,
        error.message ?? 'Failed to get a response.',
      )
      if (error.status === 429) {
        toast.error('Rate limit exceeded. Please wait and try again.')
      } else {
        toast.error(error.message ?? 'Failed to send message.')
      }
    }
  }

  const sendMessage = async (text) => {
    if (!enabled) {
      toast.error('Chat is unavailable until the backend is ready.')
      return
    }

    const trimmed = text.trim()
    if (!trimmed) return

    const { assistantId } = addUserMessage(trimmed)
    await runChat(trimmed, assistantId)
  }

  const retryMessage = async (assistantId, userContent) => {
    if (!enabled || !userContent?.trim()) return

    useChatStore.setState((state) => ({
      messages: state.messages.map((msg) =>
        msg.id === assistantId
          ? { ...msg, status: 'pending', content: '' }
          : msg,
      ),
    }))

    await runChat(userContent.trim(), assistantId)
  }

  return {
    sendMessage,
    retryMessage,
    isPending: mutation.isPending,
  }
}
