# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2025-05-23

### Added

- Full-stack Ollama chat: Flask API proxy, React SPA (Vite), `gemma:2b` via local Ollama
- Docker multi-arch images and GHCR push scripts (`push-backend.sh`, `push-frontend.sh`)
- AWS deployment: VPC (public/private subnets, NAT), ALB path routing (`/api/*` → Flask), Auto Scaling Groups
- EC2 user-data bootstrap: Ollama on Flask hosts, SSM-backed GHCR PAT, optional API key in SSM
- Terraform IaC (`infrastructure/terraform/`) with split Flask/React IAM roles
- Security: production CORS validation, rate limits, optional `X-API-Key`, CSP headers, IMDSv2, non-root containers
- Enterprise observability: structlog JSON, EMF metrics, `/live` and `/ready` probes, CloudWatch agent, alarms, [OPERATIONS.md](docs/OPERATIONS.md)
- GitHub Actions CI (backend tests, frontend lint/build)
- Documentation: ARCHITECTURE, DEPLOYMENT, SECURITY, submission and portfolio guides

### Changed

- Flask health endpoints: Kubernetes-style `/live`, `/ready`, `/health` plus backward-compatible `/api/*`

### Security

- Secrets externalized to SSM Parameter Store; user-data scripts contain no PATs or API keys
