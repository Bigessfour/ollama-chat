#!/usr/bin/env bash
# Legacy one-shot deploy (NOT idempotent). Prefer Terraform: infrastructure/terraform/README.md
# WARNING: This script does NOT create private-subnet NACLs. Use Terraform for defense-in-depth.
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$REGION"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

if [[ -z "${GHCR_PAT:-}" ]]; then
  echo "Error: export GHCR_PAT (GitHub PAT with read:packages) before running deploy-aws.sh" >&2
  echo "See SECURITY.md for secrets handling." >&2
  exit 1
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

# --- Private subnet NACL (mirrors Terraform; Flask not reachable except via ALB paths) ---
PRIVATE_NACL=$(aws ec2 create-network-acl --vpc-id "$VPC_ID" \
  --query 'NetworkAcl.NetworkAclId' --output text)
aws ec2 create-tags --resources "$PRIVATE_NACL" --tags Key=Name,Value=ollama-chat-private-nacl

aws ec2 create-network-acl-entry --network-acl-id "$PRIVATE_NACL" --rule-number 50 \
  --protocol tcp --port-range From=11434,To=11434 --cidr-block 0.0.0.0/0 --ingress --rule-action deny
aws ec2 create-network-acl-entry --network-acl-id "$PRIVATE_NACL" --rule-number 100 \
  --protocol tcp --port-range From=80,To=80 --cidr-block 10.0.1.0/24 --ingress --rule-action allow
aws ec2 create-network-acl-entry --network-acl-id "$PRIVATE_NACL" --rule-number 101 \
  --protocol tcp --port-range From=80,To=80 --cidr-block 10.0.2.0/24 --ingress --rule-action allow
aws ec2 create-network-acl-entry --network-acl-id "$PRIVATE_NACL" --rule-number 102 \
  --protocol tcp --port-range From=5000,To=5000 --cidr-block 10.0.1.0/24 --ingress --rule-action allow
aws ec2 create-network-acl-entry --network-acl-id "$PRIVATE_NACL" --rule-number 103 \
  --protocol tcp --port-range From=5000,To=5000 --cidr-block 10.0.2.0/24 --ingress --rule-action allow
# SSH from private subnets (React tier → Flask tier debugging)
aws ec2 create-network-acl-entry --network-acl-id "$PRIVATE_NACL" --rule-number 104 \
  --protocol tcp --port-range From=22,To=22 --cidr-block 10.0.10.0/24 --ingress --rule-action allow
aws ec2 create-network-acl-entry --network-acl-id "$PRIVATE_NACL" --rule-number 105 \
  --protocol tcp --port-range From=22,To=22 --cidr-block 10.0.11.0/24 --ingress --rule-action allow
aws ec2 create-network-acl-entry --network-acl-id "$PRIVATE_NACL" --rule-number 110 \
  --protocol tcp --port-range From=1024,To=65535 --cidr-block 10.0.0.0/16 --ingress --rule-action allow
aws ec2 create-network-acl-entry --network-acl-id "$PRIVATE_NACL" --rule-number 100 \
  --protocol -1 --cidr-block 0.0.0.0/0 --egress --rule-action allow

for SUBNET_ID in "$PRIVATE_1A" "$PRIVATE_1B"; do
  ASSOC_ID=$(aws ec2 describe-network-acls --filters "Name=association.subnet-id,Values=$SUBNET_ID" \
    --query 'NetworkAcls[0].Associations[?SubnetId==`'"$SUBNET_ID"'`].NetworkAclAssociationId' \
    --output text)
  aws ec2 replace-network-acl-association --association-id "$ASSOC_ID" \
    --network-acl-id "$PRIVATE_NACL"
done

# --- Security Groups ---
ALB_SG=$(aws ec2 create-security-group --group-name ollama-chat-alb-sg \
  --description "ALB for ollama-chat" --vpc-id "$VPC_ID" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$ALB_SG" --protocol tcp --port 80 --cidr 0.0.0.0/0

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
    "Action": ["ssm:GetParameter"],
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
  --vpc-id "$VPC_ID" --health-check-path /api/ready --matcher HttpCode=200 \
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

GHCR_USERNAME="${GHCR_USERNAME:-bigessfour}"
export ghcr_username="$GHCR_USERNAME"
export cors_origins="http://${ALB_DNS}"
export backend_image="ghcr.io/${GHCR_USERNAME}/ollama-chat-backend:latest"
export frontend_image="ghcr.io/${GHCR_USERNAME}/ollama-chat-frontend:latest"

FLASK_UD_B64=$(envsubst '${ghcr_username} ${cors_origins} ${backend_image}' \
  < "$ROOT/infrastructure/user-data/flask.sh" | base64 | tr -d '\n')
REACT_UD_B64=$(envsubst '${ghcr_username} ${frontend_image}' \
  < "$ROOT/infrastructure/user-data/react.sh" | base64 | tr -d '\n')

FLASK_LT_JSON=$(mktemp)
REACT_LT_JSON=$(mktemp)
chmod 600 "$FLASK_LT_JSON" "$REACT_LT_JSON"
trap 'rm -f "$FLASK_LT_JSON" "$REACT_LT_JSON"' EXIT

cat > "$FLASK_LT_JSON" <<EOF
{
  "ImageId": "$AMI_ID",
  "InstanceType": "t3.large",
  "IamInstanceProfile": {"Name": "$ROLE_NAME"},
  "SecurityGroupIds": ["$FLASK_SG"],
  "UserData": "$FLASK_UD_B64",
  "BlockDeviceMappings": [{
    "DeviceName": "/dev/xvda",
    "Ebs": {
      "VolumeSize": 30,
      "VolumeType": "gp3",
      "DeleteOnTermination": true,
      "Encrypted": true
    }
  }],
  "MetadataOptions": {
    "HttpTokens": "required",
    "HttpPutResponseHopLimit": 1
  }
}
EOF

cat > "$REACT_LT_JSON" <<EOF
{
  "ImageId": "$AMI_ID",
  "InstanceType": "t3.small",
  "IamInstanceProfile": {"Name": "$ROLE_NAME"},
  "SecurityGroupIds": ["$REACT_SG"],
  "UserData": "$REACT_UD_B64",
  "MetadataOptions": {
    "HttpTokens": "required",
    "HttpPutResponseHopLimit": 1
  }
}
EOF

aws ec2 create-launch-template --launch-template-name ollama-chat-flask-lt \
  --launch-template-data file://"$FLASK_LT_JSON" \
  --query 'LaunchTemplate.LaunchTemplateId' --output text

aws ec2 create-launch-template --launch-template-name ollama-chat-react-lt \
  --launch-template-data file://"$REACT_LT_JSON" \
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
echo "Ready:   http://$ALB_DNS/api/ready"
echo "Health:  http://$ALB_DNS/api/health"
echo ""
echo "Next: export GHCR_PAT=... ALB_DNS=$ALB_DNS && ./infrastructure/push-frontend.sh"
echo "State saved to $STATE_FILE"
