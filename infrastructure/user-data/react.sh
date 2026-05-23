#!/bin/bash
# React/nginx bootstrap — idempotent, no secrets in this file.
set -euo pipefail
umask 077

MARKER=/var/lib/ollama-chat/react-bootstrapped
CONTAINER_NAME=frontend
GHCR_USERNAME="${ghcr_username}"
FRONTEND_IMAGE="${frontend_image}"
SSM_PAT_PARAM=/ollama-chat/ghcr-pat

log() {
  echo "[$(date -Iseconds)] $*" >> /var/log/ollama-chat-react.log
}

mkdir -p /var/lib/ollama-chat
touch /var/log/ollama-chat-react.log
chmod 600 /var/log/ollama-chat-react.log

install_cloudwatch_agent() {
  local cw_marker=/var/lib/ollama-chat/cw-agent-react
  if [[ -f "$cw_marker" ]]; then
    systemctl start amazon-cloudwatch-agent 2>/dev/null || true
    return 0
  fi
  log "Installing CloudWatch agent"
  dnf install -y amazon-cloudwatch-agent 2>/dev/null \
    || yum install -y amazon-cloudwatch-agent
  local instance_id cw_conf
  instance_id=$(curl -sf -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/instance-id)
  cw_conf=/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
  sed "s/__INSTANCE_ID__/${instance_id}/g" <<'CWCFG' > "$cw_conf"
{
  "agent": {"metrics_collection_interval": 60, "run_as_user": "root"},
  "logs": {"logs_collected": {"files": {"collect_list": [
    {"file_path": "/var/log/ollama-chat-react.log", "log_group_name": "/ollama-chat/react/bootstrap", "log_stream_name": "__INSTANCE_ID__/bootstrap", "timezone": "UTC"},
    {"file_path": "/var/lib/docker/containers/*/*-json.log", "log_group_name": "/ollama-chat/react/app", "log_stream_name": "__INSTANCE_ID__/docker", "timezone": "UTC"}
  ]}}},
  "metrics": {"namespace": "OllamaChat/EC2", "append_dimensions": {"InstanceId": "__INSTANCE_ID__"},
    "metrics_collected": {
      "cpu": {"measurement": ["cpu_usage_idle", "cpu_usage_iowait", "cpu_usage_user", "cpu_usage_system"], "metrics_collection_interval": 60, "totalcpu": false},
      "disk": {"measurement": ["used_percent"], "metrics_collection_interval": 60, "resources": ["*"]},
      "mem": {"measurement": ["mem_used_percent"], "metrics_collection_interval": 60}
    }
  }
}
CWCFG
  sed -i "s/__INSTANCE_ID__/${instance_id}/g" "$cw_conf"
  /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config -m ec2 -s -c "file:${cw_conf}"
  systemctl enable amazon-cloudwatch-agent
  systemctl start amazon-cloudwatch-agent || true
  touch "$cw_marker"
}

if [[ -f "$MARKER" ]]; then
  log "Marker present — starting existing container"
  docker start "$CONTAINER_NAME" 2>/dev/null || true
  TOKEN=$(curl -sf -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null || true)
  [[ -n "${TOKEN:-}" ]] && install_cloudwatch_agent || true
  exit 0
fi

log "First boot — installing dependencies"
dnf install -y docker aws-cli
systemctl enable --now docker

TOKEN=$(curl -sf -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
install_cloudwatch_agent

REGION=$(curl -sf -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/region)

set +x
PAT=$(aws ssm get-parameter --name "$SSM_PAT_PARAM" --with-decryption \
  --region "$REGION" --query Parameter.Value --output text)
echo "$PAT" | docker login ghcr.io -u "$GHCR_USERNAME" --password-stdin
unset PAT

docker pull "$FRONTEND_IMAGE"
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
docker run -d --restart unless-stopped \
  -p 80:8080 \
  --name "$CONTAINER_NAME" \
  --security-opt=no-new-privileges:true \
  --cap-drop=ALL \
  "$FRONTEND_IMAGE"

touch "$MARKER"
log "React startup complete"
