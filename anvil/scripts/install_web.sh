#!/bin/bash -e
# This script is run by Packer to build the Web Server Golden AMI.
# It installs Nginx, the WordPress static content, and the CloudWatch Agent.

echo "--- [Web AMI] Updating OS packages ---"
sudo apt-get update
sudo apt-get install -y nginx jq awscli

# --- Web Content Installation ---
echo "--- [Web AMI] Unpacking static WordPress content ---"
# The web_package.tar.gz artifact is uploaded to /tmp/ by Packer.
sudo tar -xzf /tmp/web_package.tar.gz -C /var/www/html
sudo chown -R www-data:www-data /var/www/html

# --- Nginx Configuration ---
echo "--- [Web AMI] Copying baked-in Nginx configuration ---"
sudo cp /tmp/nginx-default /etc/nginx/sites-available/default

echo "--- [Web AMI] Enabling Nginx service to start on boot ---"
sudo systemctl enable nginx

# --- CloudWatch Agent Installation & Configuration ---
echo "--- [Web AMI] Installing CloudWatch Agent ---"
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb -O /tmp/amazon-cloudwatch-agent.deb
sudo dpkg -i -E /tmp/amazon-cloudwatch-agent.deb
rm /tmp/amazon-cloudwatch-agent.deb

echo "--- [Web AMI] Configuring CloudWatch Agent ---"
# Fetches the centralized agent config from SSM Parameter Store and starts the agent.
# The IAM role on the Packer instance provides permission to do this.
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c ssm:AnvilCloudWatchAgentConfig -s

echo "--- [Web AMI] Golden AMI Build Complete ---"
