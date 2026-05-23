#!/bin/bash
# Sourced by user-data scripts — not executed standalone on instances.
# Usage: install_cloudwatch_agent "$TOKEN" "$CONFIG_PATH"
# CONFIG_PATH is a JSON file with __INSTANCE_ID__ placeholders.

install_cloudwatch_agent() {
  local metadata_token="$1"
  local config_template_path="$2"
  local tier_marker="$3"

  local cw_marker="/var/lib/ollama-chat/cw-agent-${tier_marker}"
  if [[ -f "$cw_marker" ]]; then
    systemctl start amazon-cloudwatch-agent 2>/dev/null || true
    return 0
  fi

  log "Installing CloudWatch agent (${tier_marker})"
  dnf install -y amazon-cloudwatch-agent 2>/dev/null \
    || yum install -y amazon-cloudwatch-agent

  local instance_id region cw_conf
  instance_id=$(curl -sf -H "X-aws-ec2-metadata-token: ${metadata_token}" \
    http://169.254.169.254/latest/meta-data/instance-id)
  region=$(curl -sf -H "X-aws-ec2-metadata-token: ${metadata_token}" \
    http://169.254.169.254/latest/meta-data/placement/region)

  cw_conf=/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
  sed "s/__INSTANCE_ID__/${instance_id}/g" "${config_template_path}" > "${cw_conf}"

  /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config -m ec2 -s -c "file:${cw_conf}"
  systemctl enable amazon-cloudwatch-agent
  systemctl start amazon-cloudwatch-agent || true
  touch "${cw_marker}"
  log "CloudWatch agent configured (region=${region}, instance=${instance_id})"
}
