import { expect, test } from '@playwright/test'

test.describe('Chat flow', () => {
  test.beforeEach(async ({ page }) => {
    await page.route('**/api/health', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          status: 'ok',
          service: 'ollama-chat-api',
          version: 'test',
          uptime_seconds: 1,
        }),
      })
    })

    await page.route('**/api/ready', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          status: 'ready',
          version: 'test',
          checks: { ollama: { status: 'ready', model: 'gemma:2b', latency_ms: 1 } },
        }),
      })
    })

    await page.route('**/api/chat', async (route) => {
      const payload = route.request().postDataJSON()
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          response: `Echo: ${payload.message}`,
          model: 'gemma:2b',
        }),
      })
    })
  })

  test('user can send a message and see the assistant reply', async ({ page }) => {
    await page.goto('/')

    await expect(page.getByRole('status', { name: /loading connection/i })).toBeHidden({
      timeout: 15_000,
    })

    const input = page.locator('#chat-input')
    await input.fill('Hello from Playwright')
    await page.getByRole('button', { name: 'Send message' }).click()

    await expect(
      page.getByRole('article', { name: 'Your message' }),
    ).toContainText('Hello from Playwright')
    await expect(
      page.getByRole('article', { name: 'Assistant message' }),
    ).toContainText('Echo: Hello from Playwright', { timeout: 10_000 })
  })
})
