# Artifact storage for the demo service.
#
# Deliberately small: one bucket, one customer-managed key to encrypt it with. The KMS key is the
# only line item with a price attached, which keeps the monthly bill around a dollar while still
# giving the cost policy a real number to judge.
terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Native S3 locking, so there is no DynamoDB table to keep alive alongside the state.
  backend "s3" {
    bucket       = "demo-tirith-action-tfstate-790543352839"
    key          = "tirith-action-demo/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-east-1"
}

locals {
  tags = {
    Name  = "tirith-action-demo"
    Owner = "rafid.aslam"
    Demo  = "tirith-action-demo"
  }
}

resource "aws_kms_key" "artifacts" {
  description             = "Encrypts the tirith-action-demo artifact bucket"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = local.tags
}

resource "aws_s3_bucket" "artifacts" {
  bucket = "demo-tirith-action-artifacts-790543352839"
  tags   = local.tags
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.artifacts.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket" "analytics" {
  bucket = "demo-tirith-action-analytics-790543352839"

  tags = {
    Name  = "tirith-action-demo"
    Demo  = "tirith-action-demo"
    Owner = "data-platform"
  }
}
