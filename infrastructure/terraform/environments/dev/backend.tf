# Uncomment and configure after running bootstrap (see ../../bootstrap/README.md)
#
# terraform {
#   backend "s3" {
#     bucket         = "ollama-chat-terraform-state-<ACCOUNT_ID>"
#     key            = "dev/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "ollama-chat-terraform-locks"
#     encrypt        = true
#   }
# }
