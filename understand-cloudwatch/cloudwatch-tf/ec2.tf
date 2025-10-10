# EC2 IAM Role（允許 CloudWatch Agent 傳資料）
resource "aws_iam_role" "cw_agent_role" {
  name = "EC2CloudWatchAgentRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cw_agent_attach" {
  role       = aws_iam_role.cw_agent_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "cw_profile" {
  name = "cw-agent-instance-profile"
  role = aws_iam_role.cw_agent_role.name
}

# 安全組
data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2-ssh-sg"
  description = "Allow SSH"
  vpc_id      = data.aws_vpc.default.id

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
}

# EC2 Instance（自動安裝 CloudWatch Agent）
resource "aws_instance" "monitor_ec2" {
  ami                         = "ami-0c02fb55956c7d316" # Amazon Linux 2
  instance_type               = "t2.micro"
  iam_instance_profile         = aws_iam_instance_profile.cw_profile.name
  key_name                    = aws_key_pair.generated_key.key_name
  vpc_security_group_ids       = [aws_security_group.ec2_sg.id]
  associate_public_ip_address  = true

  # ✅ 自動安裝並啟動 CloudWatch Agent
  user_data = <<-EOF
              #!/bin/bash
              yum install -y amazon-cloudwatch-agent
              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
                -a fetch-config -m ec2 \
                -c default \
                -s
              EOF

  tags = {
    Name = "Monitor-EC2"
  }
}
