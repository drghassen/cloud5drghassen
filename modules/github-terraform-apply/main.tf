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
  # Attach the narrower create-time tagging policy before updating the inline
  # policy. Old live permissions remain effective until the update succeeds.
  depends_on = [aws_iam_role_policy_attachment.create_tags]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
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
        Sid      = "ReadEnvironmentPlanVersion"
        Effect   = "Allow"
        Action   = ["s3:GetObjectVersion"]
        Resource = "${var.state_bucket_arn}/cloud5/ci-plans/v1/${var.environment}/*"
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
          "elasticloadbalancing:DescribeListenerAttributes",
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
        Sid    = "ReadProjectInstanceIam"
        Effect = "Allow"
        Action = [
          "iam:GetInstanceProfile",
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfileTags",
          "iam:ListInstanceProfilesForRole",
          "iam:ListRolePolicies",
          "iam:ListRoleTags"
        ]
        Resource = [local.instance_role_arn, local.instance_profile_arn]
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
        Action   = ["s3:GetAccelerateConfiguration", "s3:GetBucket*", "s3:GetEncryptionConfiguration", "s3:GetLifecycleConfiguration", "s3:GetReplicationConfiguration", "s3:ListBucket"]
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
            "aws:RequestTag/Owner"       = "drghassen"
            "aws:RequestTag/Project"     = var.project_name
            "aws:RequestTag/Environment" = var.environment
          }
        }
      },
      {
        Sid      = "UseOwnedVpcForChildCreation"
        Effect   = "Allow"
        Action   = ["ec2:CreateSubnet", "ec2:CreateRouteTable", "ec2:CreateSecurityGroup"]
        Resource = "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:vpc/*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion"         = var.aws_region
            "aws:ResourceTag/Owner"       = "drghassen"
            "aws:ResourceTag/Project"     = var.project_name
            "aws:ResourceTag/Environment" = var.environment
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
            "aws:ResourceTag/Owner"       = "drghassen"
            "aws:ResourceTag/Project"     = var.project_name
            "aws:ResourceTag/Environment" = var.environment
          }
        }
      },
      {
        Sid    = "CreateAndManageProjectLoadBalancer"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:ModifyListenerAttributes",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
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
          "autoscaling:DeleteAutoScalingGroup",
          "autoscaling:PutScalingPolicy",
          "autoscaling:DeletePolicy"
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
          "rds:CreateDBInstance",
          "rds:CreateDBSubnetGroup",
          "rds:DeleteDBInstance",
          "rds:DeleteDBSubnetGroup",
          "rds:ModifyDBInstance",
          "rds:ModifyDBSubnetGroup",
          "rds:ListTagsForResource"
        ]
        Resource = [local.db_instance_arn, local.db_subnet_group_arn]
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Sid       = "CreateRdsManagedSecret"
        Effect    = "Allow"
        Action    = ["secretsmanager:CreateSecret", "secretsmanager:TagResource"]
        Resource  = "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:rds!db-*"
        Condition = { StringEquals = { "aws:RequestedRegion" = var.aws_region } }
      },
      {
        Sid      = "DescribeSecretsManagerKey"
        Effect   = "Allow"
        Action   = ["kms:DescribeKey"]
        Resource = "arn:aws:kms:${var.aws_region}:${var.aws_account_id}:key/*"
        Condition = {
          StringEquals               = { "aws:RequestedRegion" = var.aws_region }
          "ForAnyValue:StringEquals" = { "kms:ResourceAliases" = "alias/aws/secretsmanager" }
        }
      },
      {
        Sid      = "AttachOnlySsmPolicyToProjectInstanceRole"
        Effect   = "Allow"
        Action   = ["iam:AttachRolePolicy", "iam:DetachRolePolicy"]
        Resource = local.instance_role_arn
        Condition = {
          ArnEquals = {
            "iam:PolicyARN" = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
          }
          StringEquals = {
            "aws:ResourceTag/Owner"       = "drghassen"
            "aws:ResourceTag/Project"     = var.project_name
            "aws:ResourceTag/Environment" = var.environment
          }
        }
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
        Sid    = "ManageProjectSecurityGroupRules"
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress"
        ]
        Resource = "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:security-group-rule/*"
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
      ], var.environment == "dev" ? [{
        Sid      = "WriteDevDiagnostics"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${var.state_bucket_arn}/cloud5/ci-diagnostics/v1/dev/*"
        Condition = {
          StringEquals = { "s3:x-amz-server-side-encryption" = "AES256" }
        }
    }] : [])
  })
}

resource "aws_iam_policy" "create_tags" {
  name = "${local.role_name}-ec2-create-tags"
  tags = var.common_tags
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "TagEc2OnlyDuringApprovedCreation"
      Effect   = "Allow"
      Action   = ["ec2:CreateTags"]
      Resource = local.ec2_resource_arns
      Condition = {
        StringEquals = {
          "aws:RequestedRegion"        = var.aws_region
          "aws:RequestTag/Owner"       = "drghassen"
          "aws:RequestTag/Project"     = var.project_name
          "aws:RequestTag/Environment" = var.environment
          "ec2:CreateAction" = [
            "AllocateAddress", "CreateInternetGateway", "CreateLaunchTemplate", "CreateNatGateway",
            "CreateRouteTable", "CreateSecurityGroup", "CreateSubnet", "CreateVpc"
          ]
        }
      }
      },
      {
        Sid    = "LaunchTaggedInstancesAndVolumes"
        Effect = "Allow"
        Action = ["ec2:RunInstances"]
        Resource = [
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:instance/*",
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:volume/*"
        ]
        Condition = {
          StringEquals = {
            "aws:RequestedRegion"        = var.aws_region
            "aws:RequestTag/Owner"       = "drghassen"
            "aws:RequestTag/Project"     = var.project_name
            "aws:RequestTag/Environment" = var.environment
          }
          ArnLike = { "ec2:LaunchTemplate" = "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:launch-template/*" }
        }
      },
      {
        Sid      = "LaunchUsingOwnedDependencies"
        Effect   = "Allow"
        Action   = ["ec2:RunInstances"]
        Resource = [for t in ["launch-template", "subnet", "security-group"] : "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:${t}/*"]
        Condition = {
          StringEquals = {
            "aws:RequestedRegion"         = var.aws_region
            "aws:ResourceTag/Owner"       = "drghassen"
            "aws:ResourceTag/Project"     = var.project_name
            "aws:ResourceTag/Environment" = var.environment
          }
          ArnLike = { "ec2:LaunchTemplate" = "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:launch-template/*" }
        }
      },
      {
        Sid      = "LaunchAmazonImage"
        Effect   = "Allow"
        Action   = ["ec2:RunInstances"]
        Resource = "arn:aws:ec2:${var.aws_region}::image/*"
        Condition = {
          StringEquals = { "aws:RequestedRegion" = var.aws_region, "ec2:Owner" = "amazon" }
          ArnLike      = { "ec2:LaunchTemplate" = "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:launch-template/*" }
        }
      },
      {
        Sid      = "LaunchPrivateNetworkInterface"
        Effect   = "Allow"
        Action   = ["ec2:RunInstances"]
        Resource = "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:network-interface/*"
        Condition = {
          StringEquals = { "aws:RequestedRegion" = var.aws_region }
          ArnLike      = { "ec2:LaunchTemplate" = "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:launch-template/*" }
          Bool         = { "ec2:AssociatePublicIpAddress" = "false" }
        }
      },
      {
        Sid       = "RequireImdsV2"
        Effect    = "Deny"
        Action    = ["ec2:RunInstances"]
        Resource  = "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:instance/*"
        Condition = { StringNotEquals = { "ec2:MetadataHttpTokens" = "required" } }
      },
      {
        Sid      = "TagNewInstanceVolumeAndRules"
        Effect   = "Allow"
        Action   = ["ec2:CreateTags"]
        Resource = [for t in ["instance", "volume", "security-group-rule"] : "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:${t}/*"]
        Condition = {
          StringEquals = {
            "aws:RequestedRegion"        = var.aws_region
            "aws:RequestTag/Owner"       = "drghassen"
            "aws:RequestTag/Project"     = var.project_name
            "aws:RequestTag/Environment" = var.environment
            "ec2:CreateAction"           = ["RunInstances", "AuthorizeSecurityGroupIngress", "AuthorizeSecurityGroupEgress"]
          }
        }
      },
      {
        Sid      = "CreateAutoScalingWithNumericTemplate"
        Effect   = "Allow"
        Action   = ["autoscaling:CreateAutoScalingGroup"]
        Resource = local.auto_scaling_group_arn
        Condition = {
          StringEquals = { "aws:RequestedRegion" = var.aws_region, "aws:RequestTag/Owner" = "drghassen", "aws:RequestTag/Project" = var.project_name, "aws:RequestTag/Environment" = var.environment }
          Bool         = { "autoscaling:LaunchTemplateVersionSpecified" = "true" }
        }
      },
      {
        Sid      = "UpdateAutoScalingWithNumericTemplate"
        Effect   = "Allow"
        Action   = ["autoscaling:UpdateAutoScalingGroup"]
        Resource = local.auto_scaling_group_arn
        Condition = {
          StringEquals = { "aws:RequestedRegion" = var.aws_region, "aws:ResourceTag/Owner" = "drghassen", "aws:ResourceTag/Project" = var.project_name, "aws:ResourceTag/Environment" = var.environment }
          BoolIfExists = { "autoscaling:LaunchTemplateVersionSpecified" = "true" }
        }
      },
      {
        Sid       = "TagProjectAutoScaling"
        Effect    = "Allow"
        Action    = ["autoscaling:CreateOrUpdateTags"]
        Resource  = local.auto_scaling_group_arn
        Condition = { StringEquals = { "aws:RequestedRegion" = var.aws_region, "aws:RequestTag/Owner" = "drghassen", "aws:RequestTag/Project" = var.project_name, "aws:RequestTag/Environment" = var.environment } }
      },
      {
        Sid       = "TagLoadBalancerOnCreation"
        Effect    = "Allow"
        Action    = ["elasticloadbalancing:AddTags"]
        Resource  = local.load_balancer_resource_arns
        Condition = { StringEquals = { "aws:RequestedRegion" = var.aws_region, "elasticloadbalancing:CreateAction" = ["CreateLoadBalancer", "CreateTargetGroup", "CreateListener"] } }
      },
      {
        Sid       = "TagNamedDatabase"
        Effect    = "Allow"
        Action    = ["rds:AddTagsToResource"]
        Resource  = [local.db_instance_arn, local.db_subnet_group_arn]
        Condition = { StringEquals = { "aws:RequestedRegion" = var.aws_region, "aws:RequestTag/Owner" = "drghassen", "aws:RequestTag/Project" = var.project_name, "aws:RequestTag/Environment" = var.environment } }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "create_tags" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.create_tags.arn
}
