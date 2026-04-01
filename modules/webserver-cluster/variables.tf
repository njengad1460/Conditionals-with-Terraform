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

variable "environment" {
  description = "The deployment environment (dev or prod)"
  type        = string

  validation {
    # The condition must return true for the validation to pass
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be either 'dev' or 'prod'."
  }
}


variable "use_existing_vpc" {
  description = "If true, look up an existing VPC instead of creating a new one"
  type        = bool
  default     = false
}

variable "existing_vpc_id" {
  description = "The ID of the existing VPC to use (required if use_existing_vpc is true)"
  type        = string
  default     = null
}