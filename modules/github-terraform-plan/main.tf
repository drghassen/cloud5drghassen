locals {
  role_name          = "${var.name_prefix}-github-terraform-plan"
  repo_owner         = split("/", var.github_repository)[0]
  repo_name          = split("/", var.github_repository)[1]
  subject            = "repo:${local.repo_owner}@${var.github_owner_id}/${local.repo_name}@${var.github_repository_id}:environment:${var.github_environment}"
  state_object_arn   = "${var.state_bucket_arn}/${var.state_key}"
  state_lock_arn     = "${local.state_object_arn}.tflock"
  role_arn           = "arn:aws:iam::${var.aws_account_id}:role/${var.name_prefix}-*"
  profile_arn        = "arn:aws:iam::${var.aws_account_id}:instance-profile/${var.name_prefix}-*"
  storage_bucket_arn = "arn:aws:s3:::${var.name_prefix}-storage-${var.aws_account_id}"
}

resource "aws_iam_role" "this" {
  name                 = local.role_name
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud"                 = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub"                 = local.subject
          "token.actions.githubusercontent.com:repository_id"       = var.github_repository_id
          "token.actions.githubusercontent.com:repository_owner_id" = var.github_owner_id
        }
        StringLike = {
          "token.actions.githubusercontent.com:ref" = var.github_ref_patterns
        }
      }
    }]
  })

  tags = merge(var.common_tags, {
    Name = local.role_name
    Role = "github-terraform-plan"
  })
}

resource "aws_iam_role_policy" "this" {
  name = "${local.role_name}-read-only"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadTerraformState"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = local.state_object_arn
      },
      {
        Sid      = "ManageOnlyTerraformLock"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = local.state_lock_arn
      },
      {
        Sid      = "ListStateAndLock"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = var.state_bucket_arn
        Condition = {
          StringLike = {
            "s3:prefix" = [var.state_key, "${var.state_key}.tflock"]
          }
        }
      },
      {
        Sid      = "ReadStateBucketMetadata"
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:GetBucketVersioning"]
        Resource = var.state_bucket_arn
      },
      {
        Sid    = "ReadRegionalInfrastructure"
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribePolicies",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAddressesAttribute",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstances",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeNatGateways",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroupRules",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes",
          "ec2:DescribeVpcAttribute",
          "ec2:DescribeVpcs",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTags",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth",
          "rds:DescribeDBEngineVersions",
          "rds:DescribeDBInstances",
          "rds:DescribeDBSnapshots",
          "rds:DescribeDBSubnetGroups",
          "rds:DescribeOrderableDBInstanceOptions"
        ]
        # EC2, ELB, RDS, and Auto Scaling Describe APIs require wildcard resources;
        # these permissions are read-only and constrained to the configured region.
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Sid      = "ReadManagedIamRoles"
        Effect   = "Allow"
        Action   = ["iam:GetRole", "iam:GetRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListRoleTags"]
        Resource = local.role_arn
      },
      {
        Sid      = "ReadManagedInstanceProfiles"
        Effect   = "Allow"
        Action   = ["iam:GetInstanceProfile", "iam:ListInstanceProfileTags", "iam:ListInstanceProfilesForRole"]
        Resource = local.profile_arn
      },
      {
        Sid    = "ReadStorageBucketConfiguration"
        Effect = "Allow"
        Action = [
          "s3:GetBucketAcl",
          "s3:GetBucketCORS",
          "s3:GetBucketLocation",
          "s3:GetBucketOwnershipControls",
          "s3:GetBucketPolicy",
          "s3:GetBucketPolicyStatus",
          "s3:GetBucketPublicAccessBlock",
          "s3:GetBucketTagging",
          "s3:GetBucketVersioning",
          "s3:GetEncryptionConfiguration",
          "s3:GetLifecycleConfiguration",
          "s3:ListBucket"
        ]
        Resource = local.storage_bucket_arn
      },
      {
        Sid    = "ReadCallerIdentity"
        Effect = "Allow"
        Action = ["sts:GetCallerIdentity"]
        # sts:GetCallerIdentity does not support resource-level permissions.
        Resource = "*"
      }
    ]
  })
}
