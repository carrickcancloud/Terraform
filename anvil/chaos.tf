# This file defines resources for Chaos Engineering using AWS Fault Injection Simulator (FIS).
# These experiments are designed to be run manually in non-production environments to
# verify the resilience of the system.

# +------------------------------------------+
# |           IAM Role for FIS               |
# +------------------------------------------+

# This IAM role allows the FIS service to perform actions on our resources,
# specifically terminating EC2 instances within the scope of our experiment.
resource "aws_iam_role" "fis_role" {
  name = "${local.name_prefix}-fis-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "fis.amazonaws.com" }
    }]
  })
}

# Defines the policy granting FIS permission to terminate EC2 instances that
# are part of our application's Auto Scaling Groups.
resource "aws_iam_policy" "fis_ec2_access" {
  name   = "${local.name_prefix}-fis-ec2-access-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = [
        "ec2:DescribeInstances",
        "ec2:TerminateInstances"
      ],
      # IMPORTANT: This policy is scoped to only allow terminating instances
      # that have the project and environment tag, preventing accidental termination
      # of other resources in the account.
      Resource = "*",
      Condition = {
        StringEquals = {
          "ec2:ResourceTag/Project" : var.project_name,
          "ec2:ResourceTag/Environment" : terraform.workspace
        }
      }
    }]
  })
}

# Attaches the policy to the FIS role.
resource "aws_iam_role_policy_attachment" "fis_ec2_access_attach" {
  role       = aws_iam_role.fis_role.name
  policy_arn = aws_iam_policy.fis_ec2_access.arn
}

# +------------------------------------------+
# |       FIS Experiment Template            |
# +------------------------------------------+

# Defines a reusable "Game Day" experiment template. This template can be started
# from the AWS Console to run a controlled chaos experiment.
resource "aws_fis_experiment_template" "terminate_web_instance" {
  description = "Game Day: Terminate one web server instance to verify auto-scaling and load balancer health checks."
  role_arn    = aws_iam_role.fis_role.arn

  # Defines the action to take. In this case, terminate an EC2 instance.
  action {
    name       = "terminate-instance"
    action_id  = "aws:ec2:terminate-instances"
    target {
      key   = "instance-target"
      value = "web-instances"
    }
  }

  # Defines the target resources for the action.
  target {
    name            = "web-instances"
    resource_type   = "aws:ec2:instance"
    selection_mode  = "COUNT(1)"

    # Filters the target resources to only those with the specific Name tag.
    resource_tag {
      key   = "Name"
      value = "${local.name_prefix}-web-instance"
    }
  }

  # Defines the "stop condition" for the experiment. This is a critical safety mechanism.
  # If this CloudWatch alarm goes into an ALARM state during the experiment, FIS will
  # immediately stop the experiment and roll back if possible.
  stop_condition {
    source = "aws:cloudwatch:alarm"
    value  = aws_cloudwatch_metric_alarm.web_unhealthy_hosts.arn
  }

  tags = local.common_tags

  # Ensure the role and policies are created before the template.
  depends_on = [aws_iam_role_policy_attachment.fis_ec2_access_attach]
}
