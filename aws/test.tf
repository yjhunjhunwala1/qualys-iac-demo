###########################################
# Terraform CSPM Misconfiguration Demo
# 100 Violations as per CIS AWS Foundations
# WARNING: Do NOT deploy in production
###########################################

provider "aws" {
  region = "us-east-1"
}

#########################
# IAM Misconfigurations
#########################
resource "aws_iam_user" "admin_user" {
  name = "admin-user"
}

resource "aws_iam_user_policy_attachment" "admin_attach" {
  user       = aws_iam_user.admin_user.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess" # ❌ CIS 1.20
}

resource "aws_iam_access_key" "admin_key" {
  user = aws_iam_user.admin_user.name
} # ❌ CIS 1.3, 1.4

resource "aws_iam_group" "wildcard_group" {
  name = "wildcard-group"
}

resource "aws_iam_group_policy" "wildcard_policy" {
  name  = "wildcard"
  group = aws_iam_group.wildcard_group.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*"
    }
  ]
}
EOF
} # ❌ Wildcards in policy

resource "aws_iam_user" "mfa_user" {
  name = "no-mfa-user"
} # ❌ No MFA

resource "aws_iam_user" "inactive_user" {
  name = "inactive-user"
} # ❌ Should be removed if not used

resource "aws_iam_user" "no_password_policy_user" {
  name = "nopw-user"
} # ❌ Password policy not enforced

resource "aws_iam_user" "service_account_user" {
  name = "svc-account"
} # ❌ Service accounts should use roles

resource "aws_iam_user_policy" "wildcard_iam_user_policy" {
  name = "wildcard-policy"
  user = aws_iam_user.service_account_user.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*"
    }
  ]
}
EOF
} # ❌ IAM user policy with wildcards

#########################
# Logging (CloudTrail)
#########################
resource "aws_s3_bucket" "trail_bucket" {
  bucket = "trail-bucket-1234"
  acl    = "private"
} # ❌ No encryption, no logging

resource "aws_cloudtrail" "bad_trail" {
  name                          = "badtrail"
  s3_bucket_name                = aws_s3_bucket.trail_bucket.id
  include_global_service_events = false # ❌
  is_multi_region_trail         = false # ❌
  enable_log_file_validation    = false # ❌
}

resource "aws_s3_bucket" "trail_logs_bucket" {
  bucket = "trail-logs-unsecure"
  acl    = "public-read"
} # ❌ Public trail logs

#########################
# EC2 & EBS Misconfigs
#########################
resource "aws_instance" "public_ec2" {
  ami                         = "ami-0abcdef1234567890"
  instance_type               = "t2.micro"
  associate_public_ip_address = true # ❌
} # ❌ No SG, no key_name

resource "aws_instance" "default_sg_ec2" {
  ami           = "ami-0abcdef1234567890"
  instance_type = "t2.micro"
  vpc_security_group_ids = [] # ❌ Default SG
} # ❌ No monitoring/logging agent

resource "aws_ebs_volume" "unencrypted_volume" {
  availability_zone = "us-east-1a"
  size              = 10
  type              = "gp2"
} # ❌ No encryption

resource "aws_ebs_snapshot" "unencrypted_snapshot" {
  volume_id = aws_ebs_volume.unencrypted_volume.id
} # ❌ No encryption

resource "aws_volume_attachment" "attach_unencrypted" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.unencrypted_volume.id
  instance_id = aws_instance.public_ec2.id
}

#########################
# S3 Misconfigs
#########################
resource "aws_s3_bucket" "public_s3" {
  bucket = "misconfigured-s3-demo"
  acl    = "public-read" # ❌
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.public_s3.id

  versioning_configuration {
    status = "Suspended" # ❌
  }
}

resource "aws_s3_bucket_public_access_block" "access_block" {
  bucket = aws_s3_bucket.public_s3.id

  block_public_acls       = false # ❌
  block_public_policy     = false # ❌
  ignore_public_acls      = false # ❌
  restrict_public_buckets = false # ❌
}

resource "aws_s3_bucket_policy" "open_bucket_policy" {
  bucket = aws_s3_bucket.public_s3.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": ["s3:GetObject"],
      "Resource": ["arn:aws:s3:::misconfigured-s3-demo/*"]
    }
  ]
}
EOF
} # ❌ Overly permissive bucket policy

resource "aws_s3_bucket" "no_encryption_bucket" {
  bucket = "unencrypted-s3-demo"
  acl    = "private"
} # ❌ No encryption

#########################
# KMS Misconfigs
#########################
resource "aws_kms_key" "open_kms" {
  description         = "Unrestricted key"
  deletion_window_in_days = 30
  enable_key_rotation = false # ❌

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "kms:*",
      "Resource": "*"
    }
  ]
}
POLICY
} # ❌ Wildcard principal and actions

resource "aws_kms_key" "no_rotation_kms" {
  description = "Key without rotation"
  enable_key_rotation = false # ❌
}

#########################
# CloudWatch Misconfigs
#########################
resource "aws_cloudwatch_log_group" "no_retention" {
  name              = "/aws/lambda/demo"
  retention_in_days = 0 # ❌ No retention
}

resource "aws_cloudwatch_log_group" "unencrypted_logs" {
  name = "/aws/app/unencrypted"
} # ❌ No encryption

#########################
# VPC & Network
#########################
resource "aws_security_group" "open_sg" {
  name   = "open-sg"
  vpc_id = "vpc-12345678"

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # ❌ Too open
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # ❌ Too open
  }
}

resource "aws_vpc" "default_vpc" {
  cidr_block = "172.31.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
} # ❌ Using default VPC for all traffic

#########################
# General Misconfigs
#########################
resource "aws_cloudformation_stack" "wildcard_template" {
  name          = "insecure-template"
  template_body = <<TEMPLATE
{
  "Resources": {
    "BadRole": {
      "Type": "AWS::IAM::Role",
      "Properties": {
        "AssumeRolePolicyDocument": {
          "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "ec2.amazonaws.com"},
            "Action": "sts:AssumeRole"
          }]
        },
        "Policies": [{
          "PolicyName": "BadPolicy",
          "PolicyDocument": {
            "Statement": [{
              "Effect": "Allow",
              "Action": "*",
              "Resource": "*"
            }]
          }
        }]
      }
    }
  }
}
TEMPLATE
} # ❌ Wildcard IAM in CFN
