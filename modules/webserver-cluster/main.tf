# DATA SOURCES
data "aws_region" "current" {}

data "aws_ami" "ubuntu_22_04" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  owners = ["099720109477"]
}

# LOCALS (Conditionals)
locals {
  # Helper boolean for cleaner ternaries
  is_prod = var.environment == "prod"

  # Environment-specific sizing
  instance_type = local.is_prod ? "t3.small" : "t3.micro"
  
  # Resource Naming Strategy
  name_prefix = "${var.environment}-webserver"
  
  # Infrastructure protection
  enable_termination_protection = local.is_prod ? true : false
}
# NETWORKING
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name   = var.vpc_name
    Region = data.aws_region.current.id
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_subnet" "public" {
  for_each = var.public_subnets #toset(var.public_subnet_cidrs)

  vpc_id   = aws_vpc.vpc.id
  cidr_block = each.value.cidr

  availability_zone = each.value.az #var.availability_zones[lookup(index(var.public_subnet_cidrs, each.value), 0, 0)]
  map_public_ip_on_launch = true

  tags = {
    Name = each.key #"public-${each.value}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# SECURITY GROUPS
resource "aws_security_group" "alb_sg" {
  name   = "${local.name_prefix}-alb-sg" # Dynamic name
  vpc_id = aws_vpc.vpc.id
}

resource "aws_security_group_rule" "alb_ingress" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_sg.id
}

resource "aws_security_group_rule" "alb_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_sg.id
}

resource "aws_security_group" "web_sg" {
  name   = "web-sg"
  vpc_id = aws_vpc.vpc.id
}

resource "aws_security_group_rule" "web_ingress" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.web_sg.id
  source_security_group_id = aws_security_group.alb_sg.id
}

resource "aws_security_group_rule" "web_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web_sg.id
}

# ALB + Target Group
resource "aws_alb" "alb" {
  name               = "${local.name_prefix}-alb" # Dynamic name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  
  # Rule 6 logic: Enable deletion protection for production
  enable_deletion_protection = local.is_prod

  subnets = [for s in aws_subnet.public : s.id]
}

resource "aws_lb_target_group" "tg" {
  name     = "web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_alb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# Launch Template + ASG
resource "aws_launch_template" "lt" {
  name_prefix   = "web-server-"
  image_id      = data.aws_ami.ubuntu_22_04.id
  instance_type = local.instance_type

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web_sg.id]
  }

  user_data = templatefile("${path.module}/user-data.sh", {
    server_port = var.server_port
  })
}

resource "aws_autoscaling_group" "asg" {
  vpc_zone_identifier = [for s in aws_subnet.public : s.id]
  target_group_arns   = [aws_lb_target_group.tg.arn]
  health_check_type   = "ELB"

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  force_delete = true

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }
}

# CONDITIONAL RESOURCE
resource "aws_autoscaling_policy" "scale_out" {
  count = var.enable_autoscaling ? 1 : 0

  name                   = "scale-out"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  # Only create this alarm if we are in prod OR if specifically enabled
  count = (local.is_prod || var.enable_autoscaling) ? 1 : 0

  alarm_name          = "${local.name_prefix}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }

  alarm_description = "This metric monitors ec2 cpu utilization"
  alarm_actions     = [aws_autoscaling_policy.scale_out[0].arn] # Note the [0] index!
}