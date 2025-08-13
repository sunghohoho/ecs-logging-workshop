locals {
  http_port = 80
  nginx_port = 8080
}

module "ecs" {
  source = "terraform-aws-modules/ecs/aws"

  cluster_name = local.project
  
  # Cluster 로깅 설정
  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = "/aws/ecs/${local.project}-${random_string.domain_prefix.result}"
      }
    }
  }

  # 기본 용량공급자 설정
  default_capacity_provider_strategy = {
    FARGATE = {
      weight = 50
      base   = 20
    }
    FARGATE_SPOT = {
      weight = 50
    }
  }
  
  # EC2 유형의 용량 공급자 설정, 아래 선언한 Autoscaling 지정
  autoscaling_capacity_providers = {
    # On-demand instances
    ex_1 = {
      auto_scaling_group_arn         = module.autoscaling["ex_1"].autoscaling_group_arn
      managed_draining               = "ENABLED"
      managed_termination_protection = "ENABLED"

      managed_scaling = {
        maximum_scaling_step_size = 1
        minimum_scaling_step_size = 1
        status                    = "ENABLED"
        target_capacity           = 60
      }
    }
  }

  # 서비스 설정
  services = {
    web-service = {
      cpu    = 512
      memory = 1024
      capacity_provider_strategy = {
        # On-demand instances
        ex_1 = {
          capacity_provider = "ex_1"
          weight            = 1
          base              = 1
        }
      }
      container_definitions = {
        web-containers = {
          cpu       = 256
          memory    = 256
          essential = true
          image     = "public.ecr.aws/d4j3m3g7/gguduck/registry:websv0.5"
          requires_compatibilities = ["EC2"]
          launch_type = "EC2"
          portMappings = [
            {
              name          = "web-container-port"
              containerPort = local.http_port
              protocol      = "tcp"
            }
          ]
          
          # Cloudwatch Logs로 향하도록 awslogs 로그 드라이버 설정
          logConfiguration = {
            logDriver = "awslogs"
            options = {
              awslogs-region        = "ap-northeast-2"
              awslogs-group         = "/ecs-workshop/${local.project}/webs"
              awslogs-create-group  = "true"
              awslogs-stream-prefix = "webs"
            }
          }
          readonlyRootFilesystem    = false
          enable_cloudwatch_logging = false
          memoryReservation         = 100
        }
      }
      
      # 서비스 실행 시 Cloudwatch Log 그룹 생성을 위한 task 실행역할 생성
      task_exec_iam_statements = [
        {
          sid       = "AllowCloudWatchLogs"
          actions   = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          effect    = "Allow"
          resources = ["*"]
        }
      ]
      
      # 서비스 구성을 위한 로드 밸런서 설정
      load_balancer = {
        service = {
          target_group_arn = module.alb.target_groups["web-target"].arn
          container_name   = "web-containers"
          container_port   = local.http_port
        }
      }

      subnet_ids = module.vpc.private_subnets
      security_group_ingress_rules = {
        alb_80 = {
          description                  = "Service port"
          from_port                    = local.http_port
          ip_protocol                  = "tcp"
          referenced_security_group_id = module.alb.security_group_id
        }
      }
      security_group_egress_rules = {
        all = {
          ip_protocol = "-1"
          cidr_ipv4   = "0.0.0.0/0"
        }
      }
    }

    cat-service = {
      cpu    = 1024
      memory = 4096

      container_definitions = {
        cat-containers = {
          cpu       = 256
          memory    = 256
          essential = true
          image     = "public.ecr.aws/d4j3m3g7/gguduck/registry:catsv0.1"
          portMappings = [
            {
              name          = "cat-container-port"
              containerPort = local.http_port
              protocol      = "tcp"
            }
          ]
          readonlyRootFilesystem    = false
          enable_cloudwatch_logging = true
          memoryReservation         = 100
        }
      }

      load_balancer = {
        service = {
          target_group_arn = module.alb.target_groups["cat-target"].arn
          container_name   = "cat-containers"
          container_port   = local.http_port
        }
      }

      subnet_ids = module.vpc.private_subnets
      security_group_ingress_rules = {
        alb_80 = {
          description                  = "Service port"
          from_port                    = local.http_port
          ip_protocol                  = "tcp"
          referenced_security_group_id = module.alb.security_group_id
        }
      }
      security_group_egress_rules = {
        all = {
          ip_protocol = "-1"
          cidr_ipv4   = "0.0.0.0/0"
        }
      }
    }

    dog-service = {
      cpu    = 1024
      memory = 4096

      container_definitions = {
        dog-containers = {
          cpu       = 256
          memory    = 256
          essential = true
          image     = "public.ecr.aws/d4j3m3g7/gguduck/registry:dogsv0.1"
          portMappings = [
            {
              name          = "dog-container-port"
              containerPort = local.http_port
              protocol      = "tcp"
            }
          ]
          readonlyRootFilesystem    = false
          enable_cloudwatch_logging = true
          memoryReservation         = 100
        }
      }

      load_balancer = {
        service = {
          target_group_arn = module.alb.target_groups["dog-target"].arn
          container_name   = "dog-containers"
          container_port   = local.http_port
        }
      }

      subnet_ids = module.vpc.private_subnets
      security_group_ingress_rules = {
        alb_80 = {
          description                  = "Service port"
          from_port                    = local.http_port
          ip_protocol                  = "tcp"
          referenced_security_group_id = module.alb.security_group_id
        }
      }
      security_group_egress_rules = {
        all = {
          ip_protocol = "-1"
          cidr_ipv4   = "0.0.0.0/0"
        }
      }
    }
  
    # 로그 생성을 위한 서비스 생성
    log-service = {
      cpu    = 1024
      memory = 4096
      
     # log continaer의 경우 EC2 위에 띄우기 위해 용량공급자 EC2로 설정
      capacity_provider_strategy = {
        # On-demand instances
        ex_1 = {
          capacity_provider = "ex_1"
          weight            = 1
          base              = 1
        }
      }
      
      container_definitions = {
        # aws-for-fluentbit 컨테이너 생성, 사이드카 설정
        fluent-bit = {
          cpu       = 256
          memory    = 512
          essential = true
          image     = "public.ecr.aws/aws-observability/aws-for-fluent-bit:stable"
          firelensConfiguration = {
            type = "fluentbit"
          }
          environment = [
            {
                "name": "aws_fluent_bit_config",
                "value": "arn:aws:s3:::${aws_s3_bucket.fluentbit-conf.id}/init"
            }
          ]
          memoryReservation = 50
        }

        log-containers = {
          cpu       = 256
          memory    = 512
          essential = true
          image     = "public.ecr.aws/d4j3m3g7/gguduck/registry:logsv2.3"
          requires_compatibilities = ["EC2"]
          launch_type = "EC2"
          
          portMappings = [
            {
              name          = "log-container-port"
              containerPort = local.nginx_port
              protocol      = "tcp"
            }
          ]
          readonlyRootFilesystem = false
          dependsOn = [{
            containerName = "fluent-bit"
            condition     = "START"
          }]
          enable_cloudwatch_logging = false
          
          # fluentbit 설정을 위한 awsfirelens 로그 드라이버 설정
          # app -> fluentbit -> cloudwatch logs로 전달하도록 옵션 설정
          logConfiguration = {
            logDriver = "awsfirelens"
            options = {
              Name             = "cloudwatch"
              region           = "ap-northeast-2"
              log_key          = "log"
              log_group_name   = "/ecs-workshop/${local.project}/application"
              auto_create_group = "true"
              log_stream_name  = "${local.project}"
              retry_limit      = "2"
            }
          }
          memoryReservation = 100
        }
      }
      
      # Cloudwatch Logs 생성을 위한 권한 부여
      tasks_iam_role_statements = [
        {
          sid       = "Allowfirehose"
          actions   = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:DescribeLogStreams",
            "s3:*"
          ]
          effect    = "Allow"
          resources = ["*"]
        }
      ]
      
      load_balancer = {
        service = {
          target_group_arn = module.alb.target_groups["log-target"].arn
          container_name   = "log-containers"
          container_port   = local.nginx_port
        }
      }

      subnet_ids = module.vpc.private_subnets
      security_group_ingress_rules = {
        alb_8080 = {
          description                  = "Service port"
          from_port                    = local.nginx_port
          ip_protocol                  = "tcp"
          referenced_security_group_id = module.alb.security_group_id
        }
      }
      security_group_egress_rules = {
        all = {
          ip_protocol = "-1"
          cidr_ipv4   = "0.0.0.0/0"
        }
      }
    }
  }

  depends_on = [module.alb]
}

# 정상 배포되면 이후에 아래 명령어로 asg 갯수 1개로 증가

# aws autoscaling update-auto-scaling-group \
#   --auto-scaling-group-name $(terraform output -raw asg_name) \
#   --min-size 1 \
#   --max-size 1 \
#   --desired-capacity 1 \
#   --region ap-northeast-2

# ec2 접근 후 sudo -i
# docker exec -it $(docker ps --filter "ancestor=public.ecr.aws/aws-observability/aws-for-fluent-bit:stable" -q) sh

# fluentbit 경로  컨테이너 내부에서 /fluent-bit/etc
# cd /fluent-bit/etc

# cd /var/lib/docker/containers/$(docker ps --filter "ancestor=public.ecr.aws/d4j3m3g7/gguduck/registry:websv0.5" -q) sh