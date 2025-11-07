#!/bin/bash
set -e

ENV=dev
AWS_REGION=us-east-1
PROJECT=acmelabs-website

# S3 Buckets (central + dev)
S3_BUCKETS=(
  "acmelabs-terraform-state-bootstrap-$ENV"
  "acmelabs-central-logs"
  "acmelabs-central-logs-self-access-logs"
  "acmelabs-audit-access-logs"
  "acmelabs-vulnerability-reports-$ENV"
)

# DynamoDB Table
DDB_TABLE="acmelabs-terraform-lock-table-bootstrap-$ENV"
DBD_ENV_TABLE="acmelabs-terraform-lock-table-$ENV"

# SSM Parameter
SSM_PARAM="/anvil/$ENV/cloudwatch-agent-config"

# ACM Certificate (Wildcard)
ACM_DOMAIN="*.${ENV}.acmelabs.cloud"

# EC2 Key Pair
KEYPAIR="acmelabs-$ENV-key"

# IAM Roles/Policies/Instance Profiles (project-wide)
IAM_ROLES=(
  "${PROJECT}-bootstrap-role"
  "${PROJECT}-packer-builder-role"
  "${PROJECT}-terraform-deploy-role"
  "${PROJECT}-ops-sync-role"
)

IAM_POLICIES=(
  "${PROJECT}-bootstrap-policy"
  "${PROJECT}-packer-builder-policy"
  "${PROJECT}-terraform-deploy-policy-part1"
  "${PROJECT}-terraform-deploy-policy-part2"
  "${PROJECT}-terraform-deploy-policy-part3"
  "${PROJECT}-ops-sync-policy"
)

IAM_INSTANCE_PROFILES=(
  "${PROJECT}-packer-builder-role"
)

echo "=== Deleting S3 Buckets ==="
for BUCKET in "${S3_BUCKETS[@]}"; do
  echo "Emptying and deleting bucket: $BUCKET"
  # Remove all objects (including versions, if versioned)
  aws s3api list-object-versions --bucket "$BUCKET" --region "$AWS_REGION" \
    | jq -r '.Versions[]?, .DeleteMarkers[]? | [.Key, .VersionId] | @tsv' \
    | while read -r Key VersionId; do
        aws s3api delete-object --bucket "$BUCKET" --key "$Key" --version-id "$VersionId" --region "$AWS_REGION"
      done || true
  aws s3 rb "s3://$BUCKET" --force --region "$AWS_REGION" || true
done

echo "=== Deleting DynamoDB Tables ==="
aws dynamodb delete-table --table-name "$DDB_TABLE" --region "$AWS_REGION" || true
aws dynamodb delete-table --table-name "$DBD_ENV_TABLE" --region "$AWS_REGION" || true

echo "=== Deleting SSM Parameter ==="
aws ssm delete-parameter --name "$SSM_PARAM" --region "$AWS_REGION" || true

echo "=== Deleting EC2 Key Pair ==="
aws ec2 delete-key-pair --key-name "$KEYPAIR" --region "$AWS_REGION" || true

echo "=== Deleting ACM Certificate (Wildcard) ==="
ACM_ARN=$(aws acm list-certificates --region "$AWS_REGION" \
  --query "CertificateSummaryList[?DomainName=='$ACM_DOMAIN'].CertificateArn" --output text)
if [ -n "$ACM_ARN" ]; then
  aws acm delete-certificate --certificate-arn "$ACM_ARN" --region "$AWS_REGION" || true
else
  echo "ACM certificate for $ACM_DOMAIN not found."
fi

echo "=== Deleting IAM Roles, Policies, and Instance Profiles ==="
for ROLE in "${IAM_ROLES[@]}"; do
  echo "Processing role: $ROLE"
  for POLICY_ARN in $(aws iam list-attached-role-policies --role-name "$ROLE" --query "AttachedPolicies[].PolicyArn" --output text 2>/dev/null); do
    echo " Detaching policy: $POLICY_ARN"
    aws iam detach-role-policy --role-name "$ROLE" --policy-arn "$POLICY_ARN" || true
  done
  for POLICY_NAME in $(aws iam list-role-policies --role-name "$ROLE" --query "PolicyNames[]" --output text 2>/dev/null); do
    echo " Deleting inline policy: $POLICY_NAME"
    aws iam delete-role-policy --role-name "$ROLE" --policy-name "$POLICY_NAME" || true
  done
done

for PROFILE in "${IAM_INSTANCE_PROFILES[@]}"; do
  echo "Deleting instance profile: $PROFILE"
  for ROLE in $(aws iam get-instance-profile --instance-profile-name "$PROFILE" --query "InstanceProfile.Roles[].RoleName" --output text 2>/dev/null); do
    aws iam remove-role-from-instance-profile --instance-profile-name "$PROFILE" --role-name "$ROLE" || true
  done
  aws iam delete-instance-profile --instance-profile-name "$PROFILE" || true
done

for ROLE in "${IAM_ROLES[@]}"; do
  echo "Deleting role: $ROLE"
  aws iam delete-role --role-name "$ROLE" || true
done

for POLICY in "${IAM_POLICIES[@]}"; do
  POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$POLICY'].Arn" --output text)
  if [ -n "$POLICY_ARN" ]; then
    echo "Deleting policy: $POLICY ($POLICY_ARN)"
    aws iam delete-policy --policy-arn "$POLICY_ARN" || true
  fi
done

echo "=== DONE ==="
echo "Secrets Manager secrets and KMS keys require manual/scheduled deletion and are NOT deleted by this script."
