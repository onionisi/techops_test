# Data Source for Availability Zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Fetch the Latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# AWS VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.13.0"

  name                 = "${var.application}-vpc-${var.environment}"
  cidr                 = var.vpc_cidr
  azs                  = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets       = var.public_subnets
  private_subnets      = var.private_subnets
  enable_nat_gateway   = true
  single_nat_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = var.environment
    Application = var.application
    Terraform   = "true"
  }
}

# Security Group for ALB
module "alb_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.2.0"

  name        = "${var.application}-alb-sg-${var.environment}"
  vpc_id      = module.vpc.vpc_id
  description = "Security group for ALB"

  ingress_rules       = ["http-80-tcp"]
  ingress_cidr_blocks = var.allowed_ips

  tags = {
    Environment = var.environment
    Application = var.application
  }
}

# Security Group for EC2 Instance
module "ec2_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.2.0"

  name        = "${var.application}-ec2-sg-${var.environment}"
  vpc_id      = module.vpc.vpc_id
  description = "Security group for EC2 instance"

  ingress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.alb_sg.security_group_id
      description              = "Allow HTTP from ALB"
    }
  ]

  egress_rules = ["all-all"]

  tags = {
    Environment = var.environment
    Application = var.application
  }
}

# IAM Role for SSM
resource "aws_iam_role" "ec2_ssm_role" {
  name = "${var.application}-ec2-ssm-role-${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json

  tags = {
    Environment = var.environment
    Application = var.application
  }
}

data "aws_iam_policy_document" "ec2_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Attach SSM Managed Policy to Role
resource "aws_iam_role_policy_attachment" "ssm_managed_policy" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance Profile
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${var.application}-ec2-instance-profile-${var.environment}"
  role = aws_iam_role.ec2_ssm_role.name
}

# AWS EC2 Instance Module
module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.7.0"

  name                        = "${var.application}-ec2-${var.environment}"
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids      = [module.ec2_sg.security_group_id]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name
  user_data                   = file("userdata.sh")
  monitoring                  = true

  tags = {
    Environment = var.environment
    Application = var.application
    Name        = "${var.application}-ec2-${var.environment}"
  }
}

# AWS ALB Module
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.11.0"

  name               = "${var.application}-alb-${var.environment}"
  load_balancer_type = "application"
  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets
  security_groups    = [module.alb_sg.security_group_id]

  listeners = {
    http_listeners = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "ghost-target"
      }
    }
  }

  target_groups = {
    ghost-target = {
      name_prefix = "cms-tg"
      protocol    = "HTTP"
      port        = 80 # Using port 80
      target_type = "instance"
      target_id   = module.ec2_instance.id

      health_check = {
        enabled             = true
        path                = "/"
        matcher             = "200-399"
        interval            = 30
        unhealthy_threshold = 2
        healthy_threshold   = 5
        timeout             = 5
      }
    }
  }

  tags = {
    Environment = var.environment
    Application = var.application
    Terraform   = "true"
  }
}
