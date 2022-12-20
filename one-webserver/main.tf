terraform {
  # 테라폼 버전 지정
  required_version = ">= 1.0.0, < 2.0.0"

  # 공급자 버전 지정
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

resource "aws_instance" "example" {
  ami           = "ami-06eea3cd85e2db8ce" # Ubuntu 20.04 version
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.instance.id]
  
  key_name = "aws04-key"

  user_data = <<-EOF
			  #!/bin/bash
			  echo "Hello, World" >index.html
			  nohup busybox httpd -f -p 8080 &
			  EOF

  tags = {
    Name = "aws04-terraform-example"
  }
}

# 보안그룹 생성
resource "aws_security_group" "instance" {
  name = "aws04-terraform-example-instance"

  # 인바운드 규칙 설정
  ingress {
    from_port   = 8080  # 출발 포트
    to_port     = 8080  # 도착 포트
    protocol    = "tcp" # 프로토콜
    cidr_blocks = ["0.0.0.0/0"] # 송신지 
  }
}

# 출력 지정
output "public-ip" {
  value       = aws_instance.example.public_ip
  description = "The Public IP of the Instance"
}
