#!/bin/bash -e
# This script runs on EC2 instance boot-up. It configures the instance dynamically,
# including internal TLS, X-Ray daemon setup, and WordPress database configuration.

echo "--- Starting instance_setup.sh script ---"

# --- Terraform Injected Variables ---
# These values are passed by Terraform's templatefile() function.
PCA_ARN="${certificate_authority_arn}"
AWS_REGION="${aws_region}"
CMS_NAME="${cms_name}"
CMS_VERSION="${cms_version}"
ENV="${env}"
DOMAIN_NAME="${domain_name}"
APP_TIER_DNS="${app_tier_dns}" # Only for web tier to talk to app tier
DB_ENDPOINT="${db_endpoint}"   # Only for app tier
DB_PORT="${db_port}"           # Only for app tier
DB_NAME="${db_name}"           # Only for app tier
DB_USERNAME="${db_username}"   # Only for app tier
XRAY_ENABLED="${xray_enabled}" # Boolean 'true' or 'false'
DB_PASSWORD_SECRET_ARN="${db_password_secret_arn}" # Only for app tier
WP_SALTS_SECRET_ARN="${wp_salts_secret_arn}" # Only for app tier
# RUM_APP_MONITOR_SCRIPT="${rum_app_monitor_script}" # For future RUM integration (JS snippet)

# --- Constants ---
CERT_DIR="/etc/ssl/acme_internal"
APP_DIR="/var/www/wordpress" # Standard WordPress app location
NGINX_CONF_PATH="/etc/nginx/sites-available/default"
PHP_FPM_WWW_CONF="/etc/php/8.3/fpm/pool.d/www.conf" # Assuming PHP 8.3-fpm (adjust if different)
WORDPRESS_CONFIG_FILE="$APP_DIR/wp-config.php"

# --- Helper Functions ---
log_message() {
  echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [INSTANCE_SETUP] $1"
}

# Function to get instance ID (needed for common name)
get_instance_id() {
  curl -s http://169.254.169.254/latest/meta-data/instance-id
}

# Function to setup X-Ray Daemon (Install & Start)
setup_xray_daemon() {
  if [[ "$XRAY_ENABLED" == "true" ]]; then
    log_message "--- Setting up X-Ray Daemon ---"
    # Install X-Ray Daemon for Ubuntu (replace with yum/dnf for RHEL-based)
    wget https://s3.amazonaws.com/aws-xray-assets.us-east-1/xray-daemon/aws-xray-daemon-3.x.deb -O /tmp/aws-xray-daemon.deb
    sudo dpkg -i /tmp/aws-xray-daemon.deb
    rm /tmp/aws-xray-daemon.deb
    sudo systemctl enable xray
    sudo systemctl start xray
    log_message "X-Ray Daemon setup complete."
  else
    log_message "X-Ray Daemon not enabled. Skipping setup."
  fi
}

# Function to request and install initial internal TLS certificate
install_initial_tls() {
  local common_name_base="$1" # Base name for the cert (e.g., internal-web.dev)
  local instance_id=$(get_instance_id)
  local cert_cn="internal-$instance_id.$common_name_base.$DOMAIN_NAME" # Full CN

  log_message "--- Installing initial internal TLS certificate for CN: $cert_cn ---"

  sudo mkdir -p "$CERT_DIR/private"
  sudo chmod 700 "$CERT_DIR/private"

  # Generate new private key if one doesn't exist
  if [ ! -f "$CERT_DIR/private/privkey.pem" ]; then
    log_message "Generating new private key..."
    sudo openssl genrsa -out "$CERT_DIR/private/privkey.pem" 4096
  else
    log_message "Existing private key found, reusing it."
  fi

  # Generate Certificate Signing Request (CSR)
  log_message "Generating CSR..."
  sudo openssl req -new -key "$CERT_DIR/private/privkey.pem" -out /tmp/request.csr \
    -subj "/C=US/ST=AcmeState/L=AcmeCity/O=AcmeLabs/OU=AcmeDept/CN=$cert_cn"

  # Request certificate from Private CA
  log_message "Requesting certificate from ACM PCA: $PCA_ARN"
  CERTIFICATE_ARN=$(aws acm-pca issue-certificate \
    --certificate-authority-arn "$PCA_ARN" \
    --csr "fileb:///tmp/request.csr" \
    --signing-algorithm "SHA256WITHRSA" \
    --validity "Value=365,Type=DAYS" \
    --region "$AWS_REGION" \
    --query 'CertificateArn' --output text 2>&1)

  if [ -z "$CERTIFICATE_ARN" ] || [[ "$CERTIFICATE_ARN" == *"Error"* ]]; then
    log_message "Error: Failed to request certificate from ACM PCA: $CERTIFICATE_ARN" >&2
    exit 1
  fi
  log_message "Certificate request submitted. ARN: $CERTIFICATE_ARN"

  # Wait for certificate to be issued and retrieve it
  log_message "Waiting for certificate issuance..."
  local MAX_WAIT_ATTEMPTS=60 # 5 minutes total
  local ATTEMPT=0
  local CERT_CHAIN_JSON=""

  while [ "$ATTEMPT" -lt "$MAX_WAIT_ATTEMPTS" ]; do
      ATTEMPT=$((ATTEMPT + 1))
      CERT_CHAIN_JSON=$(aws acm-pca get-certificate \
        --certificate-authority-arn "$PCA_ARN" \
        --certificate-arn "$CERTIFICATE_ARN" \
        --region "$AWS_REGION" \
        --query '{Certificate:Certificate,CertificateChain:CertificateChain}' --output json 2>&1)
      
      if echo "$CERT_CHAIN_JSON" | jq -e '.Certificate' > /dev/null; then
          log_message "Certificate received after $ATTEMPT attempts."
          break
      fi
      log_message "Still waiting... ($ATTEMPT/$MAX_WAIT_ATTEMPTS)"
      sleep 5
  done
  
  if ! echo "$CERT_CHAIN_JSON" | jq -e '.Certificate' > /dev/null; then
    log_message "Error: Certificate not issued within timeout." >&2
    exit 1
  fi

  # Install the certificate and chain
  echo "$CERT_CHAIN_JSON" | jq -r '.Certificate' | sudo tee "$CERT_DIR/cert.pem" > /dev/null
  echo "$CERT_CHAIN_JSON" | jq -r '.CertificateChain' | sudo tee "$CERT_DIR/chain.pem" > /dev/null

  rm /tmp/request.csr
  log_message "Initial internal TLS setup complete. Certificates saved to $CERT_DIR"
}

# Function to configure Nginx to use the new TLS certs and proxy to app tier
configure_nginx() {
  log_message "--- Configuring Nginx ---"
  
  # The main Nginx config is baked into the AMI. This function's job is to
  # dynamically insert the internal DNS name of the App Tier's load balancer.
  # We use sed to replace the placeholder in the Nginx config file.
  log_message "Dynamically setting App Tier ALB DNS to: $APP_TIER_DNS"
  sudo sed -i "s/set \$app_tier_alb \"\";/set \$app_tier_alb \"${APP_TIER_DNS}\";/" "$NGINX_CONF_PATH"

  # Test the Nginx configuration to ensure syntax is correct
  if sudo nginx -t; then
    log_message "Nginx configuration test successful."
    # Reload Nginx to apply the new configuration.
    sudo systemctl reload nginx
    log_message "Nginx configuration applied and reloaded."
  else
    log_message "Error: Nginx configuration test failed. Check the config at $NGINX_CONF_PATH." >&2
    exit 1
  fi
}

# Function to configure WordPress with DB credentials and S3 offload
configure_wordpress() {
  log_message "--- Configuring WordPress (wp-config.php) ---"
  
  # Fetch DB password securely from AWS Secrets Manager
  log_message "Fetching DB password from Secrets Manager ARN: $DB_PASSWORD_SECRET_ARN"
  DB_PASSWORD_ACTUAL=$(aws secretsmanager get-secret-value --secret-id "$DB_PASSWORD_SECRET_ARN" --query 'SecretString' --output text --region "$AWS_REGION" | jq -r .password)

  # Fetch WordPress salts securely from AWS Secrets Manager
  log_message "Fetching WordPress salts from Secrets Manager ARN: $WP_SALTS_SECRET_ARN"
  WP_SALTS_JSON=$(aws secretsmanager get-secret-value --secret-id "$WP_SALTS_SECRET_ARN" --query 'SecretString' --output text --region "$AWS_REGION")

  # Generate the salt define() statements from the fetched JSON
  SALT_DEFINES=$(echo "$WP_SALTS_JSON" | jq -r 'to_entries | .[] | "define( \u0027\(.key)\u0027, \u0027\(.value|gsub("\u0027"; "\\\u0027"))\u0027 );"')

  cat > "$WORDPRESS_CONFIG_FILE" << EOF
<?php
// ** MySQL settings - Provided by Terraform and Secrets Manager ** //
define( 'DB_NAME', '$DB_NAME' );
define( 'DB_USER', '$DB_USERNAME' );
define( 'DB_PASSWORD', '$DB_PASSWORD_ACTUAL' );
define( 'DB_HOST', '$DB_ENDPOINT' );
define( 'DB_PORT', '$DB_PORT' );

// Force SSL for database connection
define('MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL);

// ** W3 Total Cache Settings - Provided by Anvil ** //
// This enables the plugin and configures in-memory caching.
define('WP_CACHE', true);
define('W3TC_CACHE_DATABASE_ENABLE', true);
define('W3TC_CACHE_DATABASE_METHOD', 'apc');
define('W3TC_CACHE_OBJECT_ENABLE', true);
define('W3TC_CACHE_OBJECT_METHOD', 'apc');

// ** Authentication Unique Keys and Salts - Provided by Secrets Manager ** //
$SALT_DEFINES

/**
 * The base path for WordPress.
 *
 * @since 2.6.0
 */
if ( !defined('ABSPATH') )
	define('ABSPATH', __DIR__ . '/');

/** Sets up WordPress vars and included files. */
require_once ABSPATH . 'wp-settings.php';
EOF

  sudo chown www-data:www-data "$WORDPRESS_CONFIG_FILE"
  log_message "WordPress configuration applied."
}

# Function to handle RUM script injection
inject_rum_script() {
  # This part depends on the RUM_APP_MONITOR_SCRIPT variable containing the JS.
  # For WordPress, you'd usually append this to wp-config.php or use a plugin.
  log_message "RUM script injection not implemented yet. (Placeholder)"
}

# --- Main Execution Flow ---

# Determine if this instance is a web server or app server.
# This relies on services (nginx/php-fpm) being present and enabled by the AMI build.
if systemctl is-active --quiet nginx; then
  log_message "--- Instance identified as Web Server ---"
  
  setup_xray_daemon
  install_initial_tls "web.${ENV}" # Use a more specific common name for web
  configure_nginx

  inject_rum_script # RUM script goes on the public-facing web servers

elif systemctl is-active --quiet php8.3-fpm; then # Adjust PHP version as needed
  log_message "--- Instance identified as App Server ---"
  
  # Install PHP APCu for object caching before starting services
  log_message "Installing PHP APCu for object caching..."
  sudo apt-get install -y php-apcu
  
  setup_xray_daemon
  install_initial_tls "app.${ENV}" # Use a more specific common name for app
  configure_wordpress # WordPress config only goes on the App Tier

  # Restart PHP-FPM to pick up the new APCu extension and wp-config settings
  log_message "Restarting PHP-FPM service..."
  sudo systemctl restart php8.3-fpm

else
  log_message "--- Unknown instance role based on active services, skipping application setup ---" >&2
  exit 0 # Exit successfully if role not found, other instances might have it
fi

echo "--- instance_setup.sh script finished ---"
