#!/usr/bin/env bash
# Rolling LT update — user-data is templated; ALB_DNS required for Flask CORS.
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$REGION"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE_FILE="$ROOT/infrastructure/.aws-deploy-state"

if [[ -f "$STATE_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$STATE_FILE"
fi

FLASK_LT=ollama-chat-flask-lt
REACT_LT=ollama-chat-react-lt
FLASK_ASG=ollama-chat-flask-asg
REACT_ASG=ollama-chat-react-asg

echo "==> Phase 4 update in $REGION"

if [[ -z "${ALB_DNS:-}" ]]; then
  echo "Error: ALB_DNS is required for Flask CORS. Source $STATE_FILE or export ALB_DNS." >&2
  exit 1
fi

GHCR_USERNAME="${GHCR_USERNAME:-bigessfour}"
export ghcr_username="$GHCR_USERNAME"
export cors_origins="http://${ALB_DNS}"
export backend_image="ghcr.io/${GHCR_USERNAME}/ollama-chat-backend:latest"
export frontend_image="ghcr.io/${GHCR_USERNAME}/ollama-chat-frontend:latest"

FLASK_UD_B64=$(envsubst '${ghcr_username} ${cors_origins} ${backend_image}' \
  < "$ROOT/infrastructure/user-data/flask.sh" | base64 | tr -d '\n')
REACT_UD_B64=$(envsubst '${ghcr_username} ${frontend_image}' \
  < "$ROOT/infrastructure/user-data/react.sh" | base64 | tr -d '\n')

FLASK_LT_DATA=$(aws ec2 describe-launch-template-versions \
  --launch-template-name "$FLASK_LT" --versions '$Latest' \
  --query 'LaunchTemplateVersions[0].LaunchTemplateData' --output json)

REACT_LT_DATA=$(aws ec2 describe-launch-template-versions \
  --launch-template-name "$REACT_LT" --versions '$Latest' \
  --query 'LaunchTemplateVersions[0].LaunchTemplateData' --output json)

FLASK_LT_JSON=$(mktemp)
REACT_LT_JSON=$(mktemp)
chmod 600 "$FLASK_LT_JSON" "$REACT_LT_JSON"
trap 'rm -f "$FLASK_LT_JSON" "$REACT_LT_JSON"' EXIT

echo "$FLASK_LT_DATA" | jq --arg ud "$FLASK_UD_B64" '.UserData = $ud' > "$FLASK_LT_JSON"
echo "$REACT_LT_DATA" | jq --arg ud "$REACT_UD_B64" '.UserData = $ud' > "$REACT_LT_JSON"

echo "==> Creating new launch template versions"
aws ec2 create-launch-template-version \
  --launch-template-name "$FLASK_LT" \
  --source-version '$Latest' \
  --launch-template-data file://"$FLASK_LT_JSON" \
  --query 'LaunchTemplateVersion.VersionNumber' --output text

aws ec2 create-launch-template-version \
  --launch-template-name "$REACT_LT" \
  --source-version '$Latest' \
  --launch-template-data file://"$REACT_LT_JSON" \
  --query 'LaunchTemplateVersion.VersionNumber' --output text

FLASK_VER=$(aws ec2 describe-launch-template-versions \
  --launch-template-name "$FLASK_LT" --versions '$Latest' \
  --query 'LaunchTemplateVersions[0].VersionNumber' --output text)
REACT_VER=$(aws ec2 describe-launch-template-versions \
  --launch-template-name "$REACT_LT" --versions '$Latest' \
  --query 'LaunchTemplateVersions[0].VersionNumber' --output text)

aws ec2 modify-launch-template \
  --launch-template-name "$FLASK_LT" \
  --default-version "$FLASK_VER"
aws ec2 modify-launch-template \
  --launch-template-name "$REACT_LT" \
  --default-version "$REACT_VER"

echo "==> Updating Auto Scaling Groups"
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name "$FLASK_ASG" \
  --launch-template "LaunchTemplateName=$FLASK_LT,Version=\$Latest" \
  --min-size 2 --max-size 4 --desired-capacity 2 \
  --health-check-grace-period 600

aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name "$REACT_ASG" \
  --launch-template "LaunchTemplateName=$REACT_LT,Version=\$Latest" \
  --min-size 2 --max-size 4 --desired-capacity 2 \
  --health-check-grace-period 300

echo "==> Starting instance refresh"
FLASK_REFRESH=$(aws autoscaling start-instance-refresh \
  --auto-scaling-group-name "$FLASK_ASG" \
  --preferences '{"MinHealthyPercentage":50,"InstanceWarmup":600}' \
  --query 'InstanceRefreshId' --output text)
REACT_REFRESH=$(aws autoscaling start-instance-refresh \
  --auto-scaling-group-name "$REACT_ASG" \
  --preferences '{"MinHealthyPercentage":50,"InstanceWarmup":300}' \
  --query 'InstanceRefreshId' --output text)

echo ""
echo "=== Phase 4 rollout started ==="
echo "Flask LT version:  $FLASK_VER  | refresh: $FLASK_REFRESH"
echo "React LT version:  $REACT_VER  | refresh: $REACT_REFRESH"
echo "ALB DNS: http://$ALB_DNS"
echo "Ready:   http://$ALB_DNS/api/ready"
echo "Health:  http://$ALB_DNS/api/health"
echo ""
echo "Monitor: aws autoscaling describe-instance-refreshes --auto-scaling-group-name $FLASK_ASG --region $REGION"
