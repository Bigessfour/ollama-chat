import { create } from 'zustand'

let messageId = 0
function nextId() {
  messageId += 1
  return String(messageId)
}

export const useChatStore = create((set) => ({
  messages: [],

  addUserMessage: (content) => {
    const userId = nextId()
    const assistantId = nextId()
    set((state) => ({
      messages: [
        ...state.messages,
        { id: userId, role: 'user', content, status: 'sent' },
        { id: assistantId, role: 'assistant', content: '', status: 'pending' },
      ],
    }))
    return { userId, assistantId }
  },

  resolveAssistantMessage: (assistantId, content) => {
    set((state) => ({
      messages: state.messages.map((msg) =>
        msg.id === assistantId
          ? { ...msg, content, status: 'sent' }
          : msg,
      ),
    }))
  },

  markAssistantError: (assistantId, errorMessage) => {
    set((state) => ({
      messages: state.messages.map((msg) =>
        msg.id === assistantId
          ? { ...msg, content: errorMessage, status: 'error' }
          : msg,
      ),
    }))
  },

  clearMessages: () => set({ messages: [] }),
}))
