#!/usr/bin/env bash
# Import resources created by deploy-aws.sh into Terraform state (us-east-1).
# Run from: infrastructure/terraform/environments/dev
#
# Prerequisites:
#   export AWS_REGION=us-east-1
#   export TF_VAR_ghcr_pat='placeholder'   # SSM value is ignore_changes; existing PAT kept
#   terraform init
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_DIR="$(cd "$SCRIPT_DIR/../environments/dev" && pwd)"
cd "$DEV_DIR"

import() {
  local addr="$1"
  local id="$2"
  if terraform state show "$addr" &>/dev/null; then
    echo "skip (in state): $addr"
    return 0
  fi
  echo "import: $addr <- $id"
  terraform import "$addr" "$id"
}

# IDs from deploy-aws.sh stack (ollama-chat, us-east-1)
VPC_ID="${VPC_ID:-vpc-0c4c84ae38d0a7f51}"
IGW_ID="${IGW_ID:-igw-0f28cdf528e845c5a}"
PUBLIC_SUBNET_0="${PUBLIC_SUBNET_0:-subnet-040eceebaeb00bc26}"
PUBLIC_SUBNET_1="${PUBLIC_SUBNET_1:-subnet-0be6f49b549f18e83}"
PRIVATE_SUBNET_0="${PRIVATE_SUBNET_0:-subnet-097dd0cb7af86b35f}"
PRIVATE_SUBNET_1="${PRIVATE_SUBNET_1:-subnet-0c44d23fd08312443}"
NAT_EIP="${NAT_EIP:-eipalloc-0cf9aa2db9bd89c31}"
NAT_GW="${NAT_GW:-nat-03b82f120dfc434be}"
PUBLIC_RT="${PUBLIC_RT:-rtb-097c19f34ed98f054}"
PRIVATE_RT="${PRIVATE_RT:-rtb-0b9d0d0b6be5f0994}"
PRIVATE_NACL="${PRIVATE_NACL:-acl-02e319289a1d57226}"
NACL_ASSOC_0="${NACL_ASSOC_0:-aclassoc-06e697b3c2e3c5df3}"
NACL_ASSOC_1="${NACL_ASSOC_1:-aclassoc-0a4acead3effdc741}"

ALB_SG="${ALB_SG:-sg-0a1c6282d7232e008}"
REACT_SG="${REACT_SG:-sg-0517620f7597b3e7a}"
FLASK_SG="${FLASK_SG:-sg-0ac189c8cc609de43}"

ALB_ARN="${ALB_ARN:-arn:aws:elasticloadbalancing:us-east-1:388691194728:loadbalancer/app/ollama-chat-alb/474dfa2abd89e81a}"
FLASK_TG_ARN="${FLASK_TG_ARN:-arn:aws:elasticloadbalancing:us-east-1:388691194728:targetgroup/ollama-chat-flask-tg/140644381166265e}"
REACT_TG_ARN="${REACT_TG_ARN:-arn:aws:elasticloadbalancing:us-east-1:388691194728:targetgroup/ollama-chat-react-tg/f6e8212eecbe2f7e}"
LISTENER_ARN="${LISTENER_ARN:-arn:aws:elasticloadbalancing:us-east-1:388691194728:listener/app/ollama-chat-alb/474dfa2abd89e81a/56d726ce1b9249ac}"
API_RULE_ARN="${API_RULE_ARN:-arn:aws:elasticloadbalancing:us-east-1:388691194728:listener-rule/app/ollama-chat-alb/474dfa2abd89e81a/56d726ce1b9249ac/89bfe8394988e3f3}"

FLASK_LT="${FLASK_LT:-lt-0cb338b33444a5ecd}"
REACT_LT="${REACT_LT:-lt-04b4a8e4e7f7b6437}"

echo "==> Importing deploy-aws.sh stack into Terraform state"
echo "    Working directory: $DEV_DIR"
echo ""

import 'module.networking.aws_vpc.this' "$VPC_ID"
import 'module.networking.aws_internet_gateway.this' "$IGW_ID"
import 'module.networking.aws_subnet.public[0]' "$PUBLIC_SUBNET_0"
import 'module.networking.aws_subnet.public[1]' "$PUBLIC_SUBNET_1"
import 'module.networking.aws_subnet.private[0]' "$PRIVATE_SUBNET_0"
import 'module.networking.aws_subnet.private[1]' "$PRIVATE_SUBNET_1"
import 'module.networking.aws_eip.nat[0]' "$NAT_EIP"
import 'module.networking.aws_nat_gateway.this[0]' "$NAT_GW"
import 'module.networking.aws_route_table.public' "$PUBLIC_RT"
import 'module.networking.aws_route_table.private[0]' "$PRIVATE_RT"
import "module.networking.aws_route_table_association.public[0]" "${PUBLIC_SUBNET_0}/${PUBLIC_RT}"
import "module.networking.aws_route_table_association.public[1]" "${PUBLIC_SUBNET_1}/${PUBLIC_RT}"
import "module.networking.aws_route_table_association.private[0]" "${PRIVATE_SUBNET_0}/${PRIVATE_RT}"
import "module.networking.aws_route_table_association.private[1]" "${PRIVATE_SUBNET_1}/${PRIVATE_RT}"
import 'module.networking.aws_network_acl.private' "$PRIVATE_NACL"
import 'module.networking.aws_network_acl_association.private[0]' "$NACL_ASSOC_0"
import 'module.networking.aws_network_acl_association.private[1]' "$NACL_ASSOC_1"

import 'module.security.aws_security_group.alb' "$ALB_SG"
import 'module.security.aws_security_group.react' "$REACT_SG"
import 'module.security.aws_security_group.flask' "$FLASK_SG"

import 'module.iam.aws_ssm_parameter.ghcr_pat' '/ollama-chat/ghcr-pat'

import 'module.alb.aws_lb.this' "$ALB_ARN"
import 'module.alb.aws_lb_target_group.flask' "$FLASK_TG_ARN"
import 'module.alb.aws_lb_target_group.react' "$REACT_TG_ARN"
import 'module.alb.aws_lb_listener.http' "$LISTENER_ARN"
import 'module.alb.aws_lb_listener_rule.api' "$API_RULE_ARN"

import 'module.compute.aws_launch_template.flask' "$FLASK_LT"
import 'module.compute.aws_launch_template.react' "$REACT_LT"
import 'module.compute.aws_autoscaling_group.flask' 'ollama-chat-flask-asg'
import 'module.compute.aws_autoscaling_group.react' 'ollama-chat-react-asg'

echo ""
echo "==> Import complete. Run: terraform plan"
