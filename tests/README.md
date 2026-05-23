# Testing strategy

This project uses layered tests under each application package, with shared documentation here.

## Layout

```
ollama-chat/
├── tests/README.md              # This file
├── backend/tests/
│   ├── conftest.py              # App, client, and Ollama mock fixtures
│   ├── fixtures/ollama.py       # Reusable mock Ollama service factory
│   ├── unit/
│   │   ├── routes/              # Flask route handlers (HTTP via test client)
│   │   ├── services/            # OllamaService with mocked requests.Session
│   │   ├── utils/               # Metrics and helpers
│   │   └── security/            # Auth, CORS, headers
│   └── integration/
│       └── test_chat_endpoint.py  # Full POST /api/chat stack
└── frontend/
    ├── src/**/*.test.{js,jsx}   # Vitest + React Testing Library
    ├── src/test/setup.js
    └── e2e/                     # Playwright (mocked API)
```

## Backend (pytest)

| Layer | Command | Purpose |
|-------|---------|---------|
| All tests | `cd backend && pytest` | Unit + integration |
| Unit only | `pytest tests/unit` | Fast feedback |
| Integration | `pytest -m integration` | Chat API through Flask |
| Coverage | `pytest` (configured in `pytest.ini`) | HTML + XML reports, 75% minimum |

**Fixtures:** `settings`, `app`, `client`, `mock_ollama_service`, `json_headers` in `tests/conftest.py`.

**Ollama:** Never hit a real Ollama instance in CI. `make_mock_ollama_service()` stubs `generate` and `check_ready`.

## Frontend (Vitest)

| Command | Purpose |
|---------|---------|
| `npm test` | Run component/store unit tests |
| `npm run test:watch` | Watch mode |
| `npm run test:coverage` | V8 coverage report in `frontend/coverage/` |

Tests cover `ChatInput`, `MessageBubble`, `RetryButton`, and `chatStore`.

## E2E (Playwright, optional)

| Command | Purpose |
|---------|---------|
| `npm run test:e2e` | Chat flow with mocked `/api/*` routes |
| `npm run test:e2e:ui` | Interactive debugger |

Playwright starts the Vite dev server and intercepts network calls so no backend or Ollama is required.

## CI

GitHub Actions job **CI** runs:

- Backend: lint (ruff) + pytest with coverage artifacts
- Frontend: ESLint + Vitest + production build
- E2E: Playwright on pull requests and `main` (Chromium only)

Coverage reports are uploaded as workflow artifacts (`backend-coverage`, `frontend-coverage`).
