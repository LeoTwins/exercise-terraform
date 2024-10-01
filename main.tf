provider "aws" {
  region = "ap-northeast-1"
}

# VPC
resource "aws_vpc" "exercise-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "exercise-vpc"
  }
}

# IGW
resource "aws_internet_gateway" "exercise-igw" {
  vpc_id = aws_vpc.exercise-vpc.id
  tags = {
    Name = "exercise-igw"
  }
}

# route table
resource "aws_route_table" "exercise-route-table" {
  vpc_id = aws_vpc.exercise-vpc.id

  tags = {
    Name = "exercise-route-table"
  }
}

# route
resource "aws_route" "exercise-route-ipv4" {
  route_table_id = aws_route_table.exercise-route-table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.exercise-igw.id
}

resource "aws_route" "exercise-route-ipv6" {
  route_table_id = aws_route_table.exercise-route-table.id
  destination_ipv6_cidr_block = "::/0"
  gateway_id = aws_internet_gateway.exercise-igw.id
}

# subnet
resource "aws_subnet" "exercise-subnet" {
  vpc_id = aws_vpc.exercise-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-northeast-1a"
  tags = {
    Name = "exercise-subnet"
  }
}

# subnetとroute tableの紐付け
resource "aws_route_table_association" "exercise-association" {
  route_table_id = aws_route_table.exercise-route-table.id
  subnet_id = aws_subnet.exercise-subnet.id
}

# Security Group
resource "aws_security_group" "exercise-security-group" {
  name = "exercise-security-group"
  description = "Allow web inbound traffic"
  vpc_id = aws_vpc.exercise-vpc.id

  ingress {
    description = "https"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "http"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ssh"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "exercise-security-group"
  }
}

# ENI
resource "aws_network_interface" "exercise-nw-interface" {
  subnet_id = aws_subnet.exercise-subnet.id
  private_ips = ["10.0.1.50"]
  security_groups = [aws_security_group.exercise-security-group.id]
}

# EIP
resource "aws_eip" "exercise-eip" {
  network_interface = aws_network_interface.exercise-nw-interface.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [ aws_internet_gateway.exercise-igw,  aws_instance.exercise-instance ]
}

# Webサーバー
resource "aws_instance" "exercise-instance" {
  ami = var.ami_id
  instance_type = "t2.micro"
  availability_zone = "ap-northeast-1a"
  key_name = "exercise-key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.exercise-nw-interface.id
  }

  user_data = <<-EOF
    #!/bin/bash
    # Update the package repository
    sudo yum update -y
    
    # Install Docker
    sudo yum install -y docker

    # Start Docker service
    sudo systemctl start docker

    # Enable Docker to start on boot
    sudo systemctl enable docker
  EOF

  tags = {
    Name = "exercise-instance"
  }
}