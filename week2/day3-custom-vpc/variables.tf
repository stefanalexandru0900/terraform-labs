variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "my_ip_cidr" {
  type        = string
  description = "Your public IP in CIDR format (x.x.x.x/32)"
}

variable "key_pair_name" {
  type        = string
  description = "Existing EC2 key pair name"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}