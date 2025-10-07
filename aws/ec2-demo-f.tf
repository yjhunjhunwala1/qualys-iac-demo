provider "aws" {
  region = "us-east-1" # Specify your desired AWS region
}

# Data source to get the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "ec2-vpc"
    Environment = "Production"
  }
}

# Create a public subnet
resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a" # Adjust based on your region

  tags = {
    Name = "public-subnet"
    Environment = "Production"
  }
}

# Create an internet gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "ec2-igw"
    Environment = "Production"
  }
}

# Create a route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-route-table"
    Environment = "Production"
  }
}

# Associate route table with subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Create a security group for the EC2 instance
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-security-group"
  description = "Security group for EC2 instance with restricted SSH and RDP access"
  vpc_id      = aws_vpc.main.id

  # Allow SSH (port 22) from specific IP range
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["203.0.113.0/24"] # Replace with your specific IP range
    description = "Allow SSH access from specific IP range"
  }

  # Allow RDP (port 3389) from specific IP range
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["203.0.113.0/24"] # Replace with your specific IP range
    description = "Allow RDP access from specific IP range"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "ec2-security-group"
    Environment = "Production"
  }
}

# Create an EC2 instance
resource "aws_instance" "example" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro" # Free tier eligible instance type
  associate_public_ip_address = false # Qualys CID=328: No public IP
  subnet_id     = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name      = "my-key-pair" # Ensure this key pair exists in your AWS account
  monitoring    = true # Qualys CID=350: Enable detailed monitoring
  ebs_optimized = true # Qualys CID=357: Enable EBS optimization

  # Qualys CID=322: Configure IMDSv2
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  # Qualys CID=286: Enable EBS encryption for root block device
  root_block_device {
    encrypted   = true
    volume_type = "gp2"
    volume_size = 8
  }

  tags = {
    Name = "example-ec2-instance"
    Environment = "Production"
  }
}

# Output the private IP of the EC2 instance
output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.example.private_ip
}
