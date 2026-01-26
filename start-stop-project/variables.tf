variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "my_ip_cidr" {
  type        = string
  description = "Your PUBLIC IP in CIDR format (example: 86.123.45.67/32)"
  default     = "0.0.0.0/32"
}

variable "asg_desired" {
  type        = number
  description = "Default desired capacity for ASG when Terraform applies"
  default     = 0
}

variable "key_name" {
  type        = string
  description = "EC2 key pair name (optional; needed only if you want to use it)"
  default     = null
}

variable "github_org" {
  type        = string
  description = "GitHub organization/user name (owner of the repo)"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name"
}
