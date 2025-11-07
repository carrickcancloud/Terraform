# ==============================================================================
# Project Anvil - Application Layer (UAT Environment)
# backend.tf
#
# Backend configuration for storing the Terraform state for the uat application
# layer. This file explicitly defines the S3 bucket and DynamoDB table where
# this environment's state will be stored and locked.
#
# IMPORTANT: Variables (`var.*`) cannot be used directly within the 'backend' block
# as Terraform needs to initialize the backend *before* evaluating any variables.
#
# To dynamically configure the backend (e.g., per environment), these values MUST
# be provided via 'terraform init -backend-config=...' flags or environment variables.
# Your GitHub Actions workflow already does this correctly.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-06 - Corrected backend configuration due to Terraform variable limitation.
# ==============================================================================

terraform {
  backend "s3" {
    # These values are intentionally left blank here.
    # They MUST be provided during 'terraform init' using '-backend-config' flags
    # from your CI/CD pipeline (e.g., GitHub Actions workflow) or a local .tfbackend file.
    # Attempting to use 'var.*' directly here will result in a "Variables not allowed" error.
    #
    # Your CI/CD workflow (e.g., 5-deploy-app-uat.yml) passes these dynamically:
    # terraform init \
    #   -backend-config="bucket=${APPS_BUCKET_NAME}" \
    #   -backend-config="key=${APPS_KEY}" \
    #   -backend-config="region=${AWS_REGION}" \
    #   -backend-config="dynamodb_table=${APPS_DDB_TABLE_NAME}" \
    #   -backend-config="encrypt=true"
  }
}
