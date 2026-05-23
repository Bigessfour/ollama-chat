import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { ChatInput } from './ChatInput.jsx'

describe('ChatInput', () => {
  it('sends trimmed message on button click', async () => {
    const user = userEvent.setup()
    const onSend = vi.fn()

    render(<ChatInput onSend={onSend} disabled={false} isPending={false} />)

    const input = screen.getByRole('textbox', { name: 'Message' })
    await user.type(input, '  Hello world  ')
    await user.click(screen.getByRole('button', { name: /send message/i }))

    expect(onSend).toHaveBeenCalledWith('  Hello world  ')
    expect(input).toHaveValue('')
  })

  it('does not send when disabled', async () => {
    const user = userEvent.setup()
    const onSend = vi.fn()

    render(<ChatInput onSend={onSend} disabled isPending={false} />)

    await user.type(screen.getByRole('textbox', { name: 'Message' }), 'Hello')
    await user.click(screen.getByRole('button', { name: /send message/i }))

    expect(onSend).not.toHaveBeenCalled()
  })

  it('shows sending label while pending', () => {
    render(<ChatInput onSend={vi.fn()} disabled={false} isPending />)

    expect(screen.getByRole('button', { name: /send message/i })).toHaveTextContent(
      'Sending…',
    )
  })
})
