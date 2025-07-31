# 요구되는 테라폼 제공자 목록
terraform {
  required_version = "1.12.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.4.0"
    }
  }
}


# AWS 제공자 설정
provider "aws" {
  # 해당 테라폼 모듈을 통해서 생성되는 모든 AWS 리소스에 아래의 태그 부여
  default_tags {
    tags = local.tags
  }
}

provider "aws" {
  alias = "ksh"

  assume_role {
    role_arn = "arn:aws:iam::866477832211:role/AmazonRoute53FullAccess-Role"
  }
}
