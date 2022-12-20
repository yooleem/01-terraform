# 공급자에 대한 내용
provider "local" {
}

# Infra resource
resource "local_file" "foo" {
  filename = "${path.module}/foo.txt"
  content  = data.local_file.bar.content
}

# 테라폼에서 사용할 입력 데이터 지정
data "local_file" "bar" {
  filename = "${path.module}/bar.txt"
}

# 출력 지정
output "bar_content" {
  value = data.local_file.bar.content
}
