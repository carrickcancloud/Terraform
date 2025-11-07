#!/bin/bash
set -euo pipefail

ENV_NAME="$1"
AWS_REGION="$2"

echo "--- Starting KMS State Migration Script for environment: $ENV_NAME ---"

# Change to the bootstrap directory where the Terraform configuration resides
# This is crucial for terraform commands to find the state file and config
cd bootstrap

# --- Migrate aws_kms_key.vulnerability_reports ---
OLD_KEY_TF_ADDRESS="aws_kms_key.vulnerability_reports"
NEW_KEY_TF_ADDRESS="aws_kms_key.vulnerability_reports[\"$ENV_NAME\"]"

echo "Checking for old KMS key resource: $OLD_KEY_TF_ADDRESS"
if terraform state list | grep -q "^$OLD_KEY_TF_ADDRESS$"; then
  echo "Found '$OLD_KEY_TF_ADDRESS' in Terraform state."
  
  echo "DEBUG: Attempting to show state for $OLD_KEY_TF_ADDRESS"
  RAW_STATE_SHOW_OUTPUT=$(terraform state show "$OLD_KEY_TF_ADDRESS" 2>&1 || true)
  echo "DEBUG: Raw 'terraform state show' output for '$OLD_KEY_TF_ADDRESS':"
  echo "---START RAW OUTPUT---"
  echo "$RAW_STATE_SHOW_OUTPUT"
  echo "---END RAW OUTPUT---"
  
  # --- MODIFIED EXTRACTION LOGIC FOR ID ---
  # Directly extract the ID from the line containing "id =" and clean it up.
  OLD_KMS_KEY_ID=$(echo "$RAW_STATE_SHOW_OUTPUT" | grep -E '^\s*id\s*=\s*".*"' | head -n 1 | cut -d'=' -f2- | tr -d '[:space:]"')
  OLD_KMS_KEY_ID=${OLD_KMS_KEY_ID//\"/} # Remove all double quotes
  # ----------------------------------------
  
  echo "DEBUG: Extracted OLD_KMS_KEY_ID: '${OLD_KMS_KEY_ID}'" # Debug the extracted ID
  
  if [ -n "$OLD_KMS_KEY_ID" ]; then
    echo "Identified AWS KMS Key ID: $OLD_KMS_KEY_ID"
    if aws kms describe-key --key-id "$OLD_KMS_KEY_ID" --region "$AWS_REGION" &>/dev/null; then
      echo "AWS KMS Key $OLD_KMS_KEY_ID exists. Performing state migration..."
      terraform state mv "$OLD_KEY_TF_ADDRESS" "$NEW_KEY_TF_ADDRESS"
      echo "SUCCESS: Migrated Terraform state address from '$OLD_KEY_TF_ADDRESS' to '$NEW_KEY_TF_ADDRESS'."
    else
      echo "WARNING: AWS KMS Key $OLD_KMS_KEY_ID (from state address '$OLD_KEY_TF_ADDRESS') not found in AWS. Assuming it was manually deleted. Removing from Terraform state."
      terraform state rm "$OLD_KEY_TF_ADDRESS"
    fi
  else
    echo "ERROR: Could not extract AWS KMS Key ID from old state for '$OLD_KEY_TF_ADDRESS'. This might happen if 'terraform state show' returned an error or unexpected format."
    echo "       Please examine the '---START RAW OUTPUT---' above for clues."
    exit 1 # Exit with error since we couldn't proceed with key migration
  fi
else
  echo "Old KMS key resource '$OLD_KEY_TF_ADDRESS' not found in state. No migration needed for this key."
fi

echo "" # Add a newline for readability

# --- Migrate aws_kms_alias.vulnerability_reports ---
OLD_ALIAS_TF_ADDRESS="aws_kms_alias.vulnerability_reports"
NEW_ALIAS_TF_ADDRESS="aws_kms_alias.vulnerability_reports[\"$ENV_NAME\"]"

echo "Checking for old KMS alias resource: $OLD_ALIAS_TF_ADDRESS"
if terraform state list | grep -q "^$OLD_ALIAS_TF_ADDRESS$"; then
  echo "Found '$OLD_ALIAS_TF_ADDRESS' in Terraform state."
  
  echo "DEBUG: Attempting to show state for $OLD_ALIAS_TF_ADDRESS"
  RAW_STATE_SHOW_OUTPUT=$(terraform state show "$OLD_ALIAS_TF_ADDRESS" 2>&1 || true)
  echo "DEBUG: Raw 'terraform state show' output for '$OLD_ALIAS_TF_ADDRESS':"
  echo "---START RAW OUTPUT---"
  echo "$RAW_STATE_SHOW_OUTPUT"
  echo "---END RAW OUTPUT---"

  # --- MODIFIED EXTRACTION LOGIC FOR NAME ---
  # Directly extract the name from the line containing "name =" and clean it up.
  OLD_KMS_ALIAS_NAME=$(echo "$RAW_STATE_SHOW_OUTPUT" | grep -E '^\s*name\s*=\s*".*"' | head -n 1 | cut -d'=' -f2- | tr -d '[:space:]"')
  OLD_KMS_ALIAS_NAME=${OLD_KMS_ALIAS_NAME//\"/} # Remove all double quotes
  # ------------------------------------------
  
  echo "DEBUG: Extracted OLD_KMS_ALIAS_NAME: '${OLD_KMS_ALIAS_NAME}'" # Debug the extracted name
  
  if [ -n "$OLD_KMS_ALIAS_NAME" ]; then
    echo "Identified AWS KMS Alias Name: $OLD_KMS_ALIAS_NAME"
    if aws kms describe-key --key-id "$OLD_KMS_ALIAS_NAME" --region "$AWS_REGION" &>/dev/null; then
      echo "AWS KMS Alias $OLD_KMS_ALIAS_NAME exists. Performing state migration..."
      terraform state mv "$OLD_ALIAS_TF_ADDRESS" "$NEW_ALIAS_TF_ADDRESS"
      echo "SUCCESS: Migrated Terraform state address from '$OLD_ALIAS_TF_ADDRESS' to '$NEW_ALIAS_TF_ADDRESS'."
    else
      echo "WARNING: AWS KMS Alias $OLD_KMS_ALIAS_NAME (from state address '$OLD_ALIAS_TF_ADDRESS') not found in AWS. Assuming it was manually deleted. Removing from Terraform state."
      terraform state rm "$OLD_ALIAS_TF_ADDRESS"
    fi
  else
    echo "ERROR: Could not extract AWS KMS Alias Name from old state for '$OLD_ALIAS_TF_ADDRESS'. This might happen if 'terraform state show' returned an error or unexpected format."
    echo "       Please examine the '---START RAW OUTPUT---' above for clues."
    exit 1 # Exit with error since we couldn't proceed with alias migration
  fi
else
  echo "Old KMS alias resource '$OLD_ALIAS_TF_ADDRESS' not found in state. No migration needed for this alias."
fi

echo "" # Add a newline for readability
echo "--- KMS State Migration Script Finished ---"