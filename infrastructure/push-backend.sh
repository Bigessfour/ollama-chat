#!/usr/bin/env bash
# Requires GHCR_PAT in the environment — never pass PAT as a build-arg. See SECURITY.md.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GHCR_USERNAME="${GHCR_USERNAME:-bigessfour}"
cd "$ROOT"

if [[ -z "${GHCR_PAT:-}" ]]; then
  echo "Error: export GHCR_PAT (GitHub PAT with write:packages scope)" >&2
  exit 1
fi

echo "$GHCR_PAT" | docker login ghcr.io -u "$GHCR_USERNAME" --password-stdin
docker buildx inspect multiarch >/dev/null 2>&1 && docker buildx use multiarch || docker buildx create --use --name multiarch

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t "ghcr.io/${GHCR_USERNAME}/ollama-chat-backend:latest" \
  --push ./backend

docker buildx imagetools inspect ghcr.io/bigessfour/ollama-chat-backend:latest
