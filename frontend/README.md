# Ollama Chat Frontend

React 19 + Vite 8 single-page application for chatting with a local Ollama model via the Flask API proxy.

---

## Features

- Chat UI with message history, typing indicator, and per-message retry
- TanStack Query for API polling, retries, and mutations
- Zustand for client-side message state
- Connection banner when backend or model is unavailable
- Error boundary, toast notifications, structured error logging
- Accessible layout (ARIA labels, keyboard send, focus rings)
- Tailwind CSS v4 styling with light/dark support
- Multi-stage Docker image with unprivileged nginx on port 8080

---

## Project structure

```
frontend/src/
├── app/              # App shell and providers
├── api/              # HTTP client and query keys
├── components/       # UI (chat, layout, errors)
├── hooks/            # useBackendStatus, useChat
├── store/            # Zustand chat store
├── lib/              # env validation (zod), logger
└── constants/        # config re-exports
```

---

## Environment variables

Copy [`.env.example`](.env.example) to `.env` for local development.

| Variable | Dev | Production build |
|----------|-----|------------------|
| `VITE_API_URL` | *(empty)* — uses Vite proxy | `http://<ALB-DNS>` (no trailing slash) |
| `VITE_API_BASE_URL` | Deprecated alias | Same as above |

Empty `VITE_API_URL` enables same-origin requests; Vite proxies `/api` to `http://localhost:5002` (see [`vite.config.js`](vite.config.js)).

Validation runs at startup via zod in [`src/lib/env.js`](src/lib/env.js).

---

## Local development

### Prerequisites

- Node.js 20+
- npm 10+
- Backend running (see [backend/README.md](../backend/README.md))

### Run

```bash
cd frontend
cp .env.example .env
npm install
npm run dev
```

Open http://localhost:5173

### Production preview

```bash
npm run build
npm run preview
```

---

## Docker

Build from repository root:

```bash
docker build \
  --build-arg VITE_API_URL=http://<ALB-DNS> \
  -t ollama-chat-frontend ./frontend

docker run -p 8080:8080 ollama-chat-frontend
curl http://localhost:8080/health
```

On AWS EC2, the container listens on **8080**; host maps **80:8080** so the ALB target group stays on port 80.

Image uses `nginxinc/nginx-unprivileged:alpine` (non-root).

---

## API usage

The UI calls:

| Endpoint | Purpose |
|----------|---------|
| `GET /api/health` | Liveness polling |
| `GET /api/ready` | Readiness (Ollama + model) |
| `POST /api/chat` | Send message |

Chat is disabled until `/api/ready` returns 200.

---

## Health endpoints

| Path | Description |
|------|-------------|
| `/health` | nginx JSON liveness (Docker `HEALTHCHECK`) |
| `public/health.json` | Static file in build output |
| `<meta name="app-health" content="ok" />` | HTML meta tag |

---

## Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Vite dev server |
| `npm run build` | Production build to `dist/` |
| `npm run preview` | Preview production build |
| `npm run lint` | ESLint |

---

## Related documentation

- [../README.md](../README.md) — Project overview
- [../backend/README.md](../backend/README.md) — API backend
- [../docs/DEPLOYMENT.md](../docs/DEPLOYMENT.md) — AWS deploy runbook
