# This file defines the core Terraform settings, including the required version,
# and provider versions. The remote state backend configuration is now
# provided dynamically by the CI/CD pipeline.

terraform {
  required_version = ">= 1.3.0" # Increased requirement for latest features

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }

  backend "s3" {
    # The `bucket` and `key` arguments are now provided on the command line
    # during 'init' by the CI/CD pipeline using a .tfbackend file from
    # the 'config/' directory. This makes the configuration dynamic per environment.
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "acmelabs-terraform-lock-table"
  }
}
