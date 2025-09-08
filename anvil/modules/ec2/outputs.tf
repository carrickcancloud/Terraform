# This file defines the outputs that this module makes available to the root module.

output "autoscaling_group_name" {
  description = "The name of the created Auto Scaling Group."
  value       = aws_autoscaling_group.this.name
}

output "load_balancer_name" {
  description = "The name of the created Application Load Balancer. This is used to reference the LB in CloudWatch metrics."
  # The ALB name is the second to last part of its ARN. We extract it here.
  value       = var.create_load_balancer ? split("/", aws_lb.this[0].arn)[1] : ""
}

output "target_group_name" {
  description = "The name of the created Target Group. This is used to reference the TG in CloudWatch metrics."
  # The Target Group name is also part of its ARN.
  value       = var.create_load_balancer ? split("/", aws_lb_target_group.this[0].arn)[1] : ""
}

output "load_balancer_dns_name" {
  description = "The DNS name of the created Application Load Balancer. This will be empty if no load balancer was created."
  value       = var.create_load_balancer ? aws_lb.this[0].dns_name : ""
}

output "load_balancer_zone_id" {
  description = "The Hosted Zone ID of the created Application Load Balancer. This is needed for creating DNS alias records."
  value       = var.create_load_balancer ? aws_lb.this[0].zone_id : ""
}

output "target_group_arn" {
  description = "The ARN of the created Target Group. This will be empty if no load balancer was created."
  value       = var.create_load_balancer ? aws_lb_target_group.this[0].arn : ""
}

output "load_balancer_arn" {
  description = "The ARN of the created Application Load Balancer."
  value       = var.create_load_balancer ? aws_lb.this[0].arn : ""
}
