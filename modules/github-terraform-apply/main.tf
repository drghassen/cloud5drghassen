locals {
  role_name        = "${var.name_prefix}-github-terraform-apply"
  repo_owner       = split("/", var.github_repository)[0]
  repo_name        = split("/", var.github_repository)[1]
  subject          = "repo:${local.repo_owner}@${var.github_owner_id}/${local.repo_name}@${var.github_repository_id}:environment:${var.github_environment}"
  state_object_arn = "${var.state_bucket_arn}/${var.state_key}"
  state_lock_arn   = "${local.state_object_arn}.tflock"

  instance_role_arn    = "arn:aws:iam::${var.aws_account_id}:role/${var.name_prefix}-web-instance-role"
  instance_profile_arn = "arn:aws:iam::${var.aws_account_id}:instance-profile/${var.name_prefix}-web-instance-profile"
  storage_bucket_arn   = "arn:aws:s3:::${var.name_prefix}-storage-${var.aws_account_id}"

  ec2_resource_arns = [
    "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:vpc/*",
    "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:subnet/*",
    "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:internet-gateway/*",
    "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:route-table/*",
    "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:security-group/*",
    "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:security-group-rule/*",
    "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:elastic-ip/*",
    "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:natgateway/*",
    "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:launch-template/*"
  ]

  load_balancer_resource_arns = [
    "arn:aws:elasticloadbalancing:${var.aws_region}:${var.aws_account_id}:loadbalancer/app/${var.name_prefix}-alb/*",
    "arn:aws:elasticloadbalancing:${var.aws_region}:${var.aws_account_id}:targetgroup/${var.name_prefix}-web-tg/*",
    "arn:aws:elasticloadbalancing:${var.aws_region}:${var.aws_account_id}:listener/app/${var.name_prefix}-alb/*"
  ]

  auto_scaling_group_arn  = "arn:aws:autoscaling:${var.aws_region}:${var.aws_account_id}:autoScalingGroup:*:autoScalingGroupName/${var.name_prefix}-web-asg"
  auto_scaling_policy_arn = "arn:aws:autoscaling:${var.aws_region}:${var.aws_account_id}:scalingPolicy:*:autoScalingGroupName/${var.name_prefix}-web-asg:policyName/${var.name_prefix}-web-cpu-target"
  db_instance_arn         = "arn:aws:rds:${var.aws_region}:${var.aws_account_id}:db:${var.name_prefix}-postgres"
  db_subnet_group_arn     = "arn:aws:rds:${var.aws_region}:${var.aws_account_id}:subgrp:${var.name_prefix}-db-subnets"
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
          "token.actions.githubusercontent.com:ref"                 = "refs/heads/main"
          "token.actions.githubusercontent.com:repository_id"       = var.github_repository_id
          "token.actions.githubusercontent.com:repository_owner_id" = var.github_owner_id
        }
      }
    }]
  })

  tags = merge(var.common_tags, {
    Name = local.role_name
    Role = "github-terraform-apply"
  })
}

resource "aws_iam_role_policy" "this" {
  name = "${local.role_name}-${var.environment}-infrastructure"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadAndWriteOnly${title(var.environment)}State"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = local.state_object_arn
      },
      {
        Sid      = "ManageOnly${title(var.environment)}StateLock"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = local.state_lock_arn
      },
      {
        Sid      = "ListOnly${title(var.environment)}StateAndLock"
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
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Sid      = "ReadManagedInstanceRole"
        Effect   = "Allow"
        Action   = ["iam:GetRole", "iam:GetRolePolicy", "iam:ListAttachedRolePolicies", "iam:ListRolePolicies", "iam:ListRoleTags"]
        Resource = local.instance_role_arn
      },
      {
        Sid      = "ReadManagedInstanceProfile"
        Effect   = "Allow"
        Action   = ["iam:GetInstanceProfile", "iam:ListInstanceProfileTags", "iam:ListInstanceProfilesForRole"]
        Resource = local.instance_profile_arn
      },
      {
        Sid      = "ReadSsmManagedPolicy"
        Effect   = "Allow"
        Action   = ["iam:GetPolicy", "iam:GetPolicyVersion"]
        Resource = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      },
      {
        Sid      = "ReadApplicationBucketConfiguration"
        Effect   = "Allow"
        Action   = ["s3:GetBucketAcl", "s3:GetBucketCORS", "s3:GetBucketLocation", "s3:GetBucketOwnershipControls", "s3:GetBucketPolicy", "s3:GetBucketPolicyStatus", "s3:GetBucketPublicAccessBlock", "s3:GetBucketTagging", "s3:GetBucketVersioning", "s3:GetEncryptionConfiguration", "s3:GetLifecycleConfiguration", "s3:ListBucket"]
        Resource = local.storage_bucket_arn
      },
      {
        Sid    = "CreateTaggedEc2Resources"
        Effect = "Allow"
        Action = [
          "ec2:AllocateAddress",
          "ec2:CreateInternetGateway",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateNatGateway",
          "ec2:CreateRouteTable",
          "ec2:CreateSecurityGroup",
          "ec2:CreateSubnet",
          "ec2:CreateVpc"
        ]
        Resource = local.ec2_resource_arns
        Condition = {
          StringEquals = {
            "aws:RequestedRegion"        = var.aws_region
            "aws:RequestTag/Project"     = var.project_name
            "aws:RequestTag/Environment" = var.environment
          }
        }
      },
      {
        Sid    = "ManageTaggedEc2Resources"
        Effect = "Allow"
        Action = [
          "ec2:AssociateRouteTable",
          "ec2:AttachInternetGateway",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:CreateLaunchTemplateVersion",
          "ec2:CreateNatGateway",
          "ec2:CreateRoute",
          "ec2:CreateRouteTable",
          "ec2:CreateSecurityGroup",
          "ec2:CreateSubnet",
          "ec2:DeleteInternetGateway",
          "ec2:DeleteLaunchTemplate",
          "ec2:DeleteLaunchTemplateVersions",
          "ec2:DeleteNatGateway",
          "ec2:DeleteRoute",
          "ec2:DeleteRouteTable",
          "ec2:DeleteSecurityGroup",
          "ec2:DeleteSubnet",
          "ec2:DeleteVpc",
          "ec2:DetachInternetGateway",
          "ec2:DisassociateRouteTable",
          "ec2:ModifyLaunchTemplate",
          "ec2:ModifySubnetAttribute",
          "ec2:ModifyVpcAttribute",
          "ec2:ReleaseAddress",
          "ec2:ReplaceRoute",
          "ec2:ReplaceRouteTableAssociation",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress"
        ]
        Resource = local.ec2_resource_arns
        Condition = {
          StringEquals = {
            "aws:RequestedRegion"         = var.aws_region
            "aws:ResourceTag/Project"     = var.project_name
            "aws:ResourceTag/Environment" = var.environment
          }
        }
      },
      {
        Sid      = "TagEc2ResourcesForThisProject"
        Effect   = "Allow"
        Action   = ["ec2:CreateTags"]
        Resource = local.ec2_resource_arns
        Condition = {
          StringEquals = {
            "aws:RequestedRegion"        = var.aws_region
            "aws:RequestTag/Project"     = var.project_name
            "aws:RequestTag/Environment" = var.environment
          }
        }
      },
      {
        Sid    = "CreateAndManageProjectLoadBalancer"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:RemoveTags",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:SetSubnets"
        ]
        Resource = local.load_balancer_resource_arns
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Sid    = "CreateAndManageProjectAutoScaling"
        Effect = "Allow"
        Action = [
          "autoscaling:CreateAutoScalingGroup",
          "autoscaling:CreateOrUpdateTags",
          "autoscaling:DeleteAutoScalingGroup",
          "autoscaling:DeleteTags",
          "autoscaling:PutScalingPolicy",
          "autoscaling:DeletePolicy",
          "autoscaling:UpdateAutoScalingGroup"
        ]
        Resource = [local.auto_scaling_group_arn, local.auto_scaling_policy_arn]
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Sid    = "CreateAndManageProjectDatabase"
        Effect = "Allow"
        Action = [
          "rds:AddTagsToResource",
          "rds:CreateDBInstance",
          "rds:CreateDBSubnetGroup",
          "rds:DeleteDBInstance",
          "rds:DeleteDBSubnetGroup",
          "rds:ModifyDBInstance",
          "rds:ModifyDBSubnetGroup",
          "rds:ListTagsForResource",
          "rds:RemoveTagsFromResource"
        ]
        Resource = [local.db_instance_arn, local.db_subnet_group_arn]
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Sid    = "ManageProjectInstanceIam"
        Effect = "Allow"
        Action = [
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:TagInstanceProfile",
          "iam:UntagInstanceProfile",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:UpdateAssumeRolePolicy"
        ]
        Resource = [local.instance_role_arn, local.instance_profile_arn]
      },
      {
        Sid    = "AttachOnlySsmPolicyToProjectInstanceRole"
        Effect = "Allow"
        Action = ["iam:AttachRolePolicy", "iam:DetachRolePolicy"]
        Resource = [
          local.instance_role_arn,
          "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        ]
      },
      {
        Sid      = "PassOnlyProjectInstanceRoleToEc2"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = local.instance_role_arn
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ec2.amazonaws.com"
          }
        }
      },
      {
        Sid    = "CreateAndManageProjectStorageBucket"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:DeleteBucketPolicy",
          "s3:PutBucketAcl",
          "s3:PutBucketPolicy",
          "s3:PutBucketPublicAccessBlock",
          "s3:PutBucketOwnershipControls",
          "s3:PutEncryptionConfiguration",
          "s3:PutLifecycleConfiguration",
          "s3:PutBucketTagging",
          "s3:PutBucketVersioning"
        ]
        Resource = local.storage_bucket_arn
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Sid      = "ReadCallerIdentity"
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity"]
        Resource = "*"
      }
    ]
  })
}
