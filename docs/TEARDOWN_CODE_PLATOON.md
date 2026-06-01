# Tear down Code Platoon ollama-chat stack

Run these steps **only after** the personal AWS stack is healthy. Use Code Platoon account credentials (not personal).

```bash
export AWS_REGION=us-east-1
export AWS_PROFILE=codeplatoon   # your Code Platoon profile name

aws sts get-caller-identity   # confirm NOT account 570912405222
```

## 1. Scale ASGs to zero

```bash
for asg in ollama-chat-flask-asg ollama-chat-react-asg; do
  aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name "$asg" \
    --min-size 0 --max-size 0 --desired-capacity 0
done
```

Wait until no EC2 instances remain for these ASGs.

## 2. Delete application resources

Delete in order (Console or CLI):

1. Auto Scaling groups (`ollama-chat-flask-asg`, `ollama-chat-react-asg`)
2. Launch templates (`ollama-chat-flask-lt`, `ollama-chat-react-lt`)
3. ALB listener rules, listener, target groups, ALB (`ollama-chat-alb`)
4. NAT gateway; release Elastic IP
5. Detach and delete Internet Gateway
6. Subnets, route tables, VPC (`ollama-chat-vpc`)
7. Security groups (`ollama-chat-alb-sg`, `ollama-chat-react-sg`, `ollama-chat-flask-sg`)

## 3. IAM and secrets

```bash
aws ssm delete-parameter --name /ollama-chat/ghcr-pat 2>/dev/null || true
aws ssm delete-parameter --name /ollama-chat/api-key 2>/dev/null || true
```

Remove IAM roles: `ollama-chat-flask-ec2-role`, `ollama-chat-react-ec2-role` (Terraform) or legacy `ollama-chat-ec2-ssm-role` (bash deploy).

## 4. Optional: Terraform destroy

If the Code Platoon stack was created with Terraform from this repo:

```bash
cd infrastructure/terraform/environments/dev
terraform destroy
```

Full CLI table: [DEPLOYMENT.md — Teardown](DEPLOYMENT.md#teardown).
