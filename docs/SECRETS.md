# Secrets and configuration reference

Quick index of sensitive values for Ollama Chat. **Never commit secrets to git.** Full threat model and hardening: [SECURITY.md](../SECURITY.md).

---

## Secret inventory

| Name | Purpose | Where to set (local / CI) | Stored in AWS | Commit to git? |
|------|---------|---------------------------|---------------|----------------|
| `GHCR_PAT` | Pull/push container images | Shell: `export GHCR_PAT=...` | SSM `/ollama-chat/ghcr-pat` (SecureString) | **Never** |
| `TF_VAR_ghcr_pat` | Terraform creates/updates GHCR PAT in SSM | Same value as `GHCR_PAT` | Written by Terraform on apply | **Never** |
| `API_KEY` | Optional `X-API-Key` on `POST /api/chat` | `backend/.env` or `TF_VAR_api_key` | SSM `/ollama-chat/api-key` (when set) | **Never** |
| `terraform.tfvars` | Terraform variable file | `infrastructure/terraform/environments/dev/` | N/A | **Never** (use `.example` only) |
| `VITE_API_URL` | Public ALB URL baked into frontend bundle | `export ALB_DNS=...` before `push-frontend.sh` | N/A (build-time arg) | OK — **not a secret** |
| GitHub Actions | CI/CD credentials | Repository **Settings → Secrets** | Assumed role / SSM via deploy workflow | **Never** in workflow logs |

---

## Environment files (non-secret defaults)

| File | Scope | Notes |
|------|-------|-------|
| [backend/.env.example](../backend/.env.example) | Flask / Gunicorn | Copy to `backend/.env` locally; never commit `.env` |
| [frontend/.env.example](../frontend/.env.example) | Vite | Leave `VITE_API_URL` empty for dev proxy |
| [terraform.tfvars.example](../infrastructure/terraform/environments/dev/terraform.tfvars.example) | Terraform dev | Copy to `terraform.tfvars`; add real values only locally |

---

## Shell and Terraform variables

### Image push (GHCR)

```bash
export GHCR_PAT='ghp_xxxxxxxx'   # read:packages + write:packages
./infrastructure/push-backend.sh
export ALB_DNS='your-alb.us-east-1.elb.amazonaws.com'
./infrastructure/push-frontend.sh
```

### Terraform apply

```bash
export TF_VAR_ghcr_pat="$GHCR_PAT"
export TF_VAR_api_key='your-random-api-key'   # optional
cd infrastructure/terraform/environments/dev
terraform apply
```

Optional observability (see [terraform.tfvars.example](../infrastructure/terraform/environments/dev/terraform.tfvars.example)):

- `alarm_notification_email` — SNS email for CloudWatch alarms (confirm AWS subscription)
- `enable_observability` — log groups and alarms (default `true`)
- `log_retention_days` — CloudWatch log retention (default `14`)

---

## GitHub Actions secrets

| Secret | Used by |
|--------|---------|
| `GHCR_PAT` | `build-and-push.yml`, image pull in deploy |
| `TF_VAR_ghcr_pat` | Terraform apply in CI (if used) |
| `API_KEY` | Optional `TF_VAR_api_key` |
| `AWS_ROLE_ARN` | OIDC / role for AWS deploy |

Do not echo secrets in workflow output. See [SECURITY.md — GitHub Actions](../SECURITY.md#github-actions-cicd).

---

## What is safe in user-data and logs

| Location | Contains secrets? |
|----------|-------------------|
| `infrastructure/user-data/*.sh` | **No** — PAT/API key fetched from SSM at runtime with `set +x` |
| `/var/log/ollama-chat-*.log` | **No** PATs — bootstrap messages only |
| Frontend JS bundle | Public `VITE_API_URL` only |
| CloudWatch Logs `/ollama-chat/flask/app` | Structured app logs — no API keys if configured correctly |

---

## Rotation

| Secret | Action |
|--------|--------|
| GHCR PAT exposed | Revoke on GitHub → new PAT → `aws ssm put-parameter ... --overwrite` or `terraform apply -replace=module.iam.aws_ssm_parameter.ghcr_pat` |
| API key exposed | New key in SSM + instance refresh / redeploy Flask containers |

---

## Related documentation

- [SECURITY.md](../SECURITY.md) — Threat model and checklist
- [DEPLOYMENT.md](DEPLOYMENT.md) — Deploy commands
- [SUBMISSION.md](SUBMISSION.md) — Reviewer evidence map
