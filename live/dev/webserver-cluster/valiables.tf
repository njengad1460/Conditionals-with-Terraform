variable "vpc_cidr" {
  description = "The CIDR block for the dev VPC"
  type        = string
}

variable "vpc_name" {
  description = "The name tag for the dev VPC"
  type        = string
}

variable "public_subnets" {
  description = "Map of public subnets for dev"
  type = map(object({
    cidr = string
    az   = string
  }))
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