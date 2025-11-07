# ==============================================================================
# Project Anvil - AMI Builder Layer
# packer/web-server.pkr.hcl
#
# Packer template for building the Golden AMI for the Web Server tier.
# It provisions an EC2 instance, installs Nginx, unpacks static WordPress
# content, and installs the CloudWatch Agent. It also includes Trivy for
# vulnerability scanning.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

# ------------------------------------------------------------------------------
# Packer Settings
# ------------------------------------------------------------------------------

packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# ------------------------------------------------------------------------------
# Variables
# (Passed into Packer from the GitHub Actions workflow)
# ------------------------------------------------------------------------------

variable "source_ami" {
  type    = string
  description = "The ID of the base AMI to build upon (e.g., official Ubuntu LTS)."
  default = "ami-0360c520857e3138f" # Example: Ubuntu 22.04 LTS HVM EBS in us-east-1
}

variable "target_env" {
  type        = string
  description = "The target environment (e.g., 'dev', 'prod') for this AMI build. Used for tagging and S3 report paths."
  default     = "dev" # Default for local testing
}

variable "tier" {
  type        = string
  description = "The server tier for this AMI build (e.g., 'app', 'web')."
  default     = "web" # Default for this template
}

variable "git_commit" {
  type        = string
  description = "The Git commit hash from the workflow trigger. Used for tagging."
}

variable "github_actor" {
  type        = string
  description = "The GitHub actor who triggered the workflow. Used for tagging."
}

# ------------------------------------------------------------------------------
# Source Block (EC2 Instance Configuration for Building)
# ------------------------------------------------------------------------------

source "amazon-ebs" "ubuntu" {
  ami_name      = "acmelabs-${var.tier}-server-${var.target_env}-{{timestamp}}"
  instance_type = "t3.micro"
  region        = "us-east-1"
  source_ami    = var.source_ami
  ssh_username  = "ubuntu"

  # Ensure this IAM instance profile exists and has necessary permissions
  # (EC2 full access, SSM full access, S3 PutObject to vulnerability buckets).
  iam_instance_profile = "anvil-packer-builder-role"

  tags = {
    Name        = "Packer Builder - AcmeLabs ${var.tier} (${var.target_env})"
    ManagedBy   = "Packer"
    Project     = "Anvil"
    Environment = var.target_env
    Tier        = var.tier
    Commit      = var.git_commit
    BuiltBy     = var.github_actor
  }
}

# ------------------------------------------------------------------------------
# Build Block (Provisioners)
# ------------------------------------------------------------------------------

build {
  name    = "web-server-ami"
  sources = ["source.amazon-ebs.ubuntu"]

  # Step 1: Upload the web tier's static content package.
  # This path is relative to the root of the Packer execution directory (ami-builder/packer).
  # The 'create_packages.sh' script places this at the workspace root's 'dist/' folder.
  provisioner "file" {
    source      = "../../dist/web_package.tar.gz" # Path relative to ami-builder/packer/
    destination = "/tmp/web_package.tar.gz"
  }

  # Step 2: Upload the Nginx default configuration file.
  # This path is relative to the root of the Packer execution directory (ami-builder/packer).
  provisioner "file" {
    source      = "./configs/nginx-default" # Path relative to ami-builder/packer/
    destination = "/tmp/nginx-default"
  }

  # Step 3: Upload the web tier's installation script.
  # This path is relative to the root of the Packer execution directory (ami-builder/packer).
  provisioner "file" {
    source      = "../scripts/install_web.sh" # Path relative to ami-builder/packer/
    destination = "/tmp/install_web.sh"
  }

  # Step 4: Execute the installation script.
  # This script installs Nginx, unpacks web content, and installs CloudWatch Agent.
  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
      "PKR_VAR_target_env=${var.target_env}" # Pass to script for CWA config path
    ]
    inline = [
      "echo '--- [Packer Debug] /tmp directory contents before install_web.sh ---'",
      "ls -l /tmp",
      "chmod +x /tmp/install_web.sh",
      "/tmp/install_web.sh"
    ]
  }

  # ----------------------------------------------------------------------------
  # Trivy Vulnerability Scanning
  # Installs Trivy, runs a full filesystem scan, uploads reports to S3, and
  # checks for critical/high vulnerabilities without failing the build.
  # ----------------------------------------------------------------------------
  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
      "S3_BUCKET_NAME=acmelabs-vulnerability-reports-${var.target_env}", # Dynamic S3 bucket
      "TIER_NAME=${var.tier}-server",
      "ENVIRONMENT_NAME=${var.target_env}"
    ]
    inline = [
      "echo '--- [Packer] Installing Trivy ---'",
      "sudo apt-get update",
      "sudo apt-get install -y wget apt-transport-https gnupg lsb-release",
      "sudo mkdir -p /etc/apt/keyrings",
      "curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo gpg --dearmor -o /etc/apt/keyrings/trivy.gpg",
      "echo \"deb [signed-by=/etc/apt/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main\" | sudo tee /etc/apt/sources.list.d/trivy.list",
      "sudo apt-get update",
      "sudo apt-get install -y trivy",

      "echo '--- [Packer] Running Trivy Full Scan (Optimized) ---'",
      "trivy fs --format json --output /tmp/report.json --scanners vuln --skip-dirs /var/lib/apt/lists/ --skip-files /tmp/report.json / --timeout 30m || true",

      "echo '--- [Packer] Uploading Report to S3 ---'",
      "REPORT_NAME=$(date +%Y-%m-%d)-$ENVIRONMENT_NAME-$TIER_NAME-report.json",
      "aws s3 cp /tmp/report.json s3://$S3_BUCKET_NAME/$REPORT_NAME",
      "echo \"Trivy report uploaded to S3: s3://$S3_BUCKET_NAME/$REPORT_NAME\"",

      "echo '--- [Packer] Checking for Critical/High Vulnerabilities (Final Gate) ---'",
      "HIGH_VULNS=$(jq '[.Results[].Vulnerabilities[] | select(.Severity == \"HIGH\")] | length' /tmp/report.json)",
      "CRITICAL_VULNS=$(jq '[.Results[].Vulnerabilities[] | select(.Severity == \"CRITICAL\")] | length' /tmp/report.json)",
      "TOTAL_HIGH_CRIT=$((HIGH_VULNS + CRITICAL_VULNS))",

      "if [ \"$TOTAL_HIGH_CRIT\" -gt 0 ]; then",
      "  echo \"WARNING: Trivy scan found $TOTAL_HIGH_CRIT High/Critical vulnerabilities.\"",
      "  echo \"(High: $HIGH_VULNS, Critical: $CRITICAL_VULNS)\"",
      "  echo \"Please review the full report on S3: s3://$S3_BUCKET_NAME/$REPORT_NAME\"",
      "else",
      "  echo \"Trivy scan completed: No High or Critical vulnerabilities detected.\"",
      "fi",
      "echo 'Vulnerability check complete. Build continuing.'"
    ]
  }
}
