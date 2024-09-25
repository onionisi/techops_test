variable "aws_region" {
  type    = string
  default = "ap-southeast-2"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/20"
}

variable "public_subnets" {
  type        = list(string)
  description = "List of public subnet CIDR blocks"
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "private_subnets" {
  type        = list(string)
  description = "List of private subnet CIDR blocks"
  default     = ["10.0.100.0/24", "10.0.101.0/24"]
}

variable "key_name" {
  type    = string
  default = "deployer_key"
}

variable "public_key_path" {
  type    = string
  default = "~/.ssh/techops.pub"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.micro"
}

variable "application" {
  type        = string
  description = "The application name"
  default     = "techops-cms"
}

variable "environment" {
  type        = string
  description = "Deployment environment (e.g., development, staging, production)"
  default     = "development"
}
