#!/bin/bash -e
# This script runs periodically via cron to renew internal TLS certificates
# issued by AWS Private CA. It re-uses the private key for renewal.

# --- Configuration (Injected by instance_setup.sh.tpl when copying) ---
# These are placeholders. The instance_setup.sh.tpl script will replace them.
PCA_ARN="PLACEHOLDER_PCA_ARN"
AWS_REGION="PLACEHOLDER_AWS_REGION"
CERT_DIR="/etc/ssl/acme_internal"
RENEWAL_WINDOW_DAYS=30             # Renew if cert expires in less than 30 days
SERVICE_TO_RELOAD="PLACEHOLDER_SERVICE_TO_RELOAD" # e.g., 'nginx' or 'php8.3-fpm'

# --- Helper Functions ---
log_message() {
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [RENEW_CERT_SCRIPT] $1"
}

# Function to get Common Name from existing certificate
get_common_name_from_cert() {
  if [ -f "$CERT_DIR/cert.pem" ]; then
    sudo openssl x509 -in "$CERT_DIR/cert.pem" -subject -noout | sed -n '/CN=/s/.*CN=\([^/]*\).*/\1/p'
  else
    echo ""
  fi
}

# Function to request and install new certificate
request_and_install_cert() {
  local common_name="$1"
  log_message "Requesting new certificate for CN: $common_name from PCA: $PCA_ARN"

  # Ensure private key exists
  if [ ! -f "$CERT_DIR/private/privkey.pem" ]; then
    log_message "Error: Private key not found at $CERT_DIR/private/privkey.pem. Cannot renew." >&2
    return 1
  fi

  # Generate CSR using existing private key
  sudo openssl req -new -key "$CERT_DIR/private/privkey.pem" -out /tmp/renewal.csr \
    -subj "/C=US/ST=AcmeState/L=AcmeCity/O=AcmeLabs/OU=AcmeDept/CN=$common_name"

  # Request certificate from Private CA
  CERTIFICATE_ARN=$(aws acm-pca issue-certificate \
    --certificate-authority-arn "$PCA_ARN" \
    --csr "fileb:///tmp/renewal.csr" \
    --signing-algorithm "SHA256WITHRSA" \
    --validity "Value=365,Type=DAYS" \
    --region "$AWS_REGION" \
    --query 'CertificateArn' --output text 2>&1)

  if [ -z "$CERTIFICATE_ARN" ] || [[ "$CERTIFICATE_ARN" == *"Error"* ]]; then
    log_message "Error: Failed to request certificate from ACM PCA: $CERTIFICATE_ARN" >&2
    return 1
  fi
  log_message "Certificate request submitted. ARN: $CERTIFICATE_ARN"

  # Wait for certificate to be issued and retrieve it
  local MAX_WAIT_ATTEMPTS=60 # 5 minutes total (60 * 5s)
  local ATTEMPT=0
  local CERT_CHAIN_JSON=""

  while [ "$ATTEMPT" -lt "$MAX_WAIT_ATTEMPTS" ]; do
      ATTEMPT=$((ATTEMPT + 1))
      CERT_CHAIN_JSON=$(aws acm-pca get-certificate \
        --certificate-authority-arn "$PCA_ARN" \
        --certificate-arn "$CERTIFICATE_ARN" \
        --region "$AWS_REGION" \
        --query '{Certificate:Certificate,CertificateChain:CertificateChain}' --output json 2>&1)
      
      # Check if certificate is present in the JSON response
      if echo "$CERT_CHAIN_JSON" | jq -e '.Certificate' > /dev/null; then
          log_message "Certificate received after $ATTEMPT attempts."
          break
      fi
      log_message "Still waiting for certificate issuance... (Attempt $ATTEMPT/$MAX_WAIT_ATTEMPTS)"
      sleep 5
  done
  
  if ! echo "$CERT_CHAIN_JSON" | jq -e '.Certificate' > /dev/null; then
    log_message "Error: Certificate not issued within timeout." >&2
    return 1
  fi

  # Install the new certificate and chain
  echo "$CERT_CHAIN_JSON" | jq -r '.Certificate' | sudo tee "$CERT_DIR/cert.pem" > /dev/null
  echo "$CERT_CHAIN_JSON" | jq -r '.CertificateChain' | sudo tee "$CERT_DIR/chain.pem" > /dev/null

  rm /tmp/renewal.csr # Clean up temporary CSR file
  log_message "Certificate installation complete. Certs saved to $CERT_DIR"
  return 0
}

# --- Main Execution Flow ---
log_message "Starting certificate renewal check."

# Get common name from existing certificate. If no cert found, exit.
COMMON_NAME=$(get_common_name_from_cert)
if [ -z "$COMMON_NAME" ]; then
  log_message "No existing certificate found or common name could not be extracted. Exiting."
  exit 0
fi

# Get certificate expiration date
EXPIRY_DATE_UNIX=$(sudo openssl x509 -in "$CERT_DIR/cert.pem" -enddate -noout | cut -d'=' -f2 | xargs -I {} date -d {} +%s)
CURRENT_DATE_UNIX=$(date +%s)

# Calculate days until expiry
DAYS_TO_EXPIRY=$(( (EXPIRY_DATE_UNIX - CURRENT_DATE_UNIX) / 86400 ))

log_message "Certificate ($COMMON_NAME) expires in $DAYS_TO_EXPIRY days."

# Check if within renewal window
if [ "$DAYS_TO_EXPIRY" -le "$RENEWAL_WINDOW_DAYS" ]; then
  log_message "Certificate is within renewal window ($RENEWAL_WINDOW_DAYS days). Attempting renewal..."
  
  if request_and_install_cert "$COMMON_NAME"; then
    log_message "Certificate renewed successfully. Reloading $SERVICE_TO_RELOAD service..."
    # Reload the service to use the new certificate
    if systemctl is-active --quiet "$SERVICE_TO_RELOAD"; then
      sudo systemctl reload "$SERVICE_TO_RELOAD"
    else
      log_message "Warning: Service $SERVICE_TO_RELOAD is not active, cannot reload. Manual intervention may be required." >&2
    fi
  else
    log_message "Certificate renewal FAILED. Please investigate." >&2
    exit 1
  fi
else
  log_message "Certificate is not yet in renewal period. Exiting."
fi

log_message "Certificate renewal script finished."
