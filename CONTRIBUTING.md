# Contributing

Thank you for your interest in Ollama Chat. This project is primarily maintained for learning, Code Platoon submission, and portfolio use.

## Getting started

1. Clone the repository and work from the `ollama-chat/` root (or repo root if that is your clone layout).
2. Follow [README.md](README.md) for local development (Ollama, backend, frontend).
3. Read [docs/SECRETS.md](docs/SECRETS.md) before setting any credentials.

## Running tests

**Backend:**

```bash
cd backend
python3.11 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
pytest
```

**Frontend:**

```bash
cd frontend
npm install
npm run lint
npm run build
```

CI runs the same checks via [.github/workflows/ci.yml](.github/workflows/ci.yml).

## Pull requests

- Keep changes focused; match existing style in the touched package.
- Update [CHANGELOG.md](CHANGELOG.md) under `[Unreleased]` for user-visible changes.
- Do not commit secrets, `.env` files, `terraform.tfvars`, or screenshots with live credentials.
- Add or update tests when changing API or health-check behavior.

## Security

- **Never** open a PR that includes PATs, API keys, or AWS access keys.
- Report vulnerabilities privately via GitHub Issues without pasting live secrets. See [SECURITY.md](SECURITY.md).

## Documentation

- Architecture and deploy: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)
- Submission evidence: [docs/SUBMISSION.md](docs/SUBMISSION.md)
