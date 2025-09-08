# This Packer template builds the "Golden AMI" for the Application Server tier.

packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "source_ami" {
  type    = string
  default = "ami-0360c520857e3138f" # Ubuntu 24.04 LTS for us-east-1
}

variable "target_env" {
  description = "The target environment (e.g., 'dev', 'prod') for this AMI build."
  type        = string
  default     = "dev" # Default to 'dev' for local builds
}

# The temporary EC2 instance configuration.
source "amazon-ebs" "ubuntu" {
  ami_name      = "acmelabs-app-server-${var.target_env}-{{timestamp}}"
  instance_type = "t3.micro"
  region        = "us-east-1"
  source_ami    = var.source_ami
  ssh_username  = "ubuntu"

  # Attach the IAM role to grant necessary permissions for the build process.
  iam_instance_profile = "anvil-packer-builder-role"

  tags = {
    Name        = "Packer Builder - AcmeLabs App (${var.target_env})"
    ManagedBy   = "Packer"
    Project     = "Anvil"
    Environment = var.target_env
  }
}

# The build and provisioning steps.
build {
  name    = "app-server-ami"
  sources = ["source.amazon-ebs.ubuntu"]

  # Step 1: Upload the app tier's package.
  provisioner "file" {
    source      = "../dist/app_package.tar.gz"
    destination = "/tmp/app_package.tar.gz"
  }

  # Step 2: Upload the app tier's installation script.
  provisioner "file" {
    source      = "../scripts/install_app.sh"
    destination = "/tmp/install_app.sh"
  }

  # Step 3: Execute the installation script.
  provisioner "shell" {
    script = "/tmp/install_app.sh"
  }

  # Step 4: Scan the instance and upload a full vulnerability report to the correct S3 bucket.
  provisioner "shell" {
    environment_vars = [
      # The S3 bucket name is now dynamically constructed based on the target environment.
      "S3_BUCKET_NAME=acmelabs-vulnerability-reports-${var.target_env}",
      "TIER_NAME=app-server",
      "ENVIRONMENT_NAME=${var.target_env}"
    ]
    inline = [
      "echo '--- [Packer] Installing Trivy ---'",
      "sudo apt-get install -y wget apt-transport-https gnupg lsb-release",
      "wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -",
      "echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/trivy.list",
      "sudo apt-get update",
      "sudo apt-get install -y trivy",

      "echo '--- [Packer] Running Trivy Full Scan ---'",
      "trivy fs --format json --output /tmp/report.json /",

      "echo '--- [Packer] Uploading Report to S3 ---'",
      "REPORT_NAME=$(date +%Y-%m-%d)-${ENVIRONMENT_NAME}-${TIER_NAME}-report.json",
      "aws s3 cp /tmp/report.json s3://${S3_BUCKET_NAME}/${REPORT_NAME}",

      "echo '--- [Packer] Checking for Critical/High Vulnerabilities ---'",
      # This second scan acts as the security gate for the build.
      "trivy fs --severity HIGH,CRITICAL --exit-code 1 /"
    ]
  }
}
