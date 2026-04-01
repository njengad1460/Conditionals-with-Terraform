variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the production VPC"
}

variable "vpc_name" {
  type        = string
  description = "The name of the production VPC"
}

variable "public_subnets" {
  type = map(object({
    cidr = string
    az   = string
  }))
  description = "Map of public subnets for prod"
}

variable "min_size" {
  type = number
}

variable "max_size" {
  type = number
}

variable "desired_capacity" {
  type = number
}

variable "server_port" {
  type = number
}

variable "enable_autoscaling" {
  type = bool
}

variable "environment" {
  type = string
}