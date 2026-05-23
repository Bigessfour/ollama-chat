#!/usr/bin/env bash
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

FLASK_UD_B64=$(base64 < "$ROOT/infrastructure/user-data/flask.sh" | tr -d '\n')
REACT_UD_B64=$(base64 < "$ROOT/infrastructure/user-data/react.sh" | tr -d '\n')

FLASK_LT_DATA=$(aws ec2 describe-launch-template-versions \
  --launch-template-name "$FLASK_LT" --versions '$Latest' \
  --query 'LaunchTemplateVersions[0].LaunchTemplateData' --output json)

REACT_LT_DATA=$(aws ec2 describe-launch-template-versions \
  --launch-template-name "$REACT_LT" --versions '$Latest' \
  --query 'LaunchTemplateVersions[0].LaunchTemplateData' --output json)

cat > /tmp/flask-lt-phase4.json <<EOF
$(echo "$FLASK_LT_DATA" | jq --arg ud "$FLASK_UD_B64" '.UserData = $ud')
EOF

cat > /tmp/react-lt-phase4.json <<EOF
$(echo "$REACT_LT_DATA" | jq --arg ud "$REACT_UD_B64" '.UserData = $ud')
EOF

echo "==> Creating new launch template versions"
aws ec2 create-launch-template-version \
  --launch-template-name "$FLASK_LT" \
  --source-version '$Latest' \
  --launch-template-data file:///tmp/flask-lt-phase4.json \
  --query 'LaunchTemplateVersion.VersionNumber' --output text

aws ec2 create-launch-template-version \
  --launch-template-name "$REACT_LT" \
  --source-version '$Latest' \
  --launch-template-data file:///tmp/react-lt-phase4.json \
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
if [[ -n "${ALB_DNS:-}" ]]; then
  echo "ALB DNS: http://$ALB_DNS"
  echo "Health:  http://$ALB_DNS/api/health"
fi
echo ""
echo "Monitor: aws autoscaling describe-instance-refreshes --auto-scaling-group-name $FLASK_ASG --region $REGION"
