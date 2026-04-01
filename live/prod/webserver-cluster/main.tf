provider "aws" {
  region = "us-east-1"
}

module "webserver_cluster" {
  source = "../../../modules/webserver-cluster"

  # Core logic - hardcoded to PROD to trigger high-availability settings
  environment        = "prod" 
  
  # Network settings passed from variables
  vpc_cidr           = var.vpc_cidr
  vpc_name           = var.vpc_name
  public_subnets     = var.public_subnets
  
  # Scaling settings (Usually higher in prod)
  min_size           = var.min_size
  max_size           = var.max_size
  desired_capacity   = var.desired_capacity
  
  # Application settings
  server_port        = var.server_port
  enable_autoscaling = var.enable_autoscaling
}

# Production Outputs
output "alb_url" {
  value       = module.webserver_cluster.alb_dns_name
  description = "The public URL of the production load balancer"
}

output "asg_name" {
  value       = module.webserver_cluster.asg_name
}
