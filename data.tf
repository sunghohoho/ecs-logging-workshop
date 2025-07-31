# 현재 설정된 AWS 리전 정보 불러오기
data "aws_region" "current" {}

# data "aws_region" "current" {
#   region = var.region
# }
# 현재 설정된 AWS 리전에 있는 가용영역 정보 불러오기
data "aws_availability_zones" "azs" {}

# AWS 자격증명 정보
data "aws_caller_identity" "current" {}

# # Route53 호스트존
# data "aws_route53_zone" "ksh" {
#   provider = aws.ksh

#   name = "gguduck.com."
# }

# IMG_3389.jpg  IMG_3391.jpg  IMG_3393.jpg
# IMG_3390.jpg  IMG_3392.jpg  IMG_3394.jpg