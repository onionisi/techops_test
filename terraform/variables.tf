variable "aws_region" {
  type    = string
  default = "ap-southeast-2"
}

variable "aws_profile" {
  type    = string
  default = "chong"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  type        = list(string)
  description = "List of public subnet CIDR blocks"
  default     = ["10.0.1.0/24"]
}

variable "private_subnets" {
  type        = list(string)
  description = "List of private subnet CIDR blocks"
  default     = ["10.0.2.0/24"]
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

variable "allowed_ips" {
  type        = list(string)
  description = "List of CIDR blocks allowed to access the ALB"
  default     = ["0.0.0.0/0"] # For ALB access; restrict in production
}
