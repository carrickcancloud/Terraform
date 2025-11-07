# ==============================================================================
# Project Anvil - Application Layer (Dev)
# modules/ec2/main.tf
#
# This module creates an EC2 Auto Scaling Group, Launch Template, and optionally
# an Application Load Balancer for the web or app tier. Used by the dev environment.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

# ------------------------------------------------------------------------------
# Launch Template for EC2 Instances
# ------------------------------------------------------------------------------

resource "aws_launch_template" "this" {
  name          = "${var.name_prefix}-lt"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = var.iam_instance_profile_name
  }

  network_interfaces {
    security_groups             = var.security_group_ids
    associate_public_ip_address = false
  }

  user_data = var.user_data_script_base64

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Auto Scaling Group
# ------------------------------------------------------------------------------

resource "aws_autoscaling_group" "this" {
  name                = "${var.name_prefix}-asg"
  desired_capacity    = var.desired_capacity
  min_size            = var.min_size
  max_size            = var.max_size
  vpc_zone_identifier = var.subnet_ids

  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }

  # Attach to target group if load balancer is created
  target_group_arns = var.create_load_balancer ? [aws_lb_target_group.this[0].arn] : []

  health_check_type         = var.create_load_balancer ? "ELB" : "EC2"
  health_check_grace_period = 300

  dynamic "tag" {
    for_each = merge(var.tags, { "Name" = "${var.name_prefix}-instance" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# ------------------------------------------------------------------------------
# Scaling Policy
# ------------------------------------------------------------------------------

resource "aws_autoscaling_policy" "cpu_scaling" {
  name                   = "${var.name_prefix}-cpu-scaling-policy"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60.0
  }
}

# ------------------------------------------------------------------------------
# Optional Application Load Balancer (ALB)
# ------------------------------------------------------------------------------

resource "aws_lb" "this" {
  count              = var.create_load_balancer ? 1 : 0
  name               = "${var.name_prefix}-alb"
  internal           = var.lb_is_internal
  load_balancer_type = "application"
  security_groups    = var.lb_security_group_ids
  subnets            = var.lb_subnet_ids

  access_logs {
    bucket  = var.s3_bucket_for_logs
    prefix  = "alb-logs/${var.name_prefix}"
    enabled = var.s3_bucket_for_logs != "" ? true : false
  }

  tags = var.tags
}

resource "aws_lb_target_group" "this" {
  count    = var.create_load_balancer ? 1 : 0
  name     = "${var.name_prefix}-tg"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTPS"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = var.tags
}

resource "aws_lb_listener" "https" {
  count             = var.create_load_balancer && var.enable_https_listener && var.lb_certificate_arn != null ? 1 : 0
  load_balancer_arn = aws_lb.this[0].arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = var.lb_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[0].arn
  }

  tags = var.tags
}

resource "aws_lb_listener" "http" {
  count             = var.create_load_balancer ? 1 : 0
  load_balancer_arn = aws_lb.this[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = var.tags
}
