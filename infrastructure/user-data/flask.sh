#!/bin/bash
set -e

dnf update -y || yum update -y
dnf install -y docker aws-cli
systemctl enable --now docker
usermod -aG docker ec2-user

curl -fsSL https://ollama.com/install.sh | sh
systemctl enable --now ollama || true

nohup bash -c 'export HOME=/root; sleep 15; ollama pull gemma:2b' \
  > /var/log/ollama-pull.log 2>&1 &

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/region)

PAT=$(aws ssm get-parameter --name /ollama-chat/ghcr-pat --with-decryption \
  --region "$REGION" --query Parameter.Value --output text)
echo "$PAT" | docker login ghcr.io -u Bigessfour --password-stdin

docker pull ghcr.io/bigessfour/ollama-chat-backend:latest
docker run -d --restart unless-stopped --network host \
  --name backend \
  -e OLLAMA_URL=http://localhost:11434 \
  ghcr.io/bigessfour/ollama-chat-backend:latest

echo "Flask + Ollama startup complete" > /var/log/user-data.log
