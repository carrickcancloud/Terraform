# ==============================================================================
# Project Anvil - Application Layer (Prod Environment)
# environments/prod.tfvars
#
# This file defines the environment-specific input variables for the 'prod'
# application layer. These values configure scaling, instance types, and
# AMI versions for the production environment.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

# ------------------------------------------------------------------------------
# Networking Configuration
# ------------------------------------------------------------------------------
# Deploys 'prod' across three different Availability Zones for maximum resilience.
availability_zones = ["us-east-1d", "us-east-1e", "us-east-1f"]

# ------------------------------------------------------------------------------
# SSH Key Pair
# Defines the SSH key pair to be used for instances in this environment.
# This value will be passed to the EC2 module.
# ------------------------------------------------------------------------------
key_name = "acmelabs-prod-key"

# ------------------------------------------------------------------------------
# Scaling Parameters
# Defines the scaling parameters for each tier. Allow for higher scale in prod.
# ------------------------------------------------------------------------------
web_min_size         = 2
web_max_size         = 10
web_desired_capacity = 3
app_min_size         = 3
app_max_size         = 10
app_desired_capacity = 3

# ------------------------------------------------------------------------------
# Instance Types
# Defines the EC2 instance types for web and app tiers.
# ------------------------------------------------------------------------------
web_instance_type = "t3.medium"
app_instance_type = "t3.large"
db_instance_class = "db.t3.medium"

# ------------------------------------------------------------------------------
# AMI Version
# Deploys the application version specified by this Git commit hash.
# This value must match a version stored in SSM by the AMI Factory pipeline.
# ------------------------------------------------------------------------------
ami_version = "latest" # Placeholder for a specific Git hash
