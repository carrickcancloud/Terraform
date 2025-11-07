# ==============================================================================
# Project Anvil - Application Layer (Dev Environment)
# environments/dev.tfvars
#
# This file defines the environment-specific input variables for the 'dev'
# application layer. These values configure scaling, instance types, and
# AMI versions for the development environment.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

# ------------------------------------------------------------------------------
# Networking Configuration
# ------------------------------------------------------------------------------
# Deploys 'dev' across three Availability Zones for robust testing.
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# ------------------------------------------------------------------------------
# SSH Key Pair
# Defines the SSH key pair to be used for instances in this environment.
# This value will be passed to the EC2 module.
# ------------------------------------------------------------------------------
key_name = "acmelabs-dev-key"

# ------------------------------------------------------------------------------
# Scaling Parameters
# Defines the scaling parameters for each tier. Start small for dev.
# ------------------------------------------------------------------------------
web_min_size         = 1
web_max_size         = 2
web_desired_capacity = 1
app_min_size         = 1
app_max_size         = 2
app_desired_capacity = 1

# ------------------------------------------------------------------------------
# Instance Types
# Defines the EC2 instance types for web and app tiers.
# ------------------------------------------------------------------------------
web_instance_type = "t3.micro"
app_instance_type = "t3.micro"
db_instance_class = "db.t3.micro"

# ------------------------------------------------------------------------------
# AMI Version
# Deploys the application version specified by this Git commit hash.
# This value must match a version stored in SSM by the AMI Factory pipeline.
# ------------------------------------------------------------------------------
ami_version = "latest" # Placeholder for a specific Git hash
