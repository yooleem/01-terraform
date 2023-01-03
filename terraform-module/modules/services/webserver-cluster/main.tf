terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# 시작 템플릿 설정
resource "aws_launch_template" "example" {
	name                   = "${var.cluster_name}-example"
  image_id               = "ami-06eea3cd85e2db8ce" # Ubuntu 20.04 version
  instance_type          = var.instance_type
  key_name               = "aws04-key"
  vpc_security_group_ids = [aws_security_group.instance.id]

  user_data = base64encode(data.template_file.web_output.rendered)

  lifecycle {
    create_before_destroy = true
  }
}

# 오토스케일링 그룹
resource "aws_autoscaling_group" "example" {
  availability_zones = ["ap-northeast-2a", "ap-northeast-2c"]

  name             = "${var.cluster_name}-asg-example"
  desired_capacity = var.des_size
  min_size         = var.min_size
  max_size         = var.max_size

  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"

  launch_template {
    id      = aws_launch_template.example.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = var.cluster_name
    propagate_at_launch = true
  }
}

# 로드밸런서
resource "aws_lb" "example" {
  name               = var.cluster_name
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb.id]
}

# 로드밸런서 리스너
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"

  # 기본값으로 단순한 404 페이지 오류를 반환한다.
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

# 로드밸런서 리스너 룰 구성
resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

# 로드밸런서 대상그룹
resource "aws_lb_target_group" "asg" {
  name     = var.cluster_name
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# 보안그룹 - instance
resource "aws_security_group" "instance" {
  name = "${var.cluster_name}-instance"
}

resource "aws_security_group_rule" "allow_server_http_inbound" {
	type              = "ingress" 
	security_group_id = aws_security_group.instance.id

	from_port   = var.server_port
	to_port     = var.server_port
	protocol    = local.tcp_protocol
  cidr_blocks = local.all_ips
}


# 보안 그룹 - ALB
resource "aws_security_group" "alb" {
  name = "${var.cluster_name}-alb"
}

resource "aws_security_group_rule" "allow_http_inbound" {
	type              = "ingress"
	security_group_id = aws_security_group.alb.id

  from_port   = local.http_port
  to_port     = local.http_port
	protocol    = local.tcp_protocol
  cidr_blocks = local.all_ips 
}

resource "aws_security_group_rule" "allow_all_outbound" {
	type              = "egress"
	security_group_id = aws_security_group.alb.id

  from_port   = local.any_port
  to_port     = local.any_port
  protocol    = local.any_protocol
  cidr_blocks = local.all_ips
}


data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = var.db_remote_state_bucket
    key    = var.db_remote_state_key
    region = "ap-northeast-2"
  }
}

locals {
	http_port    = 80
	any_port     = 0
	any_protocol = "-1"
	tcp_protocol = "tcp"
	all_ips      = ["0.0.0.0/0"]
}

# Default VPC 정보 가지고 오기
data "aws_vpc" "default" {
  default = true
}

# Subnet 정보 가지고 오기
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "template_file" "web_output" {
  template = file("${path.module}/user-data.sh")
  vars = {
    server_port = var.server_port
    db_address  = data.terraform_remote_state.db.outputs.address
    db_port     = data.terraform_remote_state.db.outputs.port
  }
}

