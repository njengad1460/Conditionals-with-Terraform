# 1. Standard Output (Always exists)
output "alb_dns_name" {
  value       = aws_alb.alb.dns_name
  description = "The domain name of the load balancer"
}

output "asg_name" {
  value       = aws_autoscaling_group.asg.name
  description = "The name of the Auto Scaling Group"
}

# 2. Conditional Outputs (Index Notation)
# Returns the ARN if enabled, otherwise returns null to avoid errors


output "cpu_alarm_arn" {
  value       = var.enable_autoscaling ? aws_cloudwatch_metric_alarm.high_cpu[0].arn : null
  description = "The ARN of the CloudWatch CPU alarm"
}

# 3. Dynamic Networking Info
# These use the LOCALS we defined so they work whether the VPC is new or existing
output "vpc_id" {
  value       = local.vpc_id
  description = "The ID of the VPC being used"
}

output "public_subnet_ids" {
  value       = local.subnet_ids
  description = "The IDs of the public subnets being used"
}