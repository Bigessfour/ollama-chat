# Security — Ollama Chat

Security posture, hardening controls, secrets handling, and operator guidance for the Ollama Chat project.

## Threat model

| Asset | Exposure | Controls |
|-------|----------|----------|
| **ALB (HTTP :80)** | Internet-facing | Path routing: `/api/*` → Flask, default → React. Optional `API_KEY` on chat. Rate limits per instance. |
| **Frontend bundle** | Public static files | `VITE_API_URL` is baked at build time — not a secret. CSP headers on nginx. |
| **Flask EC2** | Private subnet, no public IP | SG: TCP 5000 **only** from ALB SG. NACL: 5000 from public subnet CIDRs only. Not directly internet-routable. |
| **React EC2** | Private subnet | SG: TCP 80 **only** from ALB SG. |
| **Ollama (:11434)** | Localhost on Flask host only | `OLLAMA_HOST=127.0.0.1`, no SG rule, NACL **deny** 11434 inbound. |
| **GHCR PAT** | SSM SecureString | Scoped IAM `ssm:GetParameter` on `/ollama-chat/ghcr-pat` only. Never in git or user-data templates. |
| **API key** | SSM SecureString (optional) | `/ollama-chat/api-key` when set via Terraform `TF_VAR_api_key`. |

**Residual risks:** cleartext HTTP to ALB (no TLS/WAF by default), in-memory rate limits (not distributed), optional API auth unless configured.

---

## Hardening checklist

### Before deploy

- [ ] Export `GHCR_PAT` / `TF_VAR_ghcr_pat` — never commit or log
- [ ] Use **Terraform** (not `deploy-aws.sh`) for production-like environments
- [ ] `enable_ssh_between_tiers = false` (default in Terraform dev variables)
- [ ] Set `TF_VAR_api_key` for production chat protection (stored in SSM)
- [ ] Set `REQUIRE_API_KEY_IN_PRODUCTION=true` on Flask when using API key
- [ ] Build frontend with correct `ALB_DNS` (`push-frontend.sh` requires it)
- [ ] Pin container base images by digest when feasible (see Dockerfiles)

### After deploy

- [ ] `curl http://<ALB_DNS>/api/ready` — readiness
- [ ] Confirm Flask/React instances have **no** public IP
- [ ] Verify chat returns 401 without `X-API-Key` when API key is configured
- [ ] Rotate PAT if ever committed, logged, or exposed
- [ ] Access instances via **SSM Session Manager** only (no SSH between tiers)

### Production roadmap

- [ ] ACM certificate + HTTPS listener on ALB (enables HSTS from Flask)
- [ ] AWS WAF on ALB
- [ ] Redis-backed Flask-Limiter for multi-instance rate limits
- [ ] Image digest pinning in Dockerfiles and deploy manifests

---

## Controls by layer

### Docker

| Control | Backend | Frontend |
|---------|---------|----------|
| Multi-stage build | Yes | Yes (`node` → `nginx-unprivileged`) |
| Non-root runtime | `appuser` (UID 10001) | `nginx-unprivileged` image |
| `.dockerignore` | Excludes `.env`, tests, venvs, secrets | Excludes `.env`, tests, dev tooling |
| Health checks | `GET /api/health` | `GET /health` |
| Production server | Gunicorn (not Flask dev) | nginx |
| Container hardening (EC2) | `--cap-drop=ALL`, `no-new-privileges` | Same |

**Note:** Flask binds `0.0.0.0:5000` inside the container so the ALB can reach the host port. Network isolation is enforced by **security groups** and **NACLs**, not container bind address alone.

### Flask application

| Control | Implementation |
|---------|----------------|
| Debug disabled | Gunicorn in Docker; `run.py` refuses `FLASK_DEBUG` |
| Security headers | `X-Content-Type-Options`, `X-Frame-Options`, CSP, `Permissions-Policy`, HSTS when `X-Forwarded-Proto: https` |
| CORS | Explicit origins; `*` blocked when `APP_ENV=production` |
| Input validation | Pydantic on `/api/chat`; max body size; JSON content-type required |
| API key | Optional `X-API-Key`; `secrets.compare_digest`; optional production requirement |
| Rate limiting | Flask-Limiter (per-process; use Redis at scale) |
| Proxy trust | `ProxyFix` for ALB client IP in rate limits |

Environment variables: see [backend/.env.example](backend/.env.example).

### AWS network

```
Internet → ALB:80 (public subnets)
         ├─ default → React:80 (private, ALB SG only)
         └─ /api/*  → Flask:5000 (private, ALB SG only)

Flask/React: private subnets, NAT egress, IMDSv2 required
Ollama: 127.0.0.1:11434 (not in any SG; NACL deny 11434)
```

| Control | Detail |
|---------|--------|
| **Security groups** | Tiered: ALB → React:80, ALB → Flask:5000. No `0.0.0.0/0` to app tiers. |
| **NACLs (Terraform + deploy-aws.sh)** | Private subnets: allow 80/5000 from public subnet CIDRs; ephemeral return within VPC CIDR; **deny** 11434. |
| **IMDSv2** | Required on launch templates (`HttpTokens: required`) |
| **Flask not public** | No internet → instance:5000; only ALB path `/api/*` |

### IAM (least privilege)

| Role | Permissions |
|------|-------------|
| **Flask EC2** | `AmazonSSMManagedInstanceCore` + `ssm:GetParameter` on `/ollama-chat/ghcr-pat` (+ `/ollama-chat/api-key` when configured) |
| **React EC2** | `AmazonSSMManagedInstanceCore` + `ssm:GetParameter` on `/ollama-chat/ghcr-pat` only |

Separate instance profiles per tier (no shared EC2 role). No `ssm:GetParameters` (plural) — single-parameter scope only.

---

## Secrets management

### Never commit

- `GHCR_PAT`, `terraform.tfvars`, `.env` with real values
- AWS access keys, API keys, production URLs with credentials

### Local / operator

```bash
export GHCR_PAT='ghp_...'                    # read:packages (+ write:packages for push)
export TF_VAR_ghcr_pat="$GHCR_PAT"
export TF_VAR_api_key='your-random-api-key'  # optional, stored in SSM
```

### AWS Systems Manager Parameter Store

| Parameter | Type | Purpose |
|-----------|------|---------|
| `/ollama-chat/ghcr-pat` | SecureString | GitHub PAT for `docker pull` on instances |
| `/ollama-chat/api-key` | SecureString | Flask `API_KEY` (created when `TF_VAR_api_key` is set) |

Terraform stores the GHCR PAT on first apply; value changes are ignored (`lifecycle.ignore_changes`). Rotate via:

```bash
aws ssm put-parameter --name /ollama-chat/ghcr-pat --type SecureString \
  --value "$GHCR_PAT" --overwrite
# or: terraform apply -replace=module.iam.aws_ssm_parameter.ghcr_pat
```

### GitHub Actions (CI/CD)

```yaml
env:
  GHCR_PAT: ${{ secrets.GHCR_PAT }}
  TF_VAR_ghcr_pat: ${{ secrets.GHCR_PAT }}
  TF_VAR_api_key: ${{ secrets.API_KEY }}   # optional

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
      aws-region: us-east-1
  - run: ./infrastructure/push-backend.sh
    env:
      GHCR_PAT: ${{ secrets.GHCR_PAT }}
```

Store secrets in **GitHub Secrets** (or your CI secret manager). Never echo or log them.

### Vite build args

`VITE_API_URL` is **public** in the frontend bundle. Never put API keys or PATs in `VITE_*` variables.

---

## User-data and deployment scripts

### User-data (`infrastructure/user-data/`)

| Property | Detail |
|----------|--------|
| **No secrets in files** | PAT/API key fetched from SSM at runtime with `set +x` |
| **Idempotent** | Marker file `/var/lib/ollama-chat/*-bootstrapped`; re-boot starts existing container |
| **Ollama** | Bound to `127.0.0.1` via systemd override |
| **Logging** | `/var/log/ollama-chat-*.log` (mode 600) |
| **IMDSv2** | Token-based metadata fetch |

### Script comparison

| Topic | Terraform | `deploy-aws.sh` |
|-------|-----------|-----------------|
| Private NACLs | Yes | Yes (added) |
| IMDSv2 required | Yes | Yes |
| Idempotent | Yes (state) | **No** — duplicate names on re-run |
| Tier IAM roles | Flask + React separate | Single shared role (legacy) |
| SSH between tiers | Configurable (default **off**) | Not created |

**Recommendation:** Use Terraform for all production-like deployments. Treat `deploy-aws.sh` as legacy/dev only.

### Push scripts

- `push-backend.sh` / `push-frontend.sh`: fail if `GHCR_PAT` missing; PAT via stdin to `docker login` only
- `push-frontend.sh`: requires `ALB_DNS` (prevents wrong CORS origin in bundle)
- `update-phase4.sh`: requires `ALB_DNS`; uses `mktemp` with mode 600 for launch template JSON

---

## Reporting security issues

Open a GitHub issue with:

- Description and impact
- Steps to reproduce
- Whether secrets were exposed (rotate immediately if yes)

Do **not** paste live PATs, AWS keys, or production URLs with credentials in public issues.

---

## Related documentation

- [docs/SECRETS.md](docs/SECRETS.md) — Secrets quick reference (what to set, what never to commit)
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — network and security group design
- [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) — deployment runbooks
- [infrastructure/terraform/README.md](infrastructure/terraform/README.md) — Terraform operations
- [backend/README.md](backend/README.md) — Flask environment variables
