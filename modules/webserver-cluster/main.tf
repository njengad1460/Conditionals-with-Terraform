# --- DATA SOURCES ---
data "aws_region" "current" {}

data "aws_ami" "ubuntu_22_04" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  owners = ["099720109477"]
}

# Lookup existing VPC only if enabled
data "aws_vpc" "selected" {
  count = var.use_existing_vpc ? 1 : 0
  id    = var.existing_vpc_id
}

# Lookup existing subnets only if enabled
data "aws_subnets" "existing" {
  count = var.use_existing_vpc ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected[0].id]
  }
}

# --- LOCALS ---
locals {
  is_prod = var.environment == "prod"

  # Environment-specific logic
  instance_type = local.is_prod ? "t3.small" : "t3.micro"
  name_prefix   = "${var.environment}-webserver"
  
  # Determine which VPC/Subnets to use
  vpc_id     = var.use_existing_vpc ? data.aws_vpc.selected[0].id : aws_vpc.vpc[0].id
  subnet_ids = var.use_existing_vpc ? data.aws_subnets.existing[0].ids : [for s in aws_subnet.public : s.id]
}

# --- NETWORKING ---
resource "aws_vpc" "vpc" {
  count                = var.use_existing_vpc ? 0 : 1
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name   = var.vpc_name
    Region = data.aws_region.current.id
  }
}

resource "aws_internet_gateway" "igw" {
  count  = var.use_existing_vpc ? 0 : 1
  vpc_id = aws_vpc.vpc[0].id
}

resource "aws_subnet" "public" {
  for_each = var.use_existing_vpc ? {} : var.public_subnets

  vpc_id                  = aws_vpc.vpc[0].id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-${each.key}"
  }
}

resource "aws_route_table" "public" {
  count  = var.use_existing_vpc ? 0 : 1
  vpc_id = aws_vpc.vpc[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw[0].id
  }
}

resource "aws_route_table_association" "public_assoc" {
  for_each       = var.use_existing_vpc ? {} : aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public[0].id
}

# --- SECURITY GROUPS ---
resource "aws_security_group" "alb_sg" {
  name   = "${local.name_prefix}-alb-sg"
  vpc_id = local.vpc_id
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
  name   = "${local.name_prefix}-web-sg"
  vpc_id = local.vpc_id
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

# --- ALB + TARGET GROUP ---
# --- ALB ---
resource "aws_alb" "alb" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = local.subnet_ids

  # enable_deletion_protection = local.is_prod   
  enable_deletion_protection = false # disabled deletion protection to allow all resource deletion
}

# --- TARGET GROUPS ---
resource "aws_lb_target_group" "tg" {
  name     = "${local.name_prefix}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = local.vpc_id

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

# --- THE SWITCHER (LISTENER) ---
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_alb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# --- LAUNCH TEMPLATE + ASG ---
resource "aws_launch_template" "lt" {
  name_prefix   = "${local.name_prefix}-lt-"
  image_id      = data.aws_ami.ubuntu_22_04.id
  instance_type = local.instance_type

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web_sg.id]
  }

  user_data = (base64encode(templatefile("${path.module}/user-data.sh", {
    server_port = var.server_port
  })))
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg" {
  # Keep the name static so we don't throw away the ASG, we just refresh its instances
  name                = "${local.name_prefix}-asg"
  vpc_zone_identifier = local.subnet_ids

  target_group_arns = [
    aws_lb_target_group.tg.arn
  ]

  # --- CRITICAL UPDATES FOR ZERO DOWNTIME ---
  
  health_check_type         = "ELB"
  health_check_grace_period = 300 # Gives your .sh script time to install Apache

  # This tells Terraform: "Don't finish the 'apply' until these instances are Healthy in the ALB"
  wait_for_elb_capacity = var.desired_capacity 

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  launch_template {
    id      = aws_launch_template.lt.id
    version = aws_launch_template.lt.latest_version
  }
  
  lifecycle {
    create_before_destroy = true
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      # Wait for the health check to pass before moving to the next instance
      instance_warmup        = 300 
    }
  }
}


# --- CONDITIONAL RESOURCES (Points 4 & 5) ---
resource "aws_autoscaling_policy" "scale_out" {
  count = var.enable_autoscaling ? 1 : 0

  name                   = "${local.name_prefix}-scale-out"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count = var.enable_autoscaling ? 1 : 0

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
  
  # Point 5: Using index notation for conditional resources
  alarm_actions     = [aws_autoscaling_policy.scale_out[0].arn] 
}