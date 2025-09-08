# This file defines the core Terraform settings, including the required version,
# provider versions, and the location of the remote state backend.

terraform {
  required_version = ">= 1.13.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.10.0"
    }
  }

  backend "s3" {
    bucket = "acmelabs-terraform"
    # The 'key' argument has been REMOVED from this block.
    # It will now be provided on the command line during 'init'
    # using a .tfbackend file from the 'config/' directory.
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "acmelabs-terraform-lock-table"
  }
}
