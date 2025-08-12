locals {
  # container_name = "ecs-ns"
  http_port = 80
  nginx_port = 8080
  # svc-name = ["web","cat","dog"]
}

module "ecs" {
  source = "terraform-aws-modules/ecs/aws"

  cluster_name = local.project

  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = "/aws/ecs/${local.project}-${random_string.domain_prefix.result}"
      }
    }
  }

  # Cluster capacity providers
  default_capacity_provider_strategy = {
    FARGATE = {
      weight = 50
      base   = 20
    }
    FARGATE_SPOT = {
      weight = 50
    }
  }

  services = {
    web-service = {
      cpu    = 1024
      memory = 4096

      container_definitions = {
        web-containers = {
          cpu       = 256
          memory    = 256
          essential = true
          image     = "public.ecr.aws/d4j3m3g7/gguduck/registry:websv0.5"
          portMappings = [
            {
              name          = "web-container-port"
              containerPort = local.http_port
              protocol      = "tcp"
            }
          ]
          logConfiguration = {
            logDriver = "awslogs"
            options = {
              awslogs-region        = "ap-northeast-2"
              awslogs-group         = "/ecs/${local.project}/webs"
              awslogs-create-group  = "true"
              awslogs-stream-prefix = "webs"
            }
          }
          readonlyRootFilesystem    = false
          enable_cloudwatch_logging = false
          memoryReservation         = 100
        }
      }

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

    log-service = {
      cpu    = 1024
      memory = 4096

      container_definitions = {
        fluent-bit = {
          cpu       = 512
          memory    = 1024
          essential = true
          image     = "public.ecr.aws/aws-observability/aws-for-fluent-bit:stable"
          firelensConfiguration = {
            type = "fluentbit"
          }
          memoryReservation = 50
        }

        log-containers = {
          cpu       = 512
          memory    = 1024
          essential = true
          image     = "public.ecr.aws/d4j3m3g7/gguduck/registry:logsv2.3"
          # requires_compatibilities = ["EC2"]
          # launch_type = "EC2"
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
          logConfiguration = {
            logDriver = "awsfirelens"
            options = {
              Name             = "cloudwatch"
              region           = "ap-northeast-2"
              log_key          = "log"
              log_group_name   = "/aws/ecs/${local.project}/application"
              auto_create_group = "true"
              log_stream_name  = "${local.project}"
              retry_limit      = "2"
            }
          }
          memoryReservation = 100
        }
      }

      tasks_iam_role_statements = [
        {
          sid       = "Allowfirehose"
          actions   = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:DescribeLogStreams"
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

#############################################################################
#ALB 생성
#############################################################################
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.0"

  name = "${local.project}-alb"

  load_balancer_type = "application"

  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets

  # For example only
  enable_deletion_protection = false

  # Security Group
  security_group_ingress_rules = {
    all_http = {
      from_port   = local.http_port
      to_port     = local.http_port
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = module.vpc.vpc_cidr_block
    }
  }

  listeners = {
    web_http = {
      port     = local.http_port
      protocol = "HTTP"

      forward = {
        target_group_key = "web-target"
      }
      
      rules = {
        cat = {
          actions = [{
              type = "forward"
              target_group_key = "cat-target"
            }]
            
          conditions = [{
            path_pattern = {
                values = ["/cats/"]
              }
            }]
        }
        
        dog = {
          actions = [{
              type = "forward"
              target_group_key = "dog-target"
            }]
            
          conditions = [{
            path_pattern = {
                values = ["/dogs/"]
              }
            }]
          }
          
        log = {
          actions = [{
              type = "forward"
              target_group_key = "log-target"
            }]
            
          conditions = [{
            path_pattern = {
                values = ["/logs/*"]
              }
            }]
          }
        }
      }
    }

  target_groups = {
    web-target = {
      backend_protocol                  = "HTTP"
      backend_port                      = local.http_port
      target_type                       = "ip"
      deregistration_delay              = 5
      load_balancing_cross_zone_enabled = true

      health_check = {
        enabled             = true
        healthy_threshold   = 5
        interval            = 30
        matcher             = "200"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 2
      }

      create_attachment = false
    }
    
    cat-target = {
      backend_protocol                  = "HTTP"
      backend_port                      = local.http_port
      target_type                       = "ip"
      deregistration_delay              = 5
      load_balancing_cross_zone_enabled = true

      health_check = {
        enabled             = true
        healthy_threshold   = 5
        interval            = 30
        matcher             = "200"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 2
      }

      create_attachment = false
    }
    
    dog-target = {
      backend_protocol                  = "HTTP"
      backend_port                      = local.http_port
      target_type                       = "ip"
      deregistration_delay              = 5
      load_balancing_cross_zone_enabled = true

      health_check = {
        enabled             = true
        healthy_threshold   = 5
        interval            = 30
        matcher             = "200"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 2
      }

      create_attachment = false
    }
    
    log-target = {
      backend_protocol                  = "HTTP"
      backend_port                      = local.nginx_port
      target_type                       = "ip"
      deregistration_delay              = 5
      load_balancing_cross_zone_enabled = true

      health_check = {
        enabled             = true
        healthy_threshold   = 5
        interval            = 30
        matcher             = "200"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 2
      }

      create_attachment = false
    }
  }

  tags = local.tags
}

# # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html#ecs-optimized-ami-linux
# data "aws_ssm_parameter" "ecs_optimized_ami" {
#   name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended"
# }

