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
  enable_nat_gateway   = false
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "${var.application}-alb-sg-${var.environment}"
  description = "Security group for ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow HTTP from allowed IPs"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_ips
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment
    Name        = "${var.application}-alb-sg-${var.environment}"
  }
}

# Security Group for EC2 Instance
resource "aws_security_group" "ec2_sg" {
  name        = "${var.application}-ec2-sg-${var.environment}"
  description = "Security group for EC2 instance"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Allow traffic from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment
    Name        = "${var.application}-ec2-sg-${var.environment}"
  }
}

# IAM Role for SSM
resource "aws_iam_role" "ec2_ssm_role" {
  name = "${var.application}-ec2-ssm-role-${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json

  tags = {
    Environment = var.environment
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

  name                        = "${var.application}-ghost-server-${var.environment}"
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name
  user_data                   = file("userdata.sh")

  tags = {
    Environment = var.environment
    Name        = "${var.application}-ghost-server-${var.environment}"
  }
}

# Target Group
resource "aws_lb_target_group" "ghost_tg" {
  name     = "${var.application}-ghost-tg-${var.environment}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path                = "/"
    matcher             = "200-3997"
    interval            = 30
    unhealthy_threshold = 2
    healthy_threshold   = 5
    timeout             = 5
  }

  tags = {
    Environment = var.environment
  }
}

# AWS ALB Module
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "8.0.0"

  name               = "${var.application}-alb-${var.environment}"
  load_balancer_type = "application"
  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets
  security_groups    = [aws_security_group.alb_sg.id]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  target_groups = [
    {
      name_prefix      = "ghost"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
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
  ]

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

# Attach EC2 Instance to Target Group
resource "aws_lb_target_group_attachment" "ghost_tg_attachment" {
  target_group_arn = module.alb.target_group_arns[0]
  target_id        = module.ec2_instance.id
  port             = 80
}
