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

# Create a security group for the EC2 instance
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-security-group"
  description = "Security group for EC2 instance with restricted SSH and RDP access"

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
  associate_public_ip_address = true

  # Attach the security group
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  # Specify the key pair for SSH access (replace with your key pair name)
  key_name = "my-key-pair" # Ensure this key pair exists in your AWS account

  tags = {
    Name = "example-ec2-instance"
    Environment = "Production"
  }
}

# Output the public IP of the EC2 instance
output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.example.public_ip
}
