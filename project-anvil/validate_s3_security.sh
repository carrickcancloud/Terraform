#!/bin/bash

# ==============================================================================
# S3 Bucket Security Validator
#
# This script checks all S3 buckets managed by the Project Anvil bootstrap
# layer to ensure they meet the required security standards for:
#   1. Public Access Block
#   2. Server-Side Encryption (AES256 or KMS)
#   3. Bucket Versioning
#   4. Access Logging
#
# Usage:
#   ./validate_s3_security.sh <environment> [aws-region]
#
# Example:
#   ./validate_s3_security.sh dev us-east-1
# ==============================================================================

set -e

# --- Configuration ---
ENVIRONMENT=$1
REGION=${2:-us-east-1} # Default to us-east-1 if not provided

# Check for environment argument
if [ -z "$ENVIRONMENT" ]; then
  echo "Error: Missing required argument."
  echo "Usage: $0 <environment> [aws-region]"
  echo "Example: $0 dev us-east-1"
  exit 1
fi

# --- List of Buckets to Validate ---
# These names must match what is defined in your Terraform code.
BUCKETS_TO_CHECK=(
  "acmelabs-terraform-state-bootstrap-${ENVIRONMENT}"
  "acmelabs-terraform-state-network-${ENVIRONMENT}"
  "acmelabs-terraform-state-platform-${ENVIRONMENT}"
  "acmelabs-terraform-state-apps-${ENVIRONMENT}"
  "acmelabs-vulnerability-reports-${ENVIRONMENT}"
  "acmelabs-central-logs"
  "acmelabs-central-logs-self-access-logs"
  "acmelabs-audit-access-logs"
)

# --- Main Validation Logic ---
echo "--- Starting S3 Bucket Security Validation for environment: '$ENVIRONMENT' in region: '$REGION' ---"
echo "======================================================================================"
EXIT_CODE=0

for BUCKET_NAME in "${BUCKETS_TO_CHECK[@]}"; do
  echo "Checking bucket: $BUCKET_NAME"

  # Check if bucket exists first
  if ! aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$REGION" 2>/dev/null; then
    echo -e "\033[0;31m  [✗] FAILED: Bucket does not exist or you don't have permission to access it.\033[0m"
    EXIT_CODE=1
    echo "--------------------------------------------------------------------------------------"
    continue # Skip to the next bucket
  fi

  # 1. Check Public Access Block
  PAB=$(aws s3api get-public-access-block --bucket "$BUCKET_NAME" --region "$REGION" --query "PublicAccessBlockConfiguration" --output json)
  if ! (echo "$PAB" | jq -e '.BlockPublicAcls == true and .IgnorePublicAcls == true and .BlockPublicPolicy == true and .RestrictPublicBuckets == true'); then
    echo -e "\033[0;31m  [✗] Public Access Block is NOT correctly configured.\033[0m"
    EXIT_CODE=1
  else
    echo -e "\033[0;32m  [✓] Public Access Block is correctly configured.\033[0m"
  fi

  # 2. Check Server-Side Encryption
  ENCRYPTION=$(aws s3api get-bucket-encryption --bucket "$BUCKET_NAME" --region "$REGION" --query "ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm" --output text 2>/dev/null)
  if [[ "$ENCRYPTION" != "AES256" && "$ENCRYPTION" != "aws:kms" ]]; then
    echo -e "\033[0;31m  [✗] Server-Side Encryption is NOT enabled or is not AES256/aws:kms.\033[0m"
    EXIT_CODE=1
  else
    echo -e "\033[0;32m  [✓] Server-Side Encryption is enabled ($ENCRYPTION).\033[0m"
  fi

  # 3. Check Bucket Versioning
  VERSIONING=$(aws s3api get-bucket-versioning --bucket "$BUCKET_NAME" --region "$REGION" --query "Status" --output text)
  if [[ "$VERSIONING" != "Enabled" ]]; then
    echo -e "\033[0;31m  [✗] Bucket Versioning is NOT enabled.\033[0m"
    EXIT_CODE=1
  else
    echo -e "\033[0;32m  [✓] Bucket Versioning is enabled.\033[0m"
  fi

  # 4. Check Access Logging
  LOGGING=$(aws s3api get-bucket-logging --bucket "$BUCKET_NAME" --region "$REGION" --query "LoggingEnabled.TargetBucket" --output text)
  if [[ "$LOGGING" == "None" || -z "$LOGGING" ]]; then
    echo -e "\033[0;31m  [✗] Access Logging is NOT enabled.\033[0m"
    EXIT_CODE=1
  else
    echo -e "\033[0;32m  [✓] Access Logging is enabled (Target: $LOGGING).\033[0m"
  fi

  echo "--------------------------------------------------------------------------------------"
done

# --- Final Result ---
if [ "$EXIT_CODE" -ne 0 ]; then
  echo -e "\n\033[0;31mValidation FAILED: One or more S3 buckets did not pass the security checks.\033[0m"
  exit 1
else
  echo -e "\n\033[0;32mValidation SUCCESS: All S3 buckets passed the security checks.\033[0m"
fi

