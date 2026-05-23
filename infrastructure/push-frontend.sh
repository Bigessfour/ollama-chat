#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -z "${GHCR_PAT:-}" ]]; then
  echo "Error: export GHCR_PAT (GitHub PAT with write:packages scope)" >&2
  exit 1
fi

if [[ -z "${ALB_DNS:-}" ]]; then
  echo "Error: export ALB_DNS (ALB hostname, no trailing slash)" >&2
  exit 1
fi

echo "$GHCR_PAT" | docker login ghcr.io -u Bigessfour --password-stdin
docker buildx inspect multiarch >/dev/null 2>&1 && docker buildx use multiarch || docker buildx create --use --name multiarch

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg "VITE_API_BASE_URL=http://${ALB_DNS}" \
  -t ghcr.io/bigessfour/ollama-chat-frontend:latest \
  --push ./frontend

docker buildx imagetools inspect ghcr.io/bigessfour/ollama-chat-frontend:latest
