variables {
  environment      = "dev"
  min_size         = 1
  max_size         = 2
  desired_capacity = 1
  vpc_cidr         = "10.0.0.0/16"
  vpc_name         = "test-vpc"
  public_subnets   = {
    sub-1 = { cidr = "10.0.1.0/24", az = "us-east-1a" }
  }
  server_port      = 80
}

run "validate_asg_name" {
  command = plan

  assert {
    condition     = aws_autoscaling_group.asg.name == "dev-webserver-asg"
    error_message = "ASG name must match the environment-based name prefix"
  }
}

run "validate_instance_type" {
  command = plan

  assert {
    condition     = aws_launch_template.lt.instance_type == "t3.micro"
    error_message = "Instance type for dev environment should be t3.micro"
  }
}

run "validate_security_group_port" {
  command = plan

  assert {
    condition     = aws_security_group_rule.web_ingress.from_port == 80
    error_message = "Security group must allow traffic on port 80"
  }
}
