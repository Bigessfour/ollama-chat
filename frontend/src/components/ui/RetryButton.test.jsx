import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { RetryButton } from './RetryButton.jsx'

describe('RetryButton', () => {
  it('calls onClick when pressed', async () => {
    const user = userEvent.setup()
    const onClick = vi.fn()

    render(<RetryButton onClick={onClick} label="Try again" />)
    await user.click(screen.getByRole('button', { name: 'Try again' }))

    expect(onClick).toHaveBeenCalledTimes(1)
  })
})
