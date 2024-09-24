provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# Terraform Backend Configuration
terraform {
  backend "s3" {
    bucket         = "chong-terraform-state"
    key            = "v1/techops/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-lock-table"
    encrypt        = true
    profile        = "chong"
  }
}
