# Ollama Chat — Development Log

> Running log of steps taken and rationale. Append new entries at the bottom as work continues.

**Repository:** [Bigessfour/ollama-chat](https://github.com/Bigessfour/ollama-chat)  
**Last updated:** 2026-05-23

---

## Step 1 — Clone repository and scaffold project layout

**What we did**

```bash
git clone https://github.com/Bigessfour/ollama-chat.git
cd ollama-chat
mkdir -p backend frontend infrastructure docs
```

**Why**

- Start from the GitHub remote as the source of truth.
- Split the app into clear boundaries early: API (`backend`), UI (`frontend`), deployment/ops (`infrastructure`), and documentation (`docs`).
- The repo was empty at clone time, so this structure defines how the project will grow.

---

## Step 2 — Define backend Python dependencies

**What we did**

Created `backend/requirements.txt`:

```
flask==3.0.3
flask-cors==4.0.1
requests==2.32.3
gunicorn==22.0.0
```

Also added wrapper files at the repo root and `ollama-chat/` that point to the backend file (`-r backend/requirements.txt`) so `pip install -r requirements.txt` works from more than one directory.

**Why**

| Package | Purpose |
|---------|---------|
| `flask` | Lightweight HTTP API for health checks and chat proxy |
| `flask-cors` | Allow the React dev server (different origin/port) to call the API |
| `requests` | Forward chat prompts to the Ollama HTTP API |
| `gunicorn` | Production WSGI server inside Docker / ECS (not Flask’s dev server) |

Pinned versions keep local, Docker, and future CI builds reproducible.

---

## Step 3 — Set up Python virtual environment

**What we did**

```bash
python3 -m venv .venv   # backend/.venv and parent Ollama-Chat/.venv
source .venv/bin/activate
pip install -r requirements.txt
```

**Why**

- macOS Python is “externally managed” (PEP 668); installing packages globally fails without a venv.
- Isolates project dependencies from the system Python and other projects.

---

## Step 4 — Implement Flask API (`backend/app.py`)

**What we did**

Built a small proxy API with two routes:

| Route | Method | Behavior |
|-------|--------|----------|
| `/api/health` | GET | Ping Ollama `/api/tags`; return status + model name |
| `/api/chat` | POST | Accept `{ "message": "..." }`, forward to Ollama `/api/generate` |

Configuration:

- `OLLAMA_URL` env var (default `http://localhost:11434`)
- `MODEL = "gemma:2b"`
- CORS enabled for all origins (to be tightened before production)

**Why**

- The browser should not talk to Ollama directly; the backend centralizes model name, timeouts, and error handling.
- `/api/health` gives a quick way to verify Ollama connectivity before debugging chat.
- Non-streaming `/api/generate` keeps the first version simple; streaming can be added later.

---

## Step 5 — Pull Ollama model

**What we did**

```bash
ollama pull gemma:2b
```

**Why**

- The backend is hard-coded to `gemma:2b`. Without the model pulled, chat requests fail at runtime.
- Initially only `llama3.2:1b` was installed; pulling `gemma:2b` aligned the runtime with the code.

---

## Step 6 — Containerize the backend

**What we did**

Created `backend/Dockerfile`:

- Base: `python:3.11-slim`
- Install from `requirements.txt`
- Run with gunicorn on port 5000 (2 workers, 4 threads)

Local run example:

```bash
docker build -t ollama-chat-backend ./backend
docker run -p 5002:5000 -e OLLAMA_URL=http://host.docker.internal:11434 ollama-chat-backend
```

**Why**

- Docker matches the target deployment model (ECS/Fargate).
- `host.docker.internal` lets a container reach Ollama on the Mac host.
- Port **5002** was used locally because **5000** is often taken by macOS AirPlay and **5001** was already used by another project.

---

## Step 7 — Scaffold React frontend (Vite)

**What we did**

```bash
cd frontend
npm create vite@latest . -- --template react
npm install
```

**Why**

- Vite gives fast HMR for local development and a simple production build.
- React is a standard choice for a chat UI with component-based message lists and input handling.

---

## Step 8 — Frontend folder structure and API client

**What we did**

Added standard directories and starter files:

```
frontend/src/
├── api/client.js       # getHealth(), sendChatMessage()
├── components/
├── constants/config.js # VITE_API_BASE_URL
├── hooks/
├── pages/
├── styles/
└── utils/
```

Also added:

- `frontend/requirements.txt` — documents Node/npm prerequisites and packages (mirrors `package.json`)
- `frontend/.env.example`
- Vite dev proxy: `/api` → backend (initially `localhost:5002`)

**Why**

- Separating `api/`, `components/`, and `hooks/` keeps the chat UI maintainable as it grows.
- `api/client.js` centralizes fetch logic and error handling.
- A dependency manifest in `requirements.txt` parallels the backend and helps anyone onboarding without reading `package.json` alone.

---

## Step 9 — Environment variable strategy (`VITE_API_BASE_URL`)

**What we did**

Standardized on **`VITE_API_BASE_URL`** (not `VITE_API_URL`):

- **Local dev:** leave empty → requests use relative `/api/*` through the Vite proxy
- **Production Docker build:** set to `http://<ALB-DNS>` at build time

Updated `src/constants/config.js`:

```js
export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? ''
```

**Why**

- Empty base URL + Vite proxy avoids hardcoding `localhost:5002` in frontend code.
- Vite bakes env vars at **build** time, so production needs the ALB URL when the image is built—not at container runtime.
- `VITE_API_BASE_URL` is clearer than `VITE_API_URL` because the app appends paths like `/api/chat`.

---

## Step 10 — GHCR multi-arch image plan and Docker scaffold

**What we did**

**Auth & builder**

```bash
docker login ghcr.io -u Bigessfour
docker buildx create --use --name multiarch
```

**Backend image (target)**

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/bigessfour/ollama-chat-backend:latest \
  --push ./backend
```

**Frontend Docker (added before ALB exists)**

- `frontend/Dockerfile` — Node build stage + nginx runtime
- `frontend/nginx.conf` — SPA `try_files` fallback
- `frontend/.dockerignore`, `backend/.dockerignore`

**Push scripts**

- `infrastructure/push-backend.sh`
- `infrastructure/push-frontend.sh` (requires `ALB_DNS` + `GHCR_PAT`)

**Why**

- **Multi-arch (`linux/amd64`, `linux/arm64`):** ECS Fargate and local Mac (ARM) need different architectures from one pipeline.
- **GHCR:** Host images alongside the GitHub repo under `ghcr.io/bigessfour/`.
- **Frontend nginx image:** Production serves static files; API calls go to the ALB, not nginx.
- **Build-time `VITE_API_BASE_URL`:** Browser must know the public ALB hostname after deploy.
- **Deferred frontend push:** ALB DNS is not available yet; backend push blocked on PAT scope (see Step 11).

**Target architecture**

```
Browser → ALB → /     → frontend (nginx)
              → /api/* → backend (gunicorn) → Ollama
```

---

## Step 11 — GHCR push attempt and blocker

**What we did**

- Verified multi-arch **builds** succeed for both backend and frontend (without push).
- Attempted push to `ghcr.io/bigessfour/ollama-chat-backend:latest`.
- Login via `gh auth token` succeeded for read operations; **push failed** with `permission_denied: The token provided does not match expected scopes`.

**Why it failed**

The GitHub CLI token had `repo`, `gist`, `read:org` but not **`write:packages`**. GHCR pushes require that scope.

**Resolution (pending)**

```bash
# Option A: PAT with write:packages
export GHCR_PAT=your_pat_here
./infrastructure/push-backend.sh

# Option B: refresh gh auth (interactive)
gh auth refresh -h github.com -s write:packages
```

When ALB DNS is ready:

```bash
export GHCR_PAT=your_pat_here
export ALB_DNS=your-alb-hostname.elb.amazonaws.com
./infrastructure/push-frontend.sh
```

---

## Current project state

| Area | Status |
|------|--------|
| Backend API | Implemented (`app.py`) |
| Backend Docker | Built locally; GHCR push pending PAT |
| Ollama model | `gemma:2b` pulled |
| Frontend scaffold | Vite + React + folder structure |
| Frontend API client | Stub (`getHealth`, `sendChatMessage`) |
| Chat UI | Not yet built (still Vite starter template) |
| Frontend Docker | Dockerfile validated; GHCR push pending ALB + PAT |
| Infrastructure / ALB | Not deployed |
| GHCR images | Not pushed |

---

## Local development quick reference

```bash
# Terminal 1 — backend (Docker)
docker run -p 5002:5000 -e OLLAMA_URL=http://host.docker.internal:11434 ollama-chat-backend

# Terminal 2 — frontend
cd frontend
cp .env.example .env   # VITE_API_BASE_URL= (empty)
npm run dev            # http://localhost:5173
```

---

## Next steps (to be appended as completed)

- [ ] Obtain GHCR PAT with `write:packages`; push backend image
- [ ] Deploy ALB + target groups (frontend + backend)
- [ ] Push frontend image with `VITE_API_BASE_URL=http://<ALB-DNS>`
- [ ] Build chat UI components (message list, input, loading/error states)
- [ ] Tighten CORS to ALB origin only
- [ ] Add streaming chat support (optional)

---

*Add new steps below this line as development continues.*
