provider "aws" {
  region = "us-east-1"
}

module "webserver_cluster" {
  source = "../../../modules/webserver-cluster"

  # Core logic - hardcoded to ensure this folder is always DEV
  environment        = "dev" 
  
  # Network settings from variables
  vpc_cidr           = var.vpc_cidr
  vpc_name           = var.vpc_name
  public_subnets     = var.public_subnets
  
  # Scaling settings from variables
  min_size           = var.min_size
  max_size           = var.max_size
  desired_capacity   = var.desired_capacity
  
  # Application settings
  server_port        = var.server_port
  enable_autoscaling = var.enable_autoscaling
}

# Output the URL for easy access after deployment
output "alb_url" {
  value       = module.webserver_cluster.alb_dns_name
  description = "The domain name of the load balancer for the dev environment"
}