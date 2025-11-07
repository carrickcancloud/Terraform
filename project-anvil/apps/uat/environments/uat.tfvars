# ==============================================================================
# Project Anvil - Application Layer (UAT Environment)
# environments/uat.tfvars
#
# This file defines the environment-specific input variables for the 'uat'
# application layer. These values configure scaling, instance types, and
# AMI versions for the User Acceptance Testing environment.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

# ------------------------------------------------------------------------------
# Networking Configuration
# ------------------------------------------------------------------------------
# Deploys 'uat' across three Availability Zones.
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# ------------------------------------------------------------------------------
# SSH Key Pair
# Defines the SSH key pair to be used for instances in this environment.
# This value will be passed to the EC2 module.
# ------------------------------------------------------------------------------
key_name = "acmelabs-uat-key"

# ------------------------------------------------------------------------------
# Scaling Parameters
# Defines the scaling parameters for each tier. Similar to QA.
# ------------------------------------------------------------------------------
web_min_size         = 2
web_max_size         = 4
web_desired_capacity = 2
app_min_size         = 2
app_max_size         = 4
app_desired_capacity = 2

# ------------------------------------------------------------------------------
# Instance Types
# Defines the EC2 instance types for web and app tiers.
# ------------------------------------------------------------------------------
web_instance_type = "t3.small"
app_instance_type = "t3.medium"
db_instance_class = "db.t3.small"

# ------------------------------------------------------------------------------
# AMI Version
# Deploys the application version specified by this Git commit hash.
# This value must match a version stored in SSM by the AMI Factory pipeline.
# ------------------------------------------------------------------------------
ami_version = "latest" # Placeholder for a specific Git hash
