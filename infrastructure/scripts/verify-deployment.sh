#!/usr/bin/env bash
# Post-deploy verification for Code Platoon Module 1 submission.
# Usage: export ALB_DNS=your-alb-dns-name && ./infrastructure/scripts/verify-deployment.sh
set -euo pipefail

if [[ -z "${ALB_DNS:-}" ]]; then
  echo "Error: export ALB_DNS (ALB hostname only, no http://)" >&2
  exit 1
fi

BASE="http://${ALB_DNS}"
echo "=== Ollama Chat deployment verification ==="
echo "ALB: $BASE"
echo ""

echo "--- GET /live ---"
curl -sf "${BASE}/live" | head -c 500
echo -e "\n"

echo "--- GET /api/ready ---"
curl -sf "${BASE}/api/ready" | head -c 500
echo -e "\n"

echo "--- POST /api/chat ---"
curl -sf -X POST "${BASE}/api/chat" \
  -H 'Content-Type: application/json' \
  -d '{"message":"hello from verify-deployment.sh"}' | head -c 800
echo -e "\n"

echo "=== All checks passed ==="
