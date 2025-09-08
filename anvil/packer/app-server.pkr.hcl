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

# The temporary EC2 instance configuration.
source "amazon-ebs" "ubuntu" {
  ami_name      = "acmelabs-app-server-{{timestamp}}"
  instance_type = "t3.micro"
  region        = "us-east-1"
  source_ami    = var.source_ami
  ssh_username  = "ubuntu"

  # Attach the IAM role to grant necessary permissions for the build process.
  iam_instance_profile = "anvil-packer-builder-role"

  tags = {
    Name      = "Packer Builder - AcmeLabs App"
    ManagedBy = "Packer"
    Project   = "Anvil"
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

  # Step 4: Scan the instance filesystem for vulnerabilities before creating the AMI.
  provisioner "shell" {
    inline = [
      "echo '--- [Packer] Installing Trivy ---'",
      "sudo apt-get install -y wget apt-transport-https gnupg lsb-release",
      "wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -",
      "echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/trivy.list",
      "sudo apt-get update",
      "sudo apt-get install -y trivy",
      "echo '--- [Packer] Running Trivy Filesystem Scan ---'",
      # Scan the entire filesystem, but exit with an error only if HIGH or CRITICAL vulnerabilities are found.
      # This prevents the build from failing on low/medium findings.
      "trivy fs --severity HIGH,CRITICAL --exit-code 1 /"
    ]
  }
}
