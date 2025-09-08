# This Packer template builds the "Golden AMI" for the Web Server tier.

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

# The "source" block defines the temporary EC2 instance that Packer will use for building.
source "amazon-ebs" "ubuntu" {
  ami_name      = "acmelabs-web-server-{{timestamp}}"
  instance_type = "t3.micro"
  region        = "us-east-1"
  source_ami    = var.source_ami
  ssh_username  = "ubuntu"

  # This tells Packer to launch the builder instance with the specified IAM role.
  # This role must have the 'CloudWatchAgentServerPolicy' and 'AmazonSSMReadOnlyAccess' policies attached.
  iam_instance_profile = "anvil-packer-builder-role"

  tags = {
    Name      = "Packer Builder - AcmeLabs Web"
    ManagedBy = "Packer"
    Project   = "Anvil"
  }
}

# The "build" block defines the steps to provision the instance.
build {
  name    = "web-server-ami"
  sources = ["source.amazon-ebs.ubuntu"]

  # Step 1: Upload the application package.
  provisioner "file" {
    source      = "../dist/web_package.tar.gz"
    destination = "/tmp/web_package.tar.gz"
  }

  # Step 2: Upload the pre-written Nginx configuration file.
  provisioner "file" {
    source      = "configs/nginx-default"
    destination = "/tmp/nginx-default"
  }

  # Step 3: Upload the installation script.
  provisioner "file" {
    source      = "../scripts/install_web.sh"
    destination = "/tmp/install_web.sh"
  }

  # Step 4: Execute the installation script, which now also moves the config file.
  provisioner "shell" {
    script = "/tmp/install_web.sh"
  }

  # Step 5: Scan the instance filesystem for vulnerabilities.
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
