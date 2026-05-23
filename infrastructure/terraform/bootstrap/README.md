# Terraform State Bootstrap

One-time setup for remote Terraform state using Amazon S3 and DynamoDB locking.

## Prerequisites

- AWS CLI configured with permissions to create S3 buckets and DynamoDB tables
- Terraform >= 1.5.0 installed locally

## Recommended resources

| Resource | Purpose |
|----------|---------|
| S3 bucket | Store `terraform.tfstate` remotely with versioning |
| DynamoDB table | State locking (`LockID` string hash key) |

## Manual bootstrap (AWS CLI)

Replace `<ACCOUNT_ID>` with your AWS account ID.

```bash
export AWS_REGION=us-east-1
export STATE_BUCKET=ollama-chat-terraform-state-<ACCOUNT_ID>
export LOCK_TABLE=ollama-chat-terraform-locks

aws s3api create-bucket \
  --bucket "$STATE_BUCKET" \
  --region "$AWS_REGION"

aws s3api put-bucket-versioning \
  --bucket "$STATE_BUCKET" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket "$STATE_BUCKET" \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
  }'

aws s3api put-public-access-block \
  --bucket "$STATE_BUCKET" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws dynamodb create-table \
  --table-name "$LOCK_TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$AWS_REGION"
```

## Enable remote backend

Edit [../environments/dev/backend.tf](../environments/dev/backend.tf) and uncomment the `backend "s3"` block with your bucket and table names.

```bash
cd ../environments/dev
terraform init -migrate-state
```

## AWS documentation

- [Terraform backend best practices on AWS](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/backend.html)
- [Managing Terraform state files in CI/CD](https://aws.amazon.com/blogs/devops/best-practices-for-managing-terraform-state-files-in-aws-ci-cd-pipeline/)
