terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_availability_zones" "azs" {}

# ---------------------------
# VPC + Networking
# ---------------------------
resource "aws_vpc" "lab" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "lab-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.lab.id
  tags   = { Name = "lab-igw" }
}

# Public subnets (ALB)
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = data.aws_availability_zones.azs.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "lab-public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = "10.20.2.0/24"
  availability_zone       = data.aws_availability_zones.azs.names[1]
  map_public_ip_on_launch = true
  tags                    = { Name = "lab-public-b" }
}

# Private subnets (ASG + DB)
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.lab.id
  cidr_block        = "10.20.11.0/24"
  availability_zone = data.aws_availability_zones.azs.names[0]
  tags              = { Name = "lab-private-a" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.lab.id
  cidr_block        = "10.20.12.0/24"
  availability_zone = data.aws_availability_zones.azs.names[1]
  tags              = { Name = "lab-private-b" }
}

# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id
  tags   = { Name = "lab-public-rt" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway for private subnets (so Windows can download updates)
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "lab-nat-eip" }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
  tags          = { Name = "lab-nat" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.lab.id
  tags   = { Name = "lab-private-rt" }
}

resource "aws_route" "private_to_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# ---------------------------
# Security Groups
# ---------------------------
resource "aws_security_group" "alb_sg" {
  name        = "lab-alb-sg"
  description = "Allow HTTP from internet"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app_sg" {
  name        = "lab-app-sg"
  description = "Allow HTTP only from ALB + RDP from my IP"
  vpc_id      = aws_vpc.lab.id

  # HTTP from ALB only
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # RDP from your public IP
  ingress {
    description = "RDP from my IP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db_sg" {
  name        = "lab-db-sg"
  description = "SQL from app SG + RDP from my IP"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description     = "SQL Server from App"
    from_port       = 1433
    to_port         = 1433
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  ingress {
    description = "RDP from my IP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------
# ALB + Target Group
# ---------------------------
resource "aws_lb" "alb" {
  name               = "lab-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = { Name = "lab-alb" }
}

resource "aws_lb_target_group" "tg" {
  name     = "lab-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.lab.id

  health_check {
    path                = "/"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    matcher             = "200-399"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# ---------------------------
# AMIs (Windows Server)
# ---------------------------
data "aws_ami" "windows_2022" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
}

# ---------------------------
# Launch Template + ASG
# ---------------------------
locals {
  user_data_ps1 = <<-EOT
<powershell>
Install-WindowsFeature -Name Web-Server
New-Item -ItemType Directory -Force -Path C:\\inetpub\\wwwroot | Out-Null
Set-Content -Path C:\\inetpub\\wwwroot\\index.html -Value "<h1>Lab Web Page - $(hostname)</h1>"
Restart-Service W3SVC
</powershell>
EOT
}

resource "aws_launch_template" "app" {
  name_prefix   = "lab-app-"
  image_id      = data.aws_ami.windows_2022.id
  instance_type = "t3.large"
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.app_sg.id]

  user_data = base64encode(local.user_data_ps1)

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "lab-app"
      Lab  = "terraform-lab"
    }
  }
}

resource "aws_autoscaling_group" "app" {
  name                      = "lab-app-asg"
  max_size                  = 1
  min_size                  = 0
  desired_capacity          = var.asg_desired
  vpc_zone_identifier       = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  health_check_type         = "ELB"
  health_check_grace_period = 120

  target_group_arns = [aws_lb_target_group.tg.arn]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Lab"
    value               = "terraform-lab"
    propagate_at_launch = true
  }
}

# ---------------------------
# DB Instance + data volume
# ---------------------------
resource "aws_instance" "db" {
  ami                    = data.aws_ami.windows_2022.id
  instance_type          = "t3.large"
  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  key_name               = var.key_name

  tags = {
    Name = "lab-db"
    Lab  = "terraform-lab"
  }
}

# Extra EBS volume for DB data (D:)
resource "aws_ebs_volume" "db_data" {
  availability_zone = aws_instance.db.availability_zone
  size              = 50
  type              = "gp3"

  tags = {
    Name = "lab-db-data"
    Lab  = "terraform-lab"
  }
}

resource "aws_volume_attachment" "db_data_attach" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.db_data.id
  instance_id = aws_instance.db.id
}
