import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { MessageBubble } from './MessageBubble.jsx'

describe('MessageBubble', () => {
  it('renders user messages on the right', () => {
    render(
      <MessageBubble
        message={{ id: '1', role: 'user', content: 'Hi', status: 'sent' }}
      />,
    )

    expect(screen.getByLabelText('Your message')).toBeInTheDocument()
    expect(screen.getByText('Hi')).toBeInTheDocument()
  })

  it('renders assistant thinking state', () => {
    render(
      <MessageBubble
        message={{ id: '2', role: 'assistant', content: '', status: 'pending' }}
      />,
    )

    expect(screen.getByText('Thinking…')).toBeInTheDocument()
  })

  it('shows retry for failed assistant messages', async () => {
    const user = userEvent.setup()
    const onRetry = vi.fn()

    render(
      <MessageBubble
        message={{
          id: '3',
          role: 'assistant',
          content: 'Something went wrong',
          status: 'error',
        }}
        userContent="retry me"
        onRetry={onRetry}
      />,
    )

    await user.click(screen.getByRole('button', { name: 'Retry' }))
    expect(onRetry).toHaveBeenCalledWith('3', 'retry me')
  })
})
