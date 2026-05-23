import { beforeEach, describe, expect, it } from 'vitest'
import { useChatStore } from './chatStore.js'

describe('chatStore', () => {
  beforeEach(() => {
    useChatStore.setState({ messages: [] })
  })

  it('adds user and pending assistant messages', () => {
    const { assistantId } = useChatStore.getState().addUserMessage('Hello')

    const messages = useChatStore.getState().messages
    expect(messages).toHaveLength(2)
    expect(messages[0]).toMatchObject({ role: 'user', content: 'Hello', status: 'sent' })
    expect(messages[1]).toMatchObject({
      id: assistantId,
      role: 'assistant',
      content: '',
      status: 'pending',
    })
  })

  it('resolves assistant content', () => {
    const { assistantId } = useChatStore.getState().addUserMessage('Hi')
    useChatStore.getState().resolveAssistantMessage(assistantId, 'Reply')

    const assistant = useChatStore
      .getState()
      .messages.find((m) => m.id === assistantId)
    expect(assistant).toMatchObject({ content: 'Reply', status: 'sent' })
  })

  it('marks assistant errors', () => {
    const { assistantId } = useChatStore.getState().addUserMessage('Hi')
    useChatStore.getState().markAssistantError(assistantId, 'Failed')

    const assistant = useChatStore
      .getState()
      .messages.find((m) => m.id === assistantId)
    expect(assistant).toMatchObject({ content: 'Failed', status: 'error' })
  })
})
