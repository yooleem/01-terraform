provider "local" {
}

variable "user_names" {
  description = "Create IAM users with these names"
  type        = list(string)
  default     = ["aws04-neo", "aws04-trinity", "aws04-morpheus"]
}

output "for_directive" {
  value = <<EOF
		%{~for name in var.user_names}
			${name}
		%{~endfor}
			EOF
}
