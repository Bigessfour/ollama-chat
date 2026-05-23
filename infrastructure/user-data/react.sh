#!/bin/bash
set -e

dnf install -y docker aws-cli
systemctl enable --now docker

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/region)

PAT=$(aws ssm get-parameter --name /ollama-chat/ghcr-pat --with-decryption \
  --region "$REGION" --query Parameter.Value --output text)
echo "$PAT" | docker login ghcr.io -u Bigessfour --password-stdin

docker pull ghcr.io/bigessfour/ollama-chat-frontend:latest
docker run -d --restart unless-stopped -p 80:80 --name frontend \
  ghcr.io/bigessfour/ollama-chat-frontend:latest
