variable "region" {
  description = "현재 리전"
  type = string
  default = "ap-northeast-2"
}

variable "vpc_cidr" {
  description = "VPC 대역대"
  type        = string
  default     = "10.0.0.0/16"
}