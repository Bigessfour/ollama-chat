# Screenshot guide — submission & portfolio

Use this guide to capture evidence for Code Platoon submission and job applications. Store images **locally** in a `screenshots/` folder at the repo root (ignored by git via [.gitignore](../.gitignore)) or attach them to your submission portal. **Do not commit** PATs, API keys, or URLs that include credentials.

---

## Setup

```bash
mkdir -p screenshots
export ALB_DNS=<your-alb-dns-name>   # after AWS deploy
```

Replace placeholder paths below with your files, e.g. `screenshots/01-alb-target-groups.png`.

---

## Required captures

### 1. ALB target groups (healthy)

**Proves:** AWS stack deployed; instances registered and passing health checks.

**Where:** AWS Console → EC2 → Target Groups → `ollama-chat-flask-tg` and `ollama-chat-react-tg` → Targets tab → Status **healthy**.

**Placeholder:**

```markdown
![ALB target groups showing healthy Flask and React targets](screenshots/01-alb-target-groups.png)
```

**Caption:** *Application Load Balancer target groups with healthy instances in both Flask (port 5000) and React (port 80) groups.*

---

### 2. Liveness and readiness (`curl`)

**Proves:** Probe separation — `/live` without Ollama; `/api/ready` with model available.

**Where:** Terminal on your machine.

```bash
curl -s "http://${ALB_DNS}/live" | jq .
curl -s "http://${ALB_DNS}/api/ready" | jq .
```

**Placeholder:**

```markdown
![Terminal curl output for /live and /api/ready](screenshots/02-health-curl.png)
```

**Caption:** *Liveness returns `status: ok`; readiness returns `checks.ollama` with model `gemma:2b`.*

---

### 3. Chat API (`curl`)

**Proves:** End-to-end inference through Flask → Ollama.

```bash
curl -s -X POST "http://${ALB_DNS}/api/chat" \
  -H 'Content-Type: application/json' \
  -d '{"message":"Say hello in one sentence."}' | jq .
```

**Placeholder:**

```markdown
![Terminal curl POST /api/chat with model response](screenshots/03-chat-curl.png)
```

**Caption:** *POST /api/chat returns JSON with `response` and `model` fields.*

---

### 4. Browser — SPA and chat

**Proves:** User-facing application works through the ALB.

**Where:** Browser → `http://${ALB_DNS}/` → send a chat message → capture UI with response visible.

**Placeholder:**

```markdown
![Ollama Chat SPA in browser with a completed message](screenshots/04-browser-chat.png)
```

**Caption:** *React chat UI served via ALB with a successful model reply.*

---

### 5. CloudWatch Logs (structured JSON)

**Proves:** Enterprise observability — structured logs in AWS.

**Where:** CloudWatch → Log groups → `/ollama-chat/flask/app` → latest log stream → find a line with `"event": "request_completed"`.

**Placeholder:**

```markdown
![CloudWatch Logs Insights or stream showing JSON request_completed](screenshots/05-cloudwatch-logs.png)
```

**Caption:** *Structured JSON application logs shipped by the CloudWatch agent from Docker stdout.*

---

## Optional captures

### 6. CloudWatch alarm (OK state)

**Where:** CloudWatch → Alarms → e.g. `ollama-chat-flask-unhealthy-hosts` → State **OK**.

```markdown
![CloudWatch alarm in OK state](screenshots/06-alarm-ok.png)
```

**Caption:** *Infrastructure alarm monitoring Flask target health.*

---

### 7. GitHub Actions CI (green)

**Where:** GitHub → Actions → latest workflow run on `main`.

```markdown
![GitHub Actions CI workflow passing](screenshots/07-ci-green.png)
```

**Caption:** *Automated backend tests and frontend build on pull request.*

---

### 8. Architecture diagram (doc or draw.io)

**Where:** Export from [ARCHITECTURE.md](ARCHITECTURE.md) mermaid or a simple diagram tool.

```markdown
![High-level architecture Browser ALB Flask React Ollama](screenshots/08-architecture.png)
```

**Caption:** *Three-tier design: ALB path routing, private subnets, Ollama on localhost only.*

---

## Checklist

| # | File | Captured |
|---|------|----------|
| 1 | `01-alb-target-groups.png` | [ ] |
| 2 | `02-health-curl.png` | [ ] |
| 3 | `03-chat-curl.png` | [ ] |
| 4 | `04-browser-chat.png` | [ ] |
| 5 | `05-cloudwatch-logs.png` | [ ] |
| 6 | `06-alarm-ok.png` (optional) | [ ] |
| 7 | `07-ci-green.png` (optional) | [ ] |
| 8 | `08-architecture.png` (optional) | [ ] |

Link completed screenshots in [SUBMISSION.md](SUBMISSION.md) or your portfolio README.

---

## Related

- [SUBMISSION.md](SUBMISSION.md) — Requirement traceability and verification checklist
- [OPERATIONS.md](OPERATIONS.md) — Log group names and Insights queries
