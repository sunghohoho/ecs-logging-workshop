# VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.21.0"

  name = local.project
  cidr = var.vpc_cidr

  # 서브넷
  azs             = data.aws_availability_zones.azs.names
  public_subnets  = [for idx, _ in data.aws_availability_zones.azs.names : cidrsubnet(var.vpc_cidr, 8, idx)]
  private_subnets = [for idx, _ in data.aws_availability_zones.azs.names : cidrsubnet(var.vpc_cidr, 8, idx + 10)]

  # NAT 게이트웨이
  enable_nat_gateway = true
  single_nat_gateway = true
}

# Route53 호스트존
resource "random_string" "domain_prefix" {
  length  = 16
  upper   = false
  numeric = false
  special = false
}
