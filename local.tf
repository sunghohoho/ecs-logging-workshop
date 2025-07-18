# 로컬 환경변수 지정
locals {
  project = "ecs-logging-workshop"
}

# 태그
locals {
  tags = {
    Project = local.project
  }
}