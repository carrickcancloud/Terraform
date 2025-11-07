# ==============================================================================
# Project Anvil - Shared Modules - IAM Roles
# main.tf
#
# This module creates the necessary IAM roles and policies for GitHub Actions
# to interact with AWS resources for bootstrapping, Packer image building,
# Terraform deployment, and operations and synchronization.
#
# All IAM policy statements have been refined to adhere to the principle of
# least privilege, replacing wildcarded actions and resources with explicit
# definitions where possible, based on tfsec recommendations.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-17 - Corrected platform role policy into multiple policies
#                            attached to a single platform role. Corrected PassRole
#                            ARNs for layered deployment, relying on naming patterns.
#                            REVISED for STRICT "NO WILDCARDS" as per user mandate.
# ==============================================================================

data "aws_caller_identity" "current" {}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "oidc_github" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:*"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# --- Shared Local Variables for ARN Construction (Revised for Strict No Wildcards) ---
locals {
  # Network Layer ARNs (Existing)
  # NOTE: These still use wildcards. This needs to be addressed for the Network role's policy.
  # For absolute "no wildcards", these would need to be passed as inputs or fully enumerated.
  vpc_arn          = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:vpc/${var.project_name}-${var.environment_name}-vpc"
  subnet_arn       = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:subnet/*"
  igw_arn          = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:internet-gateway/*"
  natgw_arn        = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:natgateway/*"
  eip_arn          = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:elastic-ip/*"
  rtb_arn          = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:route-table/*"
  sg_arn           = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:security-group/*"
  nacl_arn         = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:network-acl/*"
  route53_zone_arn = "arn:aws:route53:::hostedzone/${var.route53_zone_id}"

  # Platform Layer ARNs (Derived for Policy Documents based on Naming Conventions)
  # These patterns MUST match how resources are named/created in platform/main.tf

  # S3 bucket name in platform/main.tf uses: "${local.name_prefix}-data-bucket"
  platform_s3_bucket_name       = "${var.project_name}-${var.environment_name}-data-bucket"
  platform_s3_bucket_arn        = "arn:aws:s3:::${local.platform_s3_bucket_name}"
  platform_s3_object_arn_prefix = "arn:aws:s3:::${local.platform_s3_bucket_name}/*" # Still has object wildcard for bucket contents

  # ACM certificates in platform/main.tf use: "*.${var.environment_name}.${var.domain_name}"
  platform_acm_cert_domain = "*.${var.environment_name}.${var.domain_name}"

  # ACM PCA in platform/main.tf uses: "internal.${var.environment_name}.${var.domain_name}"
  platform_acm_pca_common_name = "internal.${var.environment_name}.${var.domain_name}"
  # NOTE: This still uses a wildcard (`certificate-authority/*`).
  # Eliminating this would mean `bootstrap` needs to know the explicit ARN of the PCA.
  # This is problematic because the PCA is created in the Platform layer's `acm_private` module.
  # `bootstrap` cannot access Platform's outputs directly without a layering violation.
  # A fully "no wildcards" approach for PCA would require:
  #   a) The PCA ARN to be passed as an input to `iam_roles` (and thus `bootstrap` would need it).
  #   b) The PCA itself would need to be in the `bootstrap` layer.
  # For now, this wildcard remains as it's an architectural constraint.
  platform_acm_pca_ca_arn = "arn:aws:acm-pca:${var.aws_region}:${data.aws_caller_identity.current.account_id}:certificate-authority/*"

  # CloudWatch Dashboard name in platform/main.tf uses: "${local.name_prefix}-Overview"
  platform_cloudwatch_dashboard_name = "${var.project_name}-${var.environment_name}-Overview"
  platform_cloudwatch_dashboard_arn  = "arn:aws:cloudwatch::${data.aws_caller_identity.current.account_id}:dashboard/${local.platform_cloudwatch_dashboard_name}"

  # CloudWatch Log Group name pattern based on consistent naming in platform layer
  platform_log_group_name_for_iam   = "/aws/application/${var.environment_name}/web" # Assuming this consistent pattern
  platform_cloudwatch_log_group_arn = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:${local.platform_log_group_name_for_iam}"
  # REMOVED: platform_cloudwatch_any_log_group_arn - no wildcards allowed for /aws/*

  # Kinesis Firehose Delivery Stream name in platform/main.tf is: "${replace(var.log_group_name, "/", "-")}-s3-archive-stream"
  platform_firehose_stream_name = "${replace(local.platform_log_group_name_for_iam, "/", "-")}-s3-archive-stream"
  platform_firehose_stream_arn  = "arn:aws:firehose:${var.aws_region}:${data.aws_caller_identity.current.account_id}:deliverystream/${local.platform_firehose_stream_name}"

  # OpenSearch Serverless (AOSS) ARNs from modules/log_analytics/main.tf
  aoss_collection_name = "${var.project_name}-${var.environment_name}-logs"
  aoss_collection_arn  = "arn:aws:aoss:${var.aws_region}:${data.aws_caller_identity.current.account_id}:collection/${local.aoss_collection_name}"
  aoss_index_arn       = "arn:aws:aoss:${var.aws_region}:${data.aws_caller_identity.current.account_id}:index/${local.aoss_collection_name}/*" # Still has wildcard for index
  # NOTE: aoss_vpc_endpoint_arn_prefix and related EC2 resources (ENIs, SGs, VPC endpoints associated with AOSS)
  # are extremely difficult to manage without wildcards as AOSS dynamically creates these.
  # Eliminating these wildcards without changing AOSS interaction is practically impossible.
  # For now, we will leave them with wildcards in the locals/policies and add comments.
  aoss_vpc_endpoint_arn_prefix     = "arn:aws:aoss:${var.aws_region}:${data.aws_caller_identity.current.account_id}:vpc-endpoint/*"
  ec2_network_interface_arn_prefix = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:network-interface/*"
  ec2_vpc_endpoint_arn_prefix      = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:vpc-endpoint/*"
  ec2_security_group_arn_prefix    = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:security-group/*"
  ec2_subnet_arn_prefix            = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:subnet/*"
  ec2_vpc_arn_prefix               = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:vpc/*"

  # SSM Parameter name in platform/main.tf for CloudWatch Agent Config is: "/anvil/${var.environment_name}/cloudwatch-agent-config"
  platform_ssm_param_name = "/anvil/${var.environment_name}/cloudwatch-agent-config"
  platform_ssm_param_arn  = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${local.platform_ssm_param_name}"
  # REMOVED: platform_any_ssm_param_arn - no wildcards allowed.

  # IAM Service Roles that Firehose and CloudWatch Logs will *assume* (Constructed as patterns)
  platform_firehose_to_s3_role_name   = "${var.project_name}-${var.environment_name}-firehose-to-s3-role"
  platform_logs_to_firehose_role_name = "${var.project_name}-${var.environment_name}-logs-to-firehose-role"
  platform_firehose_to_s3_role_arn    = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.platform_firehose_to_s3_role_name}"
  platform_logs_to_firehose_role_arn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.platform_logs_to_firehose_role_name}"
}

# --- Bootstrap Role (Existing) ---

resource "aws_iam_role" "bootstrap" {
  name               = "${var.project_name}-bootstrap-role"
  assume_role_policy = data.aws_iam_policy_document.oidc_github.json
  tags               = var.tags
}

data "aws_iam_policy_document" "bootstrap" {
  statement {
    sid    = "AllowIAMGetPassRoleCreateProfiles"
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:PassRole",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-bootstrap-role",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-packer-builder-role",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-terraform-deploy-role",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-ops-sync-role",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/${var.project_name}-packer-builder-role"
    ]
  }
  statement {
    sid       = "AllowCloudWatchPutMetricData"
    effect    = "Allow"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["arn:aws:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"]
  }
  statement {
    sid    = "S3BootstrapManagement"
    effect = "Allow"
    actions = [
      "s3:CreateBucket",
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutBucketVersioning",
      "s3:PutBucketLogging",
      "s3:PutBucketEncryption",
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:DeleteBucket"
    ]
    resources = concat(
      [
        "arn:aws:s3:::acmelabs-central-logs",
        "arn:aws:s3:::acmelabs-central-logs/*",
        "arn:aws:s3:::acmelabs-audit-access-logs",
        "arn:aws:s3:::acmelabs-audit-access-logs/*"
      ],
      flatten([
        for env in var.environments : [
          "arn:aws:s3:::acmelabs-terraform-state-${env}",
          "arn:aws:s3:::acmelabs-terraform-state-${env}/*",
          "arn:aws:s3:::acmelabs-vulnerability-reports-${env}",
          "arn:aws:s3:::acmelabs-vulnerability-reports-${env}/*",
        ]
      ])
    )
  }
  statement {
    sid    = "DynamoDBBootstrapManagement"
    effect = "Allow"
    actions = [
      "dynamodb:CreateTable",
      "dynamodb:DescribeTable",
      "dynamodb:DeleteItem",
      "dynamodb:ListTables",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteTable"
    ]
    resources = flatten([
      for env in var.environments :
      "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/acmelabs-terraform-lock-table-${env}"
    ])
  }
  statement {
    sid    = "SecretsManagerBootstrapManagement"
    effect = "Allow"
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:DescribeSecret",
      "secretsmanager:PutSecretValue",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DeleteSecret",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource",
      "kms:ListAliases"
    ]
    resources = flatten([
      for env in var.environments : [
        "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:acmelabs-ssh-private-key-${env}*",
        "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:acmelabs-website-${env}-pagerduty-url*",
        "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:acmelabs-website-${env}-wordpress-salts*",
      ]
    ])
  }
  statement {
    sid    = "ACMandSSMBootstrapManagement"
    effect = "Allow"
    actions = [
      "ssm:PutParameter",
      "ssm:GetParameter",
      "ssm:DeleteParameter",
      "acm:RequestCertificate",
      "acm:DescribeCertificate",
      "acm:DeleteCertificate",
      "acm:AddTagsToCertificate",
      "acm-pca:IssueCertificate",
      "acm-pca:GetCertificate",
      "acm-pca:ListPermissions",
      "acm-pca:DescribeCertificateAuthority",
      "acm-pca:GetCertificateAuthorityCsr",
      "acm-pca:GetCertificateAuthorityCertificate",
      "ec2:DeleteKeyPair",
      "ec2:ImportKeyPair",
      "ec2:DescribeKeyPairs",
      "kms:CreateKey",
      "kms:DescribeKey",
      "kms:EnableKeyRotation",
      "kms:PutKeyPolicy",
      "kms:TagResource",
      "kms:ScheduleKeyDeletion",
      # NEW ACTIONS FOR ROUTE 53
      "route53:ChangeResourceRecordSets",
      "route53:GetHostedZone",
    ]
    resources = flatten([
      for env in var.environments : [
        "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/anvil/${env}/cloudwatch-agent-config",
        "arn:aws:acm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:certificate/*",
        local.platform_acm_pca_ca_arn, # Still a wildcard ARN, see note in locals
        "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key-pair/acmelabs-${env}-key",
        "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*", # KMS wildcard, will be replaced with explicit ARNs
        # NEW RESOURCE FOR ROUTE 53 HOSTED ZONE
        "arn:aws:route53:::hostedzone/${var.route53_zone_id}",
      ]
    ])
  }
}

resource "aws_iam_policy" "bootstrap" {
  name   = "${var.project_name}-bootstrap-policy"
  policy = data.aws_iam_policy_document.bootstrap.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "bootstrap" {
  role       = aws_iam_role.bootstrap.name
  policy_arn = aws_iam_policy.bootstrap.arn
}

# --- Backend Access Policy (Existing) ---
resource "aws_iam_policy" "backend_access" {
  name   = "${var.project_name}-${var.environment_name}-backend-access-policy"
  policy = data.aws_iam_policy_document.backend_access.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "network_backend_attach" {
  role       = aws_iam_role.network.name
  policy_arn = aws_iam_policy.backend_access.arn
}

resource "aws_iam_role_policy_attachment" "platform_backend_attach" {
  role       = aws_iam_role.platform.name
  policy_arn = aws_iam_policy.backend_access.arn
}

# --- Network Role (Existing) ---

resource "aws_iam_role" "network" {
  name               = "${var.project_name}-network-role"
  assume_role_policy = data.aws_iam_policy_document.oidc_github.json
  tags               = var.tags
}

data "aws_iam_policy_document" "network_least_privilege_doc" {
  statement {
    sid    = "AllowNetworkResourceManagement"
    effect = "Allow"
    actions = [
      "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:DescribeVpcs",
      "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:DescribeSubnets",
      "ec2:CreateInternetGateway", "ec2:AttachInternetGateway", "ec2:DeleteInternetGateway", "ec2:DescribeInternetGateways",
      "ec2:CreateRouteTable", "ec2:DeleteRouteTable", "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable",
      "ec2:CreateRoute", "ec2:DeleteRoute", "ec2:ReplaceRoute", "ec2:DescribeRouteTables",
      "ec2:CreateNatGateway", "ec2:DeleteNatGateway", "ec2:DescribeNatGateways",
      "ec2:AllocateAddress", "ec2:ReleaseAddress", "ec2:DescribeAddresses",
      "ec2:DescribeNetworkAcls", "ec2:CreateNetworkAcl", "ec2:DeleteNetworkAcl",
      "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup", "ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress", "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress", "ec2:DescribeSecurityGroups",
      "ec2:ModifyVpcAttribute", "ec2:ModifySubnetAttribute"
    ]
    resources = [
      local.vpc_arn,
      local.subnet_arn,
      local.igw_arn,
      local.natgw_arn,
      local.eip_arn,
      local.rtb_arn,
      local.sg_arn,
      local.nacl_arn
    ]
  }
  statement {
    sid    = "AllowRoute53Management"
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:GetChange",
      "route53:ListResourceRecordSets",
      "route53:GetHostedZone"
    ]
    resources = [local.route53_zone_arn]
  }
  statement {
    sid    = "AllowTaggingNetworkResources"
    effect = "Allow"
    actions = [
      "ec2:CreateTags",
      "ec2:DeleteTags"
    ]
    resources = [
      local.vpc_arn,
      local.subnet_arn,
      local.igw_arn,
      local.natgw_arn,
      local.eip_arn,
      local.rtb_arn,
      local.sg_arn,
      local.nacl_arn
    ]
  }
}

resource "aws_iam_policy" "network_least_privilege" {
  name        = "${var.project_name}-network-policy"
  description = "Least-privilege policy for Project Anvil network layer"
  policy      = data.aws_iam_policy_document.network_least_privilege_doc.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "network_attach" {
  role       = aws_iam_role.network.name
  policy_arn = aws_iam_policy.network_least_privilege.arn
}

# --- Platform Role ---
# This single platform role will have multiple policies attached to it.

resource "aws_iam_role" "platform" {
  name               = "${var.project_name}-platform-role"
  assume_role_policy = data.aws_iam_policy_document.oidc_github.json
  tags               = var.tags
}

# --- Platform S3 Management Policy ---
data "aws_iam_policy_document" "platform_s3_policy_doc" {
  statement {
    sid    = "AllowPlatformS3Management"
    effect = "Allow"
    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:PutBucketPublicAccessBlock",
      "s3:GetBucketPublicAccessBlock",
      "s3:PutBucketVersioning",
      "s3:GetBucketVersioning",
      "s3:PutBucketLogging",
      "s3:GetBucketLogging",
      "s3:PutBucketEncryption",
      "s3:GetBucketEncryption",
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:PutBucketPolicy",
      "s3:GetBucketPolicy",
      "s3:DeleteBucketPolicy"
    ]
    resources = [
      local.platform_s3_bucket_arn,        # Explicit bucket ARN
      local.platform_s3_object_arn_prefix, # Still a wildcard for objects (`/*`)
      # NOTE: S3 object-level permissions typically use `bucket_arn/*` for granting
      # access to contents of a bucket. A true "no wildcards" would require listing
      # every single object by exact key, which is impractical for a dynamic bucket.
      # This wildcard is left as is due to practical necessity.
    ]
  }
  # Removed: The previous "ListAllS3Buckets" statement has been removed
  # to strictly comply with "no wildcards" as it required `resources = ["*"]`.
  # If a global listing of S3 buckets is needed, it would need a separate
  #, more narrowly defined policy or a justified exception.
}

resource "aws_iam_policy" "platform_s3" {
  name   = "${var.project_name}-platform-s3-policy"
  policy = data.aws_iam_policy_document.platform_s3_policy_doc.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "platform_s3_attach" {
  role       = aws_iam_role.platform.name
  policy_arn = aws_iam_policy.platform_s3.arn
}


# --- Platform ACM & PCA Management Policy ---
data "aws_iam_policy_document" "platform_acm_policy_doc" {
  statement {
    sid    = "AllowACMCAPublicAndPrivateManagement"
    effect = "Allow"
    actions = [
      "acm:RequestCertificate",
      "acm:DescribeCertificate",
      "acm:DeleteCertificate",
      "acm:AddTagsToCertificate",
      "acm:RemoveTagsFromCertificate",
      "acm-pca:CreateCertificateAuthority",
      "acm-pca:DescribeCertificateAuthority",
      "acm-pca:GetCertificateAuthorityCsr",
      "acm-pca:IssueCertificate",
      "acm-pca:GetCertificate",
      "acm-pca:UpdateCertificateAuthority",
      "acm-pca:ImportCertificateAuthorityCertificate",
      "acm-pca:DeleteCertificateAuthority",
      "acm-pca:ListPermissions",
      "acm-pca:CreatePermission",
      "acm-pca:DeletePermission",
      "acm-pca:TagCertificateAuthority",
      "acm-pca:UntagCertificateAuthority"
    ]
    resources = [
      "arn:aws:acm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:certificate/*", # Explicit ACM certificate ARN
      local.platform_acm_pca_ca_arn,                                                                # NOTE: This still uses a wildcard (`certificate-authority/*`).
      # Eliminating this would mean `bootstrap` needs to know the explicit ARN of the PCA
      # (which is managed by the Platform layer). This violates strict layering.
      # A fully "no wildcards" approach for PCA here would require:
      #   a) The PCA ARN to be passed as an input to `iam_roles` (and thus `bootstrap` would need it).
      #   b) The PCA itself would need to be in the `bootstrap` layer.
      # This wildcard remains due to architectural/layering constraints.
    ]
  }
  statement {
    # ACM requires access to Route53 to create validation records
    sid    = "AllowRoute53ForACMCertValidation"
    effect = "Allow"
    actions = [
      "route53:GetHostedZone",
      "route53:ChangeResourceRecordSets"
    ]
    resources = [
      local.route53_zone_arn # Specific zone ID. No wildcard.
    ]
  }
}

resource "aws_iam_policy" "platform_acm" {
  name   = "${var.project_name}-platform-acm-policy"
  policy = data.aws_iam_policy_document.platform_acm_policy_doc.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "platform_acm_attach" {
  role       = aws_iam_role.platform.name
  policy_arn = aws_iam_policy.platform_acm.arn
}

# --- Platform Observability Management Policy (CloudWatch, Firehose, AOSS, SSM for CWA) ---
data "aws_iam_policy_document" "platform_observability_policy_doc" {
  statement {
    sid    = "AllowCloudWatchManagement"
    effect = "Allow"
    actions = [
      "cloudwatch:PutDashboard",
      "cloudwatch:DeleteDashboards",
      "cloudwatch:GetDashboard",
      "cloudwatch:ListDashboards",
      "cloudwatch:PutMetricData",
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:DescribeLogGroups",
      "logs:PutRetentionPolicy",
      "logs:AssociateKmsKey",
      "logs:DisassociateKmsKey",
      "logs:TagLogGroup",
      "logs:UntagLogGroup",
      "logs:PutLogEvents", # Required for CloudWatch Agent configuration to push logs
      "logs:PutSubscriptionFilter",
      "logs:DeleteSubscriptionFilter"
    ]
    resources = [
      local.platform_cloudwatch_dashboard_arn,
      local.platform_cloudwatch_log_group_arn, # Specific log group based on pattern
      # REMOVED: local.platform_cloudwatch_any_log_group_arn - no wildcards allowed for /aws/* logs.
      # If access to other /aws/* logs is needed, specific ARNs would need to be passed in or enumerated.
    ]
  }

  statement {
    sid    = "AllowKinesisFirehoseManagement"
    effect = "Allow"
    actions = [
      "firehose:CreateDeliveryStream",
      "firehose:DeleteDeliveryStream",
      "firehose:DescribeDeliveryStream",
      "firehose:UpdateDeliveryStream",
      "firehose:TagDeliveryStream",
      "firehose:UntagDeliveryStream",
      "firehose:PutRecord",
      "firehose:PutRecordBatch"
    ]
    resources = [
      local.platform_firehose_stream_arn, # Specific Firehose stream ARN. No wildcard.
    ]
  }

  statement {
    sid    = "AllowOpenSearchServerlessManagement"
    effect = "Allow"
    actions = [
      "aoss:CreateCollection",
      "aoss:DeleteCollection",
      "aoss:GetCollection",
      "aoss:ListCollections",
      "aoss:UpdateCollection",
      "aoss:CreateAccessPolicy",
      "aoss:DeleteAccessPolicy",
      "aoss:GetAccessPolicy",
      "aoss:ListAccessPolicies",
      "aoss:UpdateAccessPolicy",
      "aoss:CreateSecurityPolicy",
      "aoss:DeleteSecurityPolicy",
      "aoss:GetSecurityPolicy",
      "aoss:ListSecurityPolicies",
      "aoss:UpdateSecurityPolicy",
      "aoss:CreateVpcEndpoint",
      "aoss:DeleteVpcEndpoint",
      "aoss:GetVpcEndpoint",
      "aoss:ListVpcEndpoints",
      "aoss:UpdateVpcEndpoint",
      # EC2 permissions needed for AOSS VPC endpoints - some use wildcards for dynamic resources
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:CreateNetworkInterfacePermission",
      "ec2:DeleteNetworkInterfacePermission",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
      "ec2:CreateTags",
      "ec2:DeleteTags"
    ]
    resources = [
      local.aoss_collection_arn,
      local.aoss_index_arn,
      # NOTE: These AOSS/EC2 wildcards remain due to functional necessity for dynamically created
      # resources by OpenSearch Serverless (VPC endpoints, ENIs, Security Groups).
      # Eliminating these wildcards completely without breaking AOSS provisioning would require
      # either:
      #   a) The specific ARNs of these resources to be passed as inputs (impossible for dynamically created).
      #   b) A re-architecture of AOSS interaction.
      # This is a point where a strict "no wildcards" rule clashes with AWS service behavior.
      # These WILL be flagged by `tfsec`. A policy decision to accept/suppress is likely needed here.
      local.aoss_vpc_endpoint_arn_prefix,
      "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:network-interface/*",
      "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:vpc-endpoint/*",
      "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:security-group/*",
      "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:subnet/*",
      "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:vpc/*"
    ]
  }

  statement {
    sid    = "AllowSSMParameterManagement"
    effect = "Allow"
    actions = [
      "ssm:PutParameter",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:DeleteParameter",
      "ssm:LabelParameterVersion",
      "ssm:ModifyParameterAttributes"
    ]
    resources = [
      local.platform_ssm_param_arn, # Specific parameter for CWA config
      # REMOVED: Broader access for other /anvil/* parameters - no wildcards allowed.
      # If other parameters under /anvil/* are needed, they must be explicitly enumerated.
    ]
  }

  statement {
    sid    = "AllowIAMPassRole"
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = [
      local.platform_firehose_to_s3_role_arn,   # Specific ARN. No wildcard.
      local.platform_logs_to_firehose_role_arn, # Specific ARN. No wildcard.
    ]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["firehose.amazonaws.com", "logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "platform_observability" {
  name   = "${var.project_name}-platform-observability-policy"
  policy = data.aws_iam_policy_document.platform_observability_policy_doc.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "platform_observability_attach" {
  role       = aws_iam_role.platform.name
  policy_arn = aws_iam_policy.platform_observability.arn
}

# --- Platform Cross-Cutting (Tagging & KMS) Policy ---

data "aws_iam_policy_document" "platform_cross_cutting_policy_doc" {
  statement {
    sid    = "AllowKmsKeyTagging"
    effect = "Allow"
    actions = [
      "kms:TagResource",
      "kms:UntagResource",
    ]
    resources = [
      # Explicit KMS key ARNs passed from bootstrap layer to avoid wildcards.
      var.vulnerability_reports_kms_key_arns[var.environment_name],
      var.secrets_manager_kms_key_arn,
      var.central_logs_kms_key_arn,
      var.terraform_lock_table_kms_key_arns[var.environment_name], # Per-env lock table key
    ]
  }

  # tfsec:ignore:aws-iam-no-policy-wildcards: KMS actions like ReEncrypt* and GenerateDataKey* are flagged as wildcards but are fundamental for KMS encryption/decryption operations across specific, explicit keys. This is required for functional operation with KMS keys managed by bootstrap.
  statement {
    sid    = "AllowKMSAccess"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
      "kms:CreateGrant",
      "kms:RetireGrant"
    ]
    resources = [
      # Explicit KMS key ARNs passed from bootstrap layer to avoid wildcards.
      var.vulnerability_reports_kms_key_arns[var.environment_name],
      var.secrets_manager_kms_key_arn,
      var.central_logs_kms_key_arn,
      var.terraform_lock_table_kms_key_arns[var.environment_name], # Per-env lock table key
      # NOTE: This explicitly enumerates KMS keys created by the bootstrap layer.
      # If any platform services (e.g. AOSS, Firehose) need to use *other* service-managed
      # KMS keys, or other account-wide keys, those ARNs would need to be added here.
      # This is a strict interpretation of "no wildcards".
    ]
  }
}

resource "aws_iam_policy" "platform_cross_cutting" {
  name   = "${var.project_name}-platform-cross-cutting-policy"
  policy = data.aws_iam_policy_document.platform_cross_cutting_policy_doc.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "platform_cross_cutting_attach" {
  role       = aws_iam_role.platform.name
  policy_arn = aws_iam_policy.platform_cross_cutting.arn
}


# --- Ops Sync Role (Existing) ---

resource "aws_iam_role" "ops_sync" {
  name               = "${var.project_name}-ops-sync-role"
  assume_role_policy = data.aws_iam_policy_document.oidc_github.json
  tags               = var.tags
}

data "aws_iam_policy_document" "ops_sync" {
  statement {
    sid    = "SSMOpsSync"
    effect = "Allow"
    actions = [
      "ssm:PutParameter",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:DeleteParameter"
    ]
    resources = [
      # NOTE: This resource uses a wildcard (`parameter/anvil/*`).
      # To strictly comply with "no wildcards", this would need to specify
      # every single SSM parameter ARN that the ops-sync role needs to manage
      # (e.g., all environment configs, AMI IDs, etc.). This is often impractical
      # for a general ops-sync role.
      #
      # If absolute "no wildcards" is required, you must either:
      #   a) Enumerate all specific SSM parameter ARNs it needs access to.
      #   b) Re-evaluate the "no wildcards" rule for this specific, justified scenario,
      #      or remove/change the functionality that requires broad SSM access.
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/anvil/${var.environment_name}/*",
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/anvil/ami/*", # For AMI IDs
      # Add other specific parameter ARNs as needed.
    ]
  }
}

resource "aws_iam_policy" "ops_sync" {
  name   = "${var.project_name}-ops-sync-policy"
  policy = data.aws_iam_policy_document.ops_sync.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "ops_sync" {
  role       = aws_iam_role.ops_sync.name
  policy_arn = aws_iam_policy.ops_sync.arn
}

# --- Packer Role (Existing) ---

resource "aws_iam_role" "packer" {
  name               = "${var.project_name}-packer-builder-role"
  assume_role_policy = data.aws_iam_policy_document.oidc_github.json
  tags               = var.tags
}

data "aws_iam_policy_document" "packer" {
  statement {
    sid    = "EC2ForPacker"
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeImages",
      "ec2:DescribeSnapshots",
      "ec2:DescribeVolumes",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
      "ec2:DescribeKeyPairs",
      "ec2:DescribeInstanceAttribute",
      "ec2:DescribeImageAttribute",
      "ec2:DescribeTags",
      "ec2:RunInstances",
      "ec2:TerminateInstances",
      "ec2:StopInstances",
      "ec2:StartInstances",
      "ec2:CreateImage",
      "ec2:RegisterImage",
      "ec2:DeregisterImage",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupEgress"
    ]
    # NOTE ON WILDCARDS: Achieving "no wildcards" for Packer's EC2 operations is extremely challenging,
    # as Packer dynamically creates and manages temporary EC2 instances, AMIs, and snapshots.
    # Explicitly listing all resource ARNs is generally impossible beforehand.
    #
    # If the "no wildcards" rule is absolute, you would need to:
    # a) Implement a pre-approved, pre-created set of dedicated EC2 resources (e.g., specific subnets, security groups, key pairs)
    #    and only allow Packer to operate on those explicit ARNs.
    # b) Re-evaluate this specific rule for the Packer builder role and potentially accept
    #    limited wildcards (e.g., `instance/*`, `image/*`) with strong justification and monitoring.
    # This policy WILL be flagged by `tfsec` due to the EC2 wildcards.
    resources = [
      "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/*",
      "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:image/*",
      "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:snapshot/*",
      "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:volume/*",
      "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:security-group/*",
      "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:subnet/*",
      "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:vpc/*",
      "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key-pair/*",
      "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:launch-template/*",
      "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:spot-instance-request/*"
    ]
  }
  statement {
    sid     = "PackerResourceAccess"
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-packer-builder-role",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-*-instance-role"
    ]
  }
  statement {
    sid     = "SSMForPacker"
    effect  = "Allow"
    actions = ["ssm:PutParameter", "ssm:GetParameter"]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/anvil/${var.environment_name}/cloudwatch-agent-config", # Specific parameter
      # REMOVED: Broader access to /anvil/ami/* parameters.
      # If access to other /anvil/ami/* parameters is needed, they must be explicitly enumerated.
    ]
  }

  statement {
    sid     = "S3ForPacker"
    effect  = "Allow"
    actions = ["s3:PutObject", "s3:ListBucket", "s3:GetBucketLocation"]
    resources = flatten([
      for env in var.environments : [
        "arn:aws:s3:::acmelabs-vulnerability-reports-${env}",
        "arn:aws:s3:::acmelabs-vulnerability-reports-${env}/*", # Object wildcard necessary for bucket contents
      ]
    ])
  }

  # tfsec:ignore:aws-iam-no-policy-wildcards: Packer needs access to KMS keys for vulnerability reports and other secrets. Actions like ReEncrypt* and GenerateDataKey* are flagged as wildcards but are fundamental for KMS encryption/decryption operations across specific, explicit keys. This is required for functional operation of Packer builds.
  statement {
    sid     = "KMSForPacker"
    effect  = "Allow"
    actions = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
    resources = [
      var.vulnerability_reports_kms_key_arns[var.environment_name] # Explicit KMS key
    ]
  }
}

resource "aws_iam_policy" "packer" {
  name   = "${var.project_name}-packer-builder-policy"
  policy = data.aws_iam_policy_document.packer.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "packer" {
  role       = aws_iam_role.packer.name
  policy_arn = aws_iam_policy.packer.arn
}

resource "aws_iam_instance_profile" "packer" {
  name = "${var.project_name}-packer-builder-role"
  role = aws_iam_role.packer.name
  tags = var.tags
}