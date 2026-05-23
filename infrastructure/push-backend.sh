#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -z "${GHCR_PAT:-}" ]]; then
  echo "Error: export GHCR_PAT (GitHub PAT with write:packages scope)" >&2
  exit 1
fi

echo "$GHCR_PAT" | docker login ghcr.io -u Bigessfour --password-stdin
docker buildx inspect multiarch >/dev/null 2>&1 && docker buildx use multiarch || docker buildx create --use --name multiarch

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/bigessfour/ollama-chat-backend:latest \
  --push ./backend

docker buildx imagetools inspect ghcr.io/bigessfour/ollama-chat-backend:latest
