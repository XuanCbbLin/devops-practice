provider "aws" {
  region = "us-east-1"
}

# ==========================================================
# 1. 建立本地 SSH 金鑰
# ==========================================================
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# 將公鑰上傳到 AWS
resource "aws_key_pair" "generated_key" {
  key_name   = "my-tf-key"
  public_key = tls_private_key.ec2_key.public_key_openssh

  tags = {
    Name = "my-tf-key"
  }
}

# 將私鑰儲存在本地端（不會上傳到 AWS）
resource "local_file" "private_key" {
  filename        = "${path.module}/my-tf-key.pem"
  content         = tls_private_key.ec2_key.private_key_pem
  file_permission = "0400"
}

# ==========================================================
# 2. 建立 VPC 與 Subnets
# ==========================================================
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "my-vpc"
  }
}

# Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

# Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet"
  }
}

# ==========================================================
# 3. 建立 Gateways
# ==========================================================
# Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "my-igw"
  }
}

# NAT Gateway 用的 EIP
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "my-nat-eip"
  }
}

# NAT Gateway（放在 Public Subnet）
resource "aws_nat_gateway" "my_nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "my-nat-gateway"
  }

  depends_on = [aws_internet_gateway.my_igw]
}

# ==========================================================
# 4. Route Tables
# ==========================================================
# Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "public-rt"
  }
}

# Private Route Table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.my_nat_gateway.id
  }

  tags = {
    Name = "private-rt"
  }
}

# Subnet 關聯
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

# ==========================================================
# 5. Security Groups
# ==========================================================
# Public SG：允許 SSH from anywhere（測試用）
resource "aws_security_group" "public_sg" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "public-sg"
  }
}

# Private SG：允許來自 VPC 的 SSH
resource "aws_security_group" "private_sg" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private-sg"
  }
}

# ==========================================================
# 6. 建立 EC2 Instances
# ==========================================================
# Public EC2
resource "aws_instance" "public_ec2" {
  ami                         = "ami-0c02fb55956c7d316" # Amazon Linux 2
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.public_sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.generated_key.key_name

  tags = {
    Name = "public-ec2"
  }
}

# Private EC2
resource "aws_instance" "private_ec2" {
  ami                    = "ami-0c02fb55956c7d316"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  associate_public_ip_address = false
  key_name               = aws_key_pair.generated_key.key_name

  tags = {
    Name = "private-ec2"
  }

  depends_on = [aws_nat_gateway.my_nat_gateway]
}

# ==========================================================
# 7. 輸出資訊
# ==========================================================
output "private_key_file" {
  description = "Path of the generated private key file"
  value       = local_file.private_key.filename
}

output "public_ec2_public_ip" {
  description = "Public IP of the public EC2 instance"
  value       = aws_instance.public_ec2.public_ip
}

output "private_ec2_private_ip" {
  description = "Private IP of the private EC2 instance"
  value       = aws_instance.private_ec2.private_ip
}
