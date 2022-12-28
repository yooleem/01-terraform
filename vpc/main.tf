provider "aws" {
  region = "ap-northeast-2"
}

data "aws_vpc" "default" {
  default = true
}

/*
다른 VPC를 사용할려면 
data "aws_vpc" "project-vpc" {
	id = "<사용하려는 VPC ID>"
}

data "aws_vpc" "project-vpc" {
	filter {
		name = "tag:Name"
		value = ["Project-VPC"]
	}
}
*/

data "aws_subnets" "example" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "example" {
  for_each = toset(data.aws_subnets.example.ids)
  id       = each.value
}

output "vpc-id" {
  value = data.aws_vpc.default.id
}

output "subnet_cidr_blocks" {
  value = [for s in data.aws_subnet.example : s.cidr_block]
}
