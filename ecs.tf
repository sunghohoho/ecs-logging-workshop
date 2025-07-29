locals {
  name   = "ex-${basename(path.cwd)}"

  container_name = "ecs-ns"
  container_port = 80
  
  # svc-name = ["web","cat","dog"]
}

module "ecs" {
  source = "terraform-aws-modules/ecs/aws"

  cluster_name = "ecs-sample-cluster"

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
      
      # Container definition(s)
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

        web-containers = {
          cpu       = 512
          memory    = 1024
          essential = true
          image     = "public.ecr.aws/d4j3m3g7/gguduck/registry:websv0.2"
          portMappings = [
            {
              name          = "web-container-port"
              containerPort = 80
              protocol      = "tcp"
            }
          ]

          # Example image used requires access to write to root filesystem
          readonlyRootFilesystem = false

          dependsOn = [{
            containerName = "fluent-bit"
            condition     = "START"
          }]

          enable_cloudwatch_logging = false
          logConfiguration = {
            logDriver = "awsfirelens"
            options = {
              Name                    = "firehose"
              region                  = "${data.aws_region.current.region}"
              delivery_stream         = "${local.project}"
              log-driver-buffer-limit = "2097152"
            }
          }
          memoryReservation = 100
        }
      }

      # service_connect_configuration = {
      #   namespace = aws_service_discovery_http_namespace.this.arn
      #   service = [
      #     {
      #       client_alias = {
      #         port     = local.container_port
      #         dns_name = "${local.container_name}"
      #       }
      #       port_name      = "web-container-port"
      #       discovery_name = aws_service_discovery_http_namespace.this.name
      #     }
      #   ]
      # }

      load_balancer = {
        service = {
          target_group_arn = module.alb.target_groups["web-target"].arn
          container_name   = "web-containers"
          container_port   = local.container_port
        }
  }

      subnet_ids = module.vpc.private_subnets
      security_group_ingress_rules = {
        alb_80 = {
          description                  = "Service port"
          from_port                    = local.container_port
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
      
      # Container definition(s)
      container_definitions = {
        cat-containers = {
          cpu       = 512
          memory    = 1024
          essential = true
          image     = "public.ecr.aws/d4j3m3g7/gguduck/registry:catsv0.1"
          portMappings = [
            {
              name          = "cat-container-port"
              containerPort = 80
              protocol      = "tcp"
            }
          ]

          # Example image used requires access to write to root filesystem
          readonlyRootFilesystem = false

          enable_cloudwatch_logging = true
          memoryReservation = 100
        }
      }

      # service_connect_configuration = {
      #   namespace = aws_service_discovery_http_namespace.this.arn
      #   service = [
      #     {
      #       client_alias = {
      #         port     = local.container_port
      #         dns_name = "${local.container_name}"
      #       }
      #       port_name      = "cat-container-port"
      #       discovery_name = aws_service_discovery_http_namespace.this.name
      #     }
      #   ]
      # }

      load_balancer = {
        service = {
          target_group_arn = module.alb.target_groups["cat-target"].arn
          container_name   = "cat-containers"
          container_port   = local.container_port
        }
  }

      subnet_ids = module.vpc.private_subnets
      security_group_ingress_rules = {
        alb_80 = {
          description                  = "Service port"
          from_port                    = local.container_port
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
      
      # Container definition(s)
      container_definitions = {
        dog-containers = {
          cpu       = 512
          memory    = 1024
          essential = true
          image     = "public.ecr.aws/d4j3m3g7/gguduck/registry:dogsv0.1"
          portMappings = [
            {
              name          = "dog-container-port"
              containerPort = 80
              protocol      = "tcp"
            }
          ]

          # Example image used requires access to write to root filesystem
          readonlyRootFilesystem = false

          enable_cloudwatch_logging = true
          memoryReservation = 100
        }
      }

      # service_connect_configuration = {
      #   namespace = aws_service_discovery_http_namespace.this.arn
      #   service = [
      #     {
      #       client_alias = {
      #         port     = local.container_port
      #         dns_name = "${local.container_name}"
      #       }
      #       port_name      = "dog-container-port"
      #       discovery_name = aws_service_discovery_http_namespace.this.name
      #     }
      #   ]
      # }

      load_balancer = {
        service = {
          target_group_arn = module.alb.target_groups["dog-target"].arn
          container_name   = "dog-containers"
          container_port   = local.container_port
        }
  }

      subnet_ids = module.vpc.private_subnets
      security_group_ingress_rules = {
        alb_80 = {
          description                  = "Service port"
          from_port                    = local.container_port
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
  
  depends_on = [ module.alb, aws_service_discovery_http_namespace.this ]
}

resource "aws_service_discovery_http_namespace" "this" {
  name        = "${local.name}-service-discovery-ns"
  description = "CloudMap namespace for ${local.project}"
  tags        = local.tags
}

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
      from_port   = 80
      to_port     = 80
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
      port     = 80
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
        }
      }
    }

  target_groups = {
    web-target = {
      backend_protocol                  = "HTTP"
      backend_port                      = local.container_port
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
      backend_port                      = local.container_port
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
      backend_port                      = local.container_port
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