variable "aws_region"{
    type = string
    default = "eu-central-1"
}

variable "state_bucket_name" {
  type = string
  description = "Must be globally unique"
}

variable "lock_table_name" {
  type = string
  default = "terraform-state-locks"
}