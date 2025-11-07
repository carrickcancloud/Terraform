#!/bin/bash -e
# ==============================================================================
# Project Anvil - AMI Builder Layer
# scripts/install_web.sh
#
# This script is executed by Packer to build the Web Server Golden AMI.
# It installs Nginx, unpacks the WordPress static content, and installs
# the CloudWatch Agent, ensuring the base OS is ready for web traffic.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

# --- OS Package Installation ---
echo "--- [Web AMI] Updating OS packages and installing Nginx ---"
sudo apt-get update
sudo apt-get install -y unzip nginx jq # jq for scripts, if used

# --- AWS CLI Installation ---
echo "--- [Web AMI] Installing AWS CLI v2 (official installer) ---"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp
sudo /tmp/aws/install
aws --version

# --- Web Content Installation ---
echo "--- [Web AMI] Unpacking static WordPress content ---"
# The web_package.tar.gz artifact is uploaded to /tmp/ by Packer (from dist/ at workspace root).
# It contains the wp-content directory.
sudo tar -xzf /tmp/web_package.tar.gz -C /var/www/html # Assuming /var/www/html is Nginx root
sudo chown -R www-data:www-data /var/www/html

# --- Nginx Configuration ---
echo "--- [Web AMI] Copying baked-in Nginx configuration ---"
# This config is copied from ami-builder/packer/configs/nginx-default.
# The instance_setup.sh script will dynamically configure the proxy_pass at boot.
sudo cp /tmp/nginx-default /etc/nginx/sites-available/default

echo "--- [Web AMI] Enabling Nginx service to start on boot ---"
sudo systemctl enable nginx

# --- CloudWatch Agent Installation ---
echo "--- [Web AMI] Installing CloudWatch Agent ---"
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb -O /tmp/amazon-cloudwatch-agent.deb
sudo dpkg -i -E /tmp/amazon-cloudwatch-agent.deb
rm /tmp/amazon-cloudwatch-agent.deb

# --- Debugging ---
# Show the instance profile info and AWS CLI identity.
echo "--- [Debug] EC2 Instance Profile Info (during AMI build) ---"
curl -s http://169.254.169.254/latest/meta-data/iam/info || echo "No IAM info available or instance not provisioned with IAM role"
aws sts get-caller-identity || echo "No AWS CLI identity or credentials available for current role"

echo "--- [Web AMI] Golden AMI Build - Web Server Complete ---"
