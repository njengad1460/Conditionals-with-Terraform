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


variable "use_existing_vpc" {
  description = "Set to true to use an existing VPC instead of creating a new one"
  type        = bool
  default     = false # Default to false so your current setup doesn't break. use false in dev env
}

variable "existing_vpc_id" {
  description = "The ID of the existing VPC (only used if use_existing_vpc is true)"
  type        = string
  default     = null
}

variable "environment" {
  type        = string
  description = "The deployment environment (dev or prod)"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be either 'dev' or 'prod'."
  }
}