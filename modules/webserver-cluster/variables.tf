variable "vpc_cidr" {
  type = string
}

variable "vpc_name" {
  type = string
}

# Useing map instead of list
variable "public_subnets" {
  description = "Map for public subnets"
  type = map(object({
    cidr = string
    az = string
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
    type =number 
}

# use of condition control

variable "enable_autoscaling" {
  type = bool
  default = true
}

# environment based logic 
variable "environment" {
  type = string
}