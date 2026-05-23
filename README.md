# Ollama Chat

A full-stack chat application that proxies [Ollama](https://ollama.com) through a Flask API and serves a React single-page application. The project includes production-style AWS deployment: multi-AZ VPC, Application Load Balancer path routing, Auto Scaling Groups in private subnets, and container images on GitHub Container Registry (GHCR).

**Repository:** [github.com/Bigessfour/ollama-chat](https://github.com/Bigessfour/ollama-chat)

---

## Overview and goals

Ollama Chat demonstrates how to build and operate a local-LLM web stack end to end:

- **Locally:** Run Ollama, a Flask API proxy, and a Vite/React dev server for rapid iteration.
- **In AWS:** Deploy containerized frontend and backend tiers behind an ALB, with Ollama co-located on backend instances (not exposed to the internet).

Primary learning outcomes for portfolio and Code Platoon review:

- Separation of UI, API, and inference layers
- Path-based ALB routing (`/api/*` vs static SPA)
- Private subnet application tier with controlled egress via NAT
- Secrets handling (GitHub PAT in SSM Parameter Store, not in user-data)

---

## Architecture

```mermaid
flowchart TB
  User[Browser] --> ALB[ALB_HTTP_80]
  ALB -->|"/api/*"| FlaskASG[Flask_ASG_private]
  ALB -->|default| ReactASG[React_ASG_private]
  FlaskASG --> Ollama[Ollama_localhost_11434]
  FlaskASG --> NAT[NAT_Gateway]
  ReactASG --> NAT
  NAT --> IGW[Internet_Gateway]
```

For VPC layout, security groups, NACLs, and data flows, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## Technology stack

| Layer | Technology |
|-------|------------|
| Frontend | React 19, Vite 8, nginx (production container) |
| Backend | Python 3.11, Flask 3, Gunicorn, flask-cors, requests |
| LLM runtime | Ollama (`gemma:2b`) |
| Containers | Docker multi-arch builds (`linux/amd64`, `linux/arm64`) |
| Registry | GitHub Container Registry (GHCR) |
| AWS | VPC, subnets, NAT, ALB, EC2 ASG, IAM, SSM Parameter Store |
| Deployment | Bash scripts (`infrastructure/*.sh`) |

---

## Repository structure

```
ollama-chat/
├── backend/           # Flask API proxy to Ollama (see backend/README.md)
├── frontend/          # React SPA (Vite)
├── infrastructure/    # AWS deploy scripts, EC2 user-data
├── docs/              # Architecture, deployment, submission checklist
└── requirements.txt   # Wrapper → backend/requirements.txt
```

After cloning, run all commands from the repository root:

```bash
git clone https://github.com/Bigessfour/ollama-chat.git
cd ollama-chat
```

---

## Prerequisites

| Requirement | Purpose |
|-------------|---------|
| [Ollama](https://ollama.com/download) | Local LLM runtime |
| Node.js 20+ and npm 10+ | Frontend dev server |
| Docker | Backend container; image builds for AWS |
| Python 3.11+ (optional) | Run Flask without Docker |
| AWS CLI v2 | Deploy and manage infrastructure |
| AWS account | EC2, VPC, ALB, IAM, SSM permissions |
| GitHub PAT | `read:packages` (EC2 pull), `write:packages` (image push) |

---

## Local development

### 1. Pull the Ollama model

The API uses model `gemma:2b` by default (override with `OLLAMA_MODEL` — see [backend/.env.example](backend/.env.example)):

```bash
ollama pull gemma:2b
```

### 2. Start the backend

**Docker (recommended on macOS — port 5002 avoids conflicts with AirPlay on 5000):**

```bash
docker build -t ollama-chat-backend ./backend
docker run -p 5002:5000 \
  -e OLLAMA_URL=http://host.docker.internal:11434 \
  ollama-chat-backend
```

**Or run the dev server directly (port 5000):**

```bash
cd backend
python3.11 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
python run.py
```

If using port 5000, change the proxy target in `frontend/vite.config.js` from `http://localhost:5002` to `http://localhost:5000`.

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_URL` | `http://localhost:11434` | Ollama HTTP API base URL |
| `OLLAMA_MODEL` | `gemma:2b` | Model for chat and readiness checks |

Full backend configuration: [backend/README.md](backend/README.md).

### 3. Start the frontend

```bash
cd frontend
cp .env.example .env    # leave VITE_API_URL empty for dev proxy
npm install
npm run dev
```

Open http://localhost:5173. Requests to `/api/*` are proxied to the backend (default `http://localhost:5002`).

| Variable | Dev value | Description |
|----------|-----------|-------------|
| `VITE_API_URL` | *(empty)* | Empty uses same-origin paths + Vite proxy |

Frontend details: [frontend/README.md](frontend/README.md).

### 4. Verify the API

```bash
curl http://localhost:5002/api/health
curl http://localhost:5002/api/ready
curl -X POST http://localhost:5002/api/chat \
  -H 'Content-Type: application/json' \
  -d '{"message":"Hello"}'
```

Use port `5000` if running `python run.py` without Docker port mapping.

### Current implementation status

| Component | Status |
|-----------|--------|
| Backend `/api/health`, `/api/ready`, `/api/chat` | Implemented |
| Frontend chat UI | Implemented (TanStack Query + Zustand) |
| Connection handling / retries | Implemented |

---

## How to Demo

Use this section for Code Platoon review, portfolio interviews, or a quick technical walkthrough.

### Option A — Local (about 5 minutes, no AWS)

1. Pull the model: `ollama pull gemma:2b`
2. Start the backend (Docker on port 5002 recommended on macOS):

   ```bash
   docker build -t ollama-chat-backend ./backend
   docker run -p 5002:5000 -e OLLAMA_URL=http://host.docker.internal:11434 ollama-chat-backend
   ```

   Or use `python run.py` in `backend/` on port 5000 (adjust Vite proxy if needed).

3. Start the frontend:

   ```bash
   cd frontend && npm install && npm run dev
   ```

4. Open http://localhost:5173 — send a chat message in the UI.
5. Show API probes and chat in the terminal:

   ```bash
   curl -s http://localhost:5002/live | jq .
   curl -s http://localhost:5002/api/ready | jq .
   curl -s -X POST http://localhost:5002/api/chat \
     -H 'Content-Type: application/json' \
     -d '{"message":"Hello"}' | jq .
   ```

### Option B — AWS (deployed stack)

1. Open `http://<ALB_DNS>/` in a browser and send a chat message.
2. From your workstation:

   ```bash
   export ALB_DNS=<your-alb-dns-name>
   curl -s "http://${ALB_DNS}/live" | jq .
   curl -s "http://${ALB_DNS}/api/ready" | jq .
   curl -s -X POST "http://${ALB_DNS}/api/chat" \
     -H 'Content-Type: application/json' \
     -d '{"message":"Hello"}' | jq .
   ```

3. (Optional) In CloudWatch Logs, open `/ollama-chat/flask/app` and show a JSON `request_completed` line. See [docs/OPERATIONS.md](docs/OPERATIONS.md).

Full deploy steps: [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md). Screenshot list: [docs/SCREENSHOTS.md](docs/SCREENSHOTS.md).

### What to highlight for reviewers

- **ALB path routing** — `/api/*` to Flask, default to React SPA
- **Private subnets** — app tier has no direct internet inbound; Ollama on `127.0.0.1` only
- **Secrets** — GHCR PAT in SSM, not in user-data or git ([docs/SECRETS.md](docs/SECRETS.md))
- **Observability** — structured JSON logs, EMF metrics, `/live` vs `/ready`, CloudWatch alarms ([docs/OPERATIONS.md](docs/OPERATIONS.md))

Submission evidence map: [docs/SUBMISSION.md](docs/SUBMISSION.md).

---

## Deployment overview

Full procedures: [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md).

| Step | Action | Script |
|------|--------|--------|
| 1 | Build and push backend image to GHCR | `./infrastructure/push-backend.sh` |
| 2 | Deploy AWS stack (VPC, ALB, ASGs) | [Terraform](infrastructure/terraform/README.md) (recommended), `./infrastructure/deploy-aws.sh`, or Console |
| 3 | Note ALB DNS; build frontend with API URL | `export ALB_DNS=<alb-hostname>` then `./infrastructure/push-frontend.sh` |
| 4 | Roll out user-data or image updates | `./infrastructure/update-phase4.sh` |

**Important:** Do not run `deploy-aws.sh` twice in the same account/region without teardown — it creates a new stack each time. For production-like hardening (split IAM roles, optional API key in SSM), use [Terraform](infrastructure/terraform/README.md). See [SECURITY.md](SECURITY.md) for the full checklist.

Default region: `us-east-1` (override with `AWS_REGION`).

---

## Cost considerations

Approximate monthly cost drivers at minimum capacity (2× Flask `t3.large` + 2× React `t3.small`, `us-east-1`):

| Resource | Rough cost | Notes |
|----------|------------|-------|
| EC2 instances | Highest line item | 4 instances at min desired capacity |
| NAT Gateway | ~$32/month + data | Single NAT in one AZ |
| Application Load Balancer | ~$16–22/month + LCU | Hourly + usage |
| Elastic IP | Low | Associated with NAT |
| Data transfer | Variable | GHCR pulls, Ollama install, model download |

Ollama model pulls and inference add CPU and egress through the NAT gateway. Scale down or tear down resources when not actively demoing.

---

## Cleanup instructions

There is no automated teardown script. Delete resources in **reverse dependency order** to avoid orphaned charges:

1. Set both ASGs (`ollama-chat-flask-asg`, `ollama-chat-react-asg`) desired capacity to **0**; wait for instances to terminate.
2. Delete Auto Scaling groups, then launch templates (`ollama-chat-flask-lt`, `ollama-chat-react-lt`).
3. Delete ALB listener rules, listener, target groups, then the ALB (`ollama-chat-alb`).
4. Delete the NAT gateway; release the Elastic IP.
5. Detach and delete the Internet Gateway; delete subnets, route tables, and the VPC (`ollama-chat-vpc`).
6. Delete security groups (`ollama-chat-alb-sg`, `ollama-chat-react-sg`, `ollama-chat-flask-sg`).
7. Remove IAM instance profiles and roles — Terraform: `ollama-chat-flask-ec2-role`, `ollama-chat-react-ec2-role` (and profiles); legacy bash: `ollama-chat-ec2-ssm-role`. Delete SSM parameters `/ollama-chat/ghcr-pat` and `/ollama-chat/api-key` (if created).
8. Optionally delete GHCR images and local `.aws-deploy-state`.

Console navigation hints: [docs/DEPLOYMENT.md#teardown](docs/DEPLOYMENT.md#teardown).

---

## Steps to move to another AWS account

Use this when copying the project from a school/lab account to a **personal** account (or any new account). AWS does **not** let you transfer a VPC, ALB, or EC2 stack across accounts—you **redeploy** in the new account and **tear down** the old one when finished.

### What moves vs. what you recreate

| Moves with git / GitHub | Recreated in the new account |
|-------------------------|------------------------------|
| Application code, Dockerfiles, Terraform, scripts | VPC, subnets, IGW, NAT, NACLs |
| Documentation and runbooks | ALB, target groups, listeners |
| Your screenshots and notes (local) | Auto Scaling groups, launch templates, EC2 instances |
| Fork/clone of this repository | IAM roles, instance profiles, security groups |
| | SSM Parameter Store secrets |
| | GHCR images under your GitHub user/org |
| | New ALB DNS name (update frontend build) |

SSM SecureStrings and IAM roles **cannot** be exported to another account. Create a new GitHub PAT and store it again in the new account.

### Configuration checklist (do not forget)

Set these **before** the first deploy in the personal account. Never commit secrets to git.

| Item | Where to set | Example / notes |
|------|----------------|-----------------|
| **AWS account** | `aws sts get-caller-identity` | Confirm you are in the **personal** account ID |
| **AWS region** | `AWS_REGION`, `terraform.tfvars`, provider | `us-east-1` (must match everywhere) |
| **AWS CLI profile** | `AWS_PROFILE` or SSO login | `personal` — or use `eval "$(aws configure export-credentials ...)"` for Terraform |
| **GitHub username (GHCR)** | `GHCR_USERNAME`, Terraform `ghcr_username` | Your personal GitHub login or org |
| **Backend image** | `infrastructure/push-backend.sh`, Terraform `backend_image` | `ghcr.io/<you>/ollama-chat-backend:latest` |
| **Frontend image** | `push-frontend.sh`, Terraform `frontend_image` | `ghcr.io/<you>/ollama-chat-frontend:latest` |
| **GitHub PAT** | `GHCR_PAT`, `TF_VAR_ghcr_pat` | Scopes: `read:packages`, `write:packages` |
| **ALB DNS (after deploy)** | `ALB_DNS` for `push-frontend.sh` | Hostname only, no `http://` — e.g. `ollama-chat-alb-123.us-east-1.elb.amazonaws.com` |
| **Vite API URL** | Baked at frontend **build** time | `VITE_API_URL=http://<ALB_DNS>` (set automatically by `push-frontend.sh`) |
| **Optional API key** | `TF_VAR_api_key` | Random string → SSM `/ollama-chat/api-key` |
| **Terraform vars** | `infrastructure/terraform/environments/dev/terraform.tfvars` | Copy from `terraform.tfvars.example`; gitignored |
| **Project prefix** | `project_name` in tfvars | Default `ollama-chat` (resource names below assume this) |

**Files to update if you change GitHub org or image names:**

- [infrastructure/push-backend.sh](infrastructure/push-backend.sh) — `GHCR_USERNAME`
- [infrastructure/push-frontend.sh](infrastructure/push-frontend.sh) — `GHCR_USERNAME`, requires `ALB_DNS`
- [infrastructure/terraform/environments/dev/variables.tf](infrastructure/terraform/environments/dev/variables.tf) — defaults for `ghcr_username`, `backend_image`, `frontend_image`
- [.github/workflows/build-and-push.yml](.github/workflows/build-and-push.yml) — if using GitHub Actions to push images

### IAM permissions needed (new account)

The deploying principal (user or role) needs permission to create and manage at least:

| Service | Typical actions | Resources created by this project |
|---------|-----------------|-----------------------------------|
| **EC2 / VPC** | Create/describe/delete VPC, subnets, IGW, NAT, routes, NACLs, security groups, launch templates, instances | `ollama-chat-vpc`, public/private subnets, `ollama-chat-*-sg` |
| **ELB v2** | Create ALB, target groups, listeners, rules | `ollama-chat-alb`, `ollama-chat-flask-tg`, `ollama-chat-react-tg` |
| **Auto Scaling** | Create/update ASG, instance refresh | `ollama-chat-flask-asg`, `ollama-chat-react-asg` |
| **IAM** | Create roles, instance profiles, attach policies | `ollama-chat-flask-ec2-role`, `ollama-chat-react-ec2-role`, profiles (Terraform) or `ollama-chat-ec2-ssm-role` (bash) |
| **SSM** | `PutParameter`, `GetParameter` | `/ollama-chat/ghcr-pat`, optional `/ollama-chat/api-key` |
| **CloudWatch** | Log groups, alarms (if observability enabled) | `/ollama-chat/flask/*`, `/ollama-chat/react/*` |

For labs, `AdministratorAccess` is simplest. For least privilege, scope to the services above in one region.

### Deploy in the new account (greenfield — recommended)

Do **not** import an old account’s resources. Run a fresh apply in the personal account.

```bash
# 1 — Confirm account and region
export AWS_REGION=us-east-1
unset AWS_PROFILE   # or: export AWS_PROFILE=personal
aws sts get-caller-identity

# 2 — Clone or fork the repo
git clone https://github.com/<your-user>/ollama-chat.git
cd ollama-chat

# 3 — Terraform variables (secrets via env, not committed)
cd infrastructure/terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: aws_region, ghcr_username, flask_health_check_path if needed

export TF_VAR_ghcr_pat='ghp_xxxxxxxx'   # personal GitHub PAT

# If Terraform cannot read ~/.aws credentials (SSO), export session creds:
# eval "$(aws configure export-credentials --profile personal --format env)"

terraform init
terraform plan
terraform apply

# 4 — Note outputs for later steps
export ALB_DNS=$(terraform output -raw alb_dns_name)
terraform output -json | jq '{alb_dns_name, vpc_id, alb_url, api_ready_url}'

# 5 — Push container images to YOUR GHCR
cd ../../../..   # repo root
export GHCR_PAT="$TF_VAR_ghcr_pat"
export GHCR_USERNAME=<your-github-user>
./infrastructure/push-backend.sh
./infrastructure/push-frontend.sh   # uses ALB_DNS for VITE_API_URL

# 6 — Roll out new images (if instances already exist from apply)
export ALB_DNS=$(terraform -chdir=infrastructure/terraform/environments/dev output -raw alb_dns_name)
./infrastructure/update-phase4.sh
# Or: EC2 → Auto Scaling Groups → Instance refresh (both ASGs)

# 7 — Verify
export ALB_DNS=$(terraform -chdir=infrastructure/terraform/environments/dev output -raw alb_dns_name)
./infrastructure/scripts/verify-deployment.sh
```

Alternative without Terraform: [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) Path B (`deploy-aws.sh`) or Console — same resource **names**, new resource IDs.

### AWS resources to verify (new account)

After deploy, confirm these exist (replace region if needed):

```bash
export AWS_REGION=us-east-1

# Identity
aws sts get-caller-identity

# Network
aws ec2 describe-vpcs --filters Name=tag:Name,Values=ollama-chat-vpc \
  --query 'Vpcs[*].[VpcId,CidrBlock]' --output table

aws ec2 describe-nat-gateways --filter Name=state,Values=available \
  --query 'NatGateways[?VpcId!=`null`].[NatGatewayId,State]' --output table

# Load balancer
aws elbv2 describe-load-balancers --names ollama-chat-alb \
  --query 'LoadBalancers[*].[LoadBalancerName,DNSName,State.Code]' --output table

# Target health (expect "healthy" on all targets after ~10 min)
for tg in ollama-chat-flask-tg ollama-chat-react-tg; do
  arn=$(aws elbv2 describe-target-groups --names "$tg" --query 'TargetGroups[0].TargetGroupArn' --output text)
  echo "=== $tg ==="
  aws elbv2 describe-target-health --target-group-arn "$arn" \
    --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' --output table
done

# Auto Scaling
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names ollama-chat-flask-asg ollama-chat-react-asg \
  --query 'AutoScalingGroups[*].[AutoScalingGroupName,MinSize,DesiredCapacity,MaxSize]' --output table

# Secrets (name only — do not print values)
aws ssm describe-parameters --parameter-filters Key=Name,Option=BeginsWith,Values=/ollama-chat \
  --query 'Parameters[*].[Name,Type]' --output table
```

Save for your records:

```bash
terraform -chdir=infrastructure/terraform/environments/dev output -raw alb_dns_name
terraform -chdir=infrastructure/terraform/environments/dev output -raw vpc_id
```

Update [docs/SUBMISSION.md](docs/SUBMISSION.md) deployment evidence table and [docs/SCREENSHOTS.md](docs/SCREENSHOTS.md).

### Tear down the **old** account (avoid double billing)

Run only after the new stack works. Order matters — see [Cleanup instructions](#cleanup-instructions) above.

```bash
export AWS_REGION=us-east-1   # old account credentials/profile

# Scale ASGs to zero
aws autoscaling update-auto-scaling-group --auto-scaling-group-name ollama-chat-flask-asg \
  --min-size 0 --max-size 0 --desired-capacity 0
aws autoscaling update-auto-scaling-group --auto-scaling-group-name ollama-chat-react-asg \
  --min-size 0 --max-size 0 --desired-capacity 0

# Wait until no instances, then delete via Console or:
# - aws autoscaling delete-auto-scaling-group --auto-scaling-group-name <name> --force-delete
# - aws elbv2 delete-load-balancer --load-balancer-arn <arn>
# - aws ec2 delete-nat-gateway --nat-gateway-id <id>
# - aws ec2 release-address --allocation-id <eip>
# - aws ec2 delete-vpc --vpc-id <id>

aws ssm delete-parameter --name /ollama-chat/ghcr-pat 2>/dev/null || true
aws ssm delete-parameter --name /ollama-chat/api-key 2>/dev/null || true

rm -f infrastructure/.aws-deploy-state
```

Full Console/CLI teardown table: [docs/DEPLOYMENT.md#teardown](docs/DEPLOYMENT.md#teardown).

### Optional: remote Terraform state (personal account)

For repeat deploys, configure S3 backend after [infrastructure/terraform/bootstrap/README.md](infrastructure/terraform/bootstrap/README.md):

- S3 bucket: `ollama-chat-terraform-state-<ACCOUNT_ID>`
- DynamoDB table: `ollama-chat-terraform-locks`
- Uncomment `backend "s3"` in [infrastructure/terraform/environments/dev/backend.tf](infrastructure/terraform/environments/dev/backend.tf)

---

## Security notes

See **[SECURITY.md](SECURITY.md)** for the threat model, hardening checklist, secrets handling, and deploy-path comparison.

| Control | Implementation |
|---------|----------------|
| Ollama isolation | `127.0.0.1:11434`; no SG rule; private NACL **deny** on 11434 |
| App tier network | Private subnets; Flask :5000 and React :80 **only** from ALB security group |
| Private NACLs | Allow 80/5000 from public subnet CIDRs; ephemeral within VPC; deny 11434 |
| Registry credentials | SSM `/ollama-chat/ghcr-pat`; tier-scoped `ssm:GetParameter` (Terraform split roles) |
| API protection | Optional `/ollama-chat/api-key` via `TF_VAR_api_key`; `X-API-Key` with `compare_digest` |
| Flask hardening | CSP/HSTS (behind HTTPS), production CORS validation, rate limits, optional `REQUIRE_API_KEY_IN_PRODUCTION` |
| EC2 metadata | IMDSv2 required on launch templates |
| User-data | Idempotent; secrets from SSM only; Docker `--cap-drop=ALL` |
| Management | SSM Session Manager; optional React→Flask SSH (`enable_ssh_between_tiers` default **true**) |

**Remaining gaps:** HTTP-only ALB (no TLS/WAF by default), in-memory rate limits at scale. Legacy `deploy-aws.sh` still uses a single shared EC2 IAM role.

Details: [docs/ARCHITECTURE.md#security-controls](docs/ARCHITECTURE.md#security-controls).

---

## Documentation

| Document | Description |
|----------|-------------|
| [backend/README.md](backend/README.md) | API structure, configuration, tests, Docker |
| [frontend/README.md](frontend/README.md) | Chat UI, env vars, Docker (unprivileged nginx) |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | VPC topology, components, network flows, scalability |
| [infrastructure/terraform/README.md](infrastructure/terraform/README.md) | Terraform IaC (recommended deploy path) |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | CLI, Console, and Terraform deployment runbooks |
| [SECURITY.md](SECURITY.md) | Threat model, secrets, hardening checklist |
| [docs/SUBMISSION.md](docs/SUBMISSION.md) | Code Platoon / portfolio submission (requirement → evidence) |
| [docs/SCREENSHOTS.md](docs/SCREENSHOTS.md) | Screenshot capture guide |
| [docs/OPERATIONS.md](docs/OPERATIONS.md) | Logs, metrics, alarms, incident response |
| [docs/SECRETS.md](docs/SECRETS.md) | Secrets and env var reference |
| [README — Steps to move](#steps-to-move-to-another-aws-account) | Migrate to a personal AWS account (checklist + CLI) |
| [CHANGELOG.md](CHANGELOG.md) | Release history |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Contributing guidelines |

---

## License

MIT License — see [LICENSE](LICENSE). Intended for educational and portfolio use.
