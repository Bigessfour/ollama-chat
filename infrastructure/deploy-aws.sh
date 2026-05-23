#!/usr/bin/env bash
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$REGION"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

if [[ -z "${GHCR_PAT:-}" ]]; then
  echo "Warning: GHCR_PAT not set. SSM parameter will use placeholder; update before instances boot." >&2
  GHCR_PAT="REPLACE_WITH_GITHUB_PAT_read_packages"
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE_FILE="$ROOT/infrastructure/.aws-deploy-state"
mkdir -p "$ROOT/infrastructure/user-data"

echo "==> Deploying ollama-chat AWS infrastructure in $REGION"

# --- VPC ---
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query 'Vpc.VpcId' --output text)
aws ec2 create-tags --resources "$VPC_ID" --tags Key=Name,Value=ollama-chat-vpc
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-support

IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 create-tags --resources "$IGW_ID" --tags Key=Name,Value=ollama-chat-igw
aws ec2 attach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"

PUBLIC_1A=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.1.0/24 \
  --availability-zone "${REGION}a" --query 'Subnet.SubnetId' --output text)
PUBLIC_1B=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.2.0/24 \
  --availability-zone "${REGION}b" --query 'Subnet.SubnetId' --output text)
PRIVATE_1A=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.10.0/24 \
  --availability-zone "${REGION}a" --query 'Subnet.SubnetId' --output text)
PRIVATE_1B=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.11.0/24 \
  --availability-zone "${REGION}b" --query 'Subnet.SubnetId' --output text)

for id in "$PUBLIC_1A" "$PUBLIC_1B"; do
  aws ec2 modify-subnet-attribute --subnet-id "$id" --map-public-ip-on-launch
  aws ec2 create-tags --resources "$id" --tags Key=Name,Value=ollama-chat-public
done
for id in "$PRIVATE_1A" "$PRIVATE_1B"; do
  aws ec2 create-tags --resources "$id" --tags Key=Name,Value=ollama-chat-private
done

PUBLIC_RT=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-tags --resources "$PUBLIC_RT" --tags Key=Name,Value=ollama-chat-public-rt
aws ec2 create-route --route-table-id "$PUBLIC_RT" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID"
aws ec2 associate-route-table --route-table-id "$PUBLIC_RT" --subnet-id "$PUBLIC_1A"
aws ec2 associate-route-table --route-table-id "$PUBLIC_RT" --subnet-id "$PUBLIC_1B"

EIP_ALLOC=$(aws ec2 allocate-address --domain vpc --query AllocationId --output text)
NAT_GW=$(aws ec2 create-nat-gateway --subnet-id "$PUBLIC_1A" --allocation-id "$EIP_ALLOC" \
  --query 'NatGateway.NatGatewayId' --output text)
aws ec2 create-tags --resources "$NAT_GW" --tags Key=Name,Value=ollama-chat-nat
aws ec2 wait nat-gateway-available --nat-gateway-ids "$NAT_GW"

PRIVATE_RT=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-tags --resources "$PRIVATE_RT" --tags Key=Name,Value=ollama-chat-private-rt
aws ec2 create-route --route-table-id "$PRIVATE_RT" --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NAT_GW"
aws ec2 associate-route-table --route-table-id "$PRIVATE_RT" --subnet-id "$PRIVATE_1A"
aws ec2 associate-route-table --route-table-id "$PRIVATE_RT" --subnet-id "$PRIVATE_1B"

# --- Security Groups ---
ALB_SG=$(aws ec2 create-security-group --group-name ollama-chat-alb-sg \
  --description "ALB for ollama-chat" --vpc-id "$VPC_ID" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$ALB_SG" --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$ALB_SG" --protocol tcp --port 443 --cidr 0.0.0.0/0

REACT_SG=$(aws ec2 create-security-group --group-name ollama-chat-react-sg \
  --description "React nginx for ollama-chat" --vpc-id "$VPC_ID" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$REACT_SG" --protocol tcp --port 80 --source-group "$ALB_SG"

FLASK_SG=$(aws ec2 create-security-group --group-name ollama-chat-flask-sg \
  --description "Flask backend for ollama-chat" --vpc-id "$VPC_ID" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$FLASK_SG" --protocol tcp --port 5000 --source-group "$ALB_SG"
aws ec2 authorize-security-group-ingress --group-id "$FLASK_SG" --protocol tcp --port 22 --source-group "$REACT_SG"

# --- IAM ---
ROLE_NAME=ollama-chat-ec2-ssm-role
TRUST_POLICY='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
aws iam create-role --role-name "$ROLE_NAME" --assume-role-policy-document "$TRUST_POLICY" 2>/dev/null || true
aws iam attach-role-policy --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore 2>/dev/null || true

SSM_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["ssm:GetParameter", "ssm:GetParameters"],
    "Resource": "arn:aws:ssm:${REGION}:${ACCOUNT_ID}:parameter/ollama-chat/ghcr-pat"
  }]
}
EOF
)
aws iam put-role-policy --role-name "$ROLE_NAME" --policy-name ghcr-pat-read --policy-document "$SSM_POLICY" 2>/dev/null || true
aws iam create-instance-profile --instance-profile-name "$ROLE_NAME" 2>/dev/null || true
aws iam add-role-to-instance-profile --instance-profile-name "$ROLE_NAME" --role-name "$ROLE_NAME" 2>/dev/null || true
sleep 10

aws ssm put-parameter --name /ollama-chat/ghcr-pat --type SecureString \
  --value "$GHCR_PAT" --overwrite 2>/dev/null || \
aws ssm put-parameter --name /ollama-chat/ghcr-pat --type SecureString --value "$GHCR_PAT"

# --- ALB Target Groups ---
FLASK_TG=$(aws elbv2 create-target-group --name ollama-chat-flask-tg --protocol HTTP --port 5000 \
  --vpc-id "$VPC_ID" --health-check-path /api/health --matcher HttpCode=200 \
  --query 'TargetGroups[0].TargetGroupArn' --output text)
REACT_TG=$(aws elbv2 create-target-group --name ollama-chat-react-tg --protocol HTTP --port 80 \
  --vpc-id "$VPC_ID" --health-check-path / --matcher HttpCode=200 \
  --query 'TargetGroups[0].TargetGroupArn' --output text)

ALB_ARN=$(aws elbv2 create-load-balancer --name ollama-chat-alb --type application \
  --scheme internet-facing --subnets "$PUBLIC_1A" "$PUBLIC_1B" --security-groups "$ALB_SG" \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)
ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" \
  --query 'LoadBalancers[0].DNSName' --output text)

LISTENER_ARN=$(aws elbv2 create-listener --load-balancer-arn "$ALB_ARN" --protocol HTTP --port 80 \
  --default-actions Type=forward,TargetGroupArn="$REACT_TG" \
  --query 'Listeners[0].ListenerArn' --output text)

aws elbv2 create-rule --listener-arn "$LISTENER_ARN" --priority 1 \
  --conditions Field=path-pattern,Values='/api/*' \
  --actions Type=forward,TargetGroupArn="$FLASK_TG"

# --- Launch Templates ---
AMI_ID=$(aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query 'Parameters[0].Value' --output text)

FLASK_UD_B64=$(base64 < "$ROOT/infrastructure/user-data/flask.sh" | tr -d '\n')
REACT_UD_B64=$(base64 < "$ROOT/infrastructure/user-data/react.sh" | tr -d '\n')

cat > /tmp/flask-lt.json <<EOF
{
  "ImageId": "$AMI_ID",
  "InstanceType": "t3.large",
  "IamInstanceProfile": {"Name": "$ROLE_NAME"},
  "SecurityGroupIds": ["$FLASK_SG"],
  "UserData": "$FLASK_UD_B64"
}
EOF

cat > /tmp/react-lt.json <<EOF
{
  "ImageId": "$AMI_ID",
  "InstanceType": "t3.small",
  "IamInstanceProfile": {"Name": "$ROLE_NAME"},
  "SecurityGroupIds": ["$REACT_SG"],
  "UserData": "$REACT_UD_B64"
}
EOF

aws ec2 create-launch-template --launch-template-name ollama-chat-flask-lt \
  --launch-template-data file:///tmp/flask-lt.json \
  --query 'LaunchTemplate.LaunchTemplateId' --output text

aws ec2 create-launch-template --launch-template-name ollama-chat-react-lt \
  --launch-template-data file:///tmp/react-lt.json \
  --query 'LaunchTemplate.LaunchTemplateId' --output text

# --- Auto Scaling Groups ---
aws autoscaling create-auto-scaling-group --auto-scaling-group-name ollama-chat-flask-asg \
  --launch-template LaunchTemplateName=ollama-chat-flask-lt,Version='$Latest' \
  --min-size 2 --max-size 4 --desired-capacity 2 \
  --vpc-zone-identifier "$PRIVATE_1A,$PRIVATE_1B" \
  --target-group-arns "$FLASK_TG" \
  --health-check-type ELB --health-check-grace-period 600

aws autoscaling create-auto-scaling-group --auto-scaling-group-name ollama-chat-react-asg \
  --launch-template LaunchTemplateName=ollama-chat-react-lt,Version='$Latest' \
  --min-size 2 --max-size 4 --desired-capacity 2 \
  --vpc-zone-identifier "$PRIVATE_1A,$PRIVATE_1B" \
  --target-group-arns "$REACT_TG" \
  --health-check-type ELB --health-check-grace-period 300

cat > "$STATE_FILE" <<EOF
REGION=$REGION
VPC_ID=$VPC_ID
ALB_DNS=$ALB_DNS
ALB_ARN=$ALB_ARN
FLASK_TG=$FLASK_TG
REACT_TG=$REACT_TG
EOF

echo ""
echo "=== Deployment complete ==="
echo "ALB DNS: http://$ALB_DNS"
echo "Health:  http://$ALB_DNS/api/health"
echo ""
echo "Next: export GHCR_PAT=... ALB_DNS=$ALB_DNS && ./infrastructure/push-frontend.sh"
echo "State saved to $STATE_FILE"
