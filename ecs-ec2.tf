locals {
  name   = "ex-${basename(path.cwd)}"
  container_name = "ecs-sample"
  container_port = 80
}

module "ecs-ec2" {
  source = "terraform-aws-modules/ecs/aws"

  cluster_name = "${local.project}-sample"
  default_capacity_provider_strategy = {
    ex_1 = {
      weight = 100
    }
  }
    
  autoscaling_capacity_providers = {
    # On-demand instances
    ex_1 = {
      auto_scaling_group_arn         = module.autoscaling["ex_1"].autoscaling_group_arn
      managed_draining               = "ENABLED"
      managed_termination_protection = "ENABLED"

      managed_scaling = {
        maximum_scaling_step_size = 2
        minimum_scaling_step_size = 1
        status                    = "ENABLED"
        target_capacity           = 60
      }
    }
  }
    
    services = {
      sample-service = {
        cpu = 256
        memory = 256
        requires_compatibilities = ["EC2"]
        launch_type  =  "EC2"

        container_definitions = {
          sample-contianers = {
            image = "public.ecr.aws/ecs-sample-image/amazon-ecs-sample:latest"
            portMappings = [
              {
                name          = local.container_name
                containerPort = local.container_port
                hostPort      = local.container_port
                protocol      = "tcp"
              }
            ]
            enable_cloudwatch_logging   = true
          }
        }
        subnet_ids = module.vpc.public_subnets
        security_group_ingress_rules = {
          alb_http = {
            from_port                    = local.container_port
            description                  = "Service port"
            referenced_security_group_id = module.alb.security_group_id
            }
          }
        }
      }
    depends_on = [ module.autoscaling ]
  }
  
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html#ecs-optimized-ami-linux
data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended"
}

module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 9.0"

  for_each = {
    # On-demand instances
    ex_1 = {
      instance_type              = "t3.medium"
      use_mixed_instances_policy = false
      mixed_instances_policy     = null
      user_data                  = <<-EOT
        #!/bin/bash

        cat <<'EOF' >> /etc/ecs/ecs.config
        ECS_CLUSTER="${local.project}-sample"
        ECS_LOGLEVEL=debug
        ECS_ENABLE_TASK_IAM_ROLE=true
        EOF
      EOT
    }
  }

  name = "${local.project}-${each.key}"

  image_id      = jsondecode(data.aws_ssm_parameter.ecs_optimized_ami.value)["image_id"]
  instance_type = each.value.instance_type

  security_groups                 = [module.autoscaling_sg.security_group_id]
  user_data                       = base64encode(each.value.user_data)
  ignore_desired_capacity_changes = true

  create_iam_instance_profile = true
  iam_role_name               = local.name
  iam_role_description        = "ECS role for ${local.project}"
  iam_role_policies = {
    AmazonEC2ContainerServiceforEC2Role = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
    AmazonSSMManagedInstanceCore        = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  vpc_zone_identifier = module.vpc.public_subnets
  health_check_type   = "EC2"
  min_size            = 1
  max_size            = 2
  desired_capacity    = 1

  # https://github.com/hashicorp/terraform-provider-aws/issues/12582
  autoscaling_group_tags = {
    AmazonECSManaged = true
  }

  # Required for  managed_termination_protection = "ENABLED"
  protect_from_scale_in = true
}

module "autoscaling_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = local.name
  description = "Autoscaling group security group"
  vpc_id      = module.vpc.vpc_id

  computed_ingress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.alb.security_group_id
    }
  ]
  number_of_computed_ingress_with_source_security_group_id = 1

  egress_rules = ["all-all"]

  tags = local.tags
}
