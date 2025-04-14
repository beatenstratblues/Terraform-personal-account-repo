terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region     = "ap-south-1"
}

resource "aws_vpc" "test-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "New testing vpc"
  }
}

resource "aws_subnet" "test-public" {
  vpc_id                  = aws_vpc.test-vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true


  tags = {
    Name = "Public"
  }
}

resource "aws_subnet" "test-private" {
  vpc_id                  = aws_vpc.test-vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false

  tags = {
    Name = "Private"
  }
}

resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.test-vpc.id

  tags = {
    Name = "allow_tls"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


resource "aws_security_group" "allow_tls_private" {
  name        = "allow_tls_private"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.test-vpc.id

  tags = {
    Name = "allow_tls_private"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4_private" {
  security_group_id = aws_security_group.allow_tls_private.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4_private" {
  security_group_id = aws_security_group.allow_tls_private.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_instance" "web-instance" {
  ami           = "ami-0e35ddab05955cf57"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.test-public.id
  key_name      = "TestKeys"

  vpc_security_group_ids = [aws_security_group.allow_tls.id]

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install git -y
                sudo apt install mysql-server -y
                sudo systemctl start mysql
                sudo systemctl enable mysql
                mkdir Admin_reg_backend
                cd Admin_reg_backend
                git clone https://github.com/beatenstratblues/Admin_registration_backend .
                cd /
                cd Admin_reg_backend
                npm install
                EOF

  tags = {
    Name = "Test Server"
  }
}

resource "aws_instance" "web-instance-private" {
  ami           = "ami-0e35ddab05955cf57"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.test-private.id
  key_name      = "TestKeys"

  vpc_security_group_ids = [aws_security_group.allow_tls.id]

  tags = {
    Name = "Test Server Private"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.test-vpc.id

  tags = {
    Name = "Test VPC Internet Gateway"
  }
}

resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.test-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Public Route table"
  }
}

resource "aws_route_table" "private-route-table" {
  vpc_id = aws_vpc.test-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Public Route table"
  }
}

resource "aws_route_table_association" "public-table" {
  subnet_id      = aws_subnet.test-public.id
  route_table_id = aws_route_table.public-route-table.id
}

resource "aws_route_table_association" "private-table" {
  subnet_id      = aws_subnet.test-private.id
  route_table_id = aws_route_table.private-route-table.id
}

