# 1. Standard Output (Always exists)
output "alb_dns_name" {
  value       = aws_alb.alb.dns_name
  description = "The domain name of the load balancer"
}

# 2. Conditional Output (Index Notation)
# This will return the ARN if the alarm exists, or null if it doesn't.
output "autoscaling_policy_arn" {
  value       = var.enable_autoscaling ? aws_autoscaling_policy.scale_out[0].arn : null
  description = "The ARN of the scale-out policy (if enabled)"
}

# 3. Networking Info
output "vpc_id" {
  value       = aws_vpc.vpc.id
  description = "The ID of the VPC"
}

output "public_subnet_ids" {
  value       = [for s in aws_subnet.public : s.id]
  description = "The IDs of the public subnets"
}