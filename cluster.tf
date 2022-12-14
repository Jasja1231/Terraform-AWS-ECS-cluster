#=====================================================================
#Cluster
#=====================================================================

resource "aws_ecs_cluster" "terr_cluster" {
  name = "terr-cluster"
}

#=====================================================================
#Docker image resource
#=====================================================================

resource "docker_image" "wordpress_image" {
  name = "wordpress:latest"
}


#======================================================================
#Service aws_ecs_service
#======================================================================
resource "aws_ecs_service" "terr_sevice" {
  name                = "terr-service"
  cluster             = aws_ecs_cluster.terr_cluster.id
  task_definition     = aws_ecs_task_definition.terr_task_definition.arn
  desired_count       = 1
  scheduling_strategy = "REPLICA"

  load_balancer {
    target_group_arn = aws_lb_target_group.terr_target_group.arn
    container_name   = "terr-apache-wp-container"
    container_port   = 80
  }
  deployment_controller {
    type = "ECS"
  }

  #To prevent a race condition during service deletion, make sure to set 
  #depends_on to the related aws_iam_role_policy; otherwise, the policy 
  #may be destroyed too soon and the ECS service will then get stuck in 
  #the DRAINING state
  # depends_on = [ aws_iam_role_policy ..]
}

# resource "aws_ecs_service" "my_service" {
#   name            = "my_service"
#   cluster         = "${aws_ecs_cluster.my_cluster.id}"
#   task_definition = "${aws_ecs_task_definition.my_tf.arn}"
#   desired_count   = 1
#   iam_role        = "${aws_iam_role.ecs-service-role.id}"
# }




#=====================================================================
#Task definition
#Revision of an ECS task definition to be used in aws_ecs_service
#=====================================================================
resource "aws_ecs_task_definition" "terr_task_definition" {
  #A unique name for your task definition.
  family       = "terr-task-definition"
  network_mode = "bridge"
  container_definitions = jsonencode([
    {
      name      = "terr-apache-wp-container"
      image     = docker_image.wordpress_image.name
      cpu       = 0 #/ 1
      memory    = 512
      essential = true
      portMappings = [
        {
          name          = "terr-wp-apahce-container-80-tcp"
          containerPort = 80,
          hostPort      = 80,
          protocol      = "tcp"
        },
        {
          name          = "terr-wp-apahce-container-443-tcp"
          containerPort = 443,
          hostPort      = 443,
          protocol      = "tcp"
        },
      ]
    }
  ])
  #ARN of the task execution role that the Amazon ECS container agent and the Docker daemon can assume.
  #execution_role_arn = aws_iam_role.ecs_agent.arn
  # or task_role_arn

  #Set of launch types required by the task. The valid values are EC2 and FARGATE.
  requires_compatibilities = ["EC2"]
  

  # volume {
  #   name      = "service-storage"
  #   host_path = "/ecs/service-storage"
  # }

}






#=====================================================================
#Capasity provider 

# For Amazon ECS workloads hosted on Amazon EC2 instances, you must create
#  and maintain a capacity provider that consists of the following components:
# -A name
# -An Auto Scaling group
# -The settings for managed scaling and managed termination protection.(?)

# ECS capacity providers are used to manage the infrastructure the tasks in your clusters use.
# Each cluster can have one or more capacity providers and an optional default capacity provider strategy. 
# The capacity provider strategy determines how the tasks are spread across the cluster's capacity providers.
# When you run a standalone task or create a service, you may either use the cluster's default capacity 
#provider strategy or specify a capacity provider strategy that overrides the cluster's default strategy.
#=====================================================================
resource "aws_ecs_cluster_capacity_providers" "terr_esc_capacity_providers" {
  cluster_name = aws_ecs_cluster.terr_cluster.name #cluster name 

  capacity_providers = [aws_ecs_capacity_provider.terr_esc_capacity_provider.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.terr_esc_capacity_provider.name
  }
}

resource "aws_ecs_capacity_provider" "terr_esc_capacity_provider" {
  name = "terr-capacity-provider"
  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.terr_autoscaling_group.arn
  }
}


#=====================================================================
#Autoscaling group + launch configuration
#=====================================================================

resource "aws_autoscaling_group" "terr_autoscaling_group" {
  name = "terr-autoscaling-group"

  desired_capacity = 1
  max_size         = 1
  min_size         = 1

  #(Optional) List of subnet IDs to launch resources in.
  # Subnets automatically determine which avail. zones the group will reside.
  vpc_zone_identifier = [aws_subnet.terr_pub_subnet.id, aws_subnet.terr_pub_subnet_1b.id]

  #min sec to keep new instance before terminate
  health_check_grace_period = 300
  health_check_type         = "EC2"

  target_group_arns    = [aws_lb_target_group.terr_target_group.arn, aws_lb_target_group.terr_target_group_ssh.arn]
  launch_configuration = aws_launch_configuration.terr_ecs_launch_config.name

  depends_on = [
    aws_launch_configuration.terr_ecs_launch_config
  ]

  # tag {
  #         key                 = "AmazonECSManaged" 
  #         propagate_at_launch = true  
  #       }
    
}


#Provides a resource to create a new launch configuration
#used for autoscaling groups
resource "aws_launch_configuration" "terr_ecs_launch_config" {
  name = "terr-ecs-launch-config"
  #- (Required) The EC2 image ID to launch.
  image_id             = "ami-0fab44817c875e415" # TO DO ,change(?) <----------------------------
  iam_instance_profile = aws_iam_instance_profile.ecs_agent.name
  security_groups      = [aws_security_group.terr_public_sec_group.id]
  user_data            = "#!/bin/bash\necho ECS_CLUSTER=terr-cluster >> /etc/ecs/ecs.config" #insert terr-cluster as var   ---> https://docs.aws.amazon.com/AmazonECS/latest/developerguide/bootstrap_container_instance.html
  instance_type        = "t2.micro"
  ebs_optimized        = "false"
  key_name             = "ec2-demo-key"

  #(Optional) The ID of a ClassicLink-enabled VPC. Only applies to EC2-Classic instances. 
  #vpc_classic_link_id  = 

  #------------------------------> 
  # DEVICE STORADGE 
  #The root_block_device is the EBS volume provided by the AMI that will contain 
  #the operating system. If you don't configure it, AWS will use the default values from the AMI.

  #ebs_block_device supports the following:
  #device_name - (Required) The name of the device to mount.
  # ebs_block_device {
  #   device_name = "/dev/xvda"
  # }

  # root_block_device {
  #   device_name = "/dev/xvda"
  #   volume_type = "EBS"
  #   delete_on_termination = "true"
  #   volume_size = "30"
  #   encrypted = false
  # }
  # ebs_optimized = false
  # --------------------------------<
}


#=====================================================================
#Target group  | Load balancer | Listener(http 80)
#https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group
#=====================================================================
resource "aws_lb_target_group" "terr_target_group" {
  name        = "terr-target-group-instance"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.terr_vpc.id
}

resource "aws_lb_target_group" "terr_target_group_ssh" {
  name        = "terr-target-group-instance-ssh"
  port        = 22
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = aws_vpc.terr_vpc.id
}


resource "aws_lb" "terr_load_balancer" {
  name               = "terr-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.terr_public_sec_group.id]
  subnets            = [aws_subnet.terr_pub_subnet.id, aws_subnet.terr_pub_subnet_1b.id]

  enable_deletion_protection = false
  ip_address_type            = "ipv4"

}

resource "aws_lb_listener" "terr_80_listener" {
  load_balancer_arn = aws_lb.terr_load_balancer.arn
  port              = "80"
  protocol          = "HTTP"
  # ssl_policy        = "ELBSecurityPolicy-2016-08"
  #certificate_arn   = "arn:aws:iam::187416307283:server-certificate/test_cert_rab3wuqwgja25ct3n4jdj2tzu4"

  default_action {
    #(Required) Type of routing action. Valid values are forward,
    #redirect, fixed-response, authenticate-cognito and authenticate-oidc.
    type             = "forward"
    target_group_arn = aws_lb_target_group.terr_target_group.arn
  }
}


#=====================================================================
#Create an IAM role for instances to use when they are launched
# ( but has to be created auto?)   

#Before adding ECS instances to a cluster - create ecs-optimized instances
#with an IAM role that has the AmazonEC2ContainerServiceforEC2Role 
#policy attached
#=====================================================================
data "aws_iam_policy_document" "ecs_agent" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_agent" {
  name               = "terr-ecs-agent"
  assume_role_policy = data.aws_iam_policy_document.ecs_agent.json
}


resource "aws_iam_role_policy_attachment" "ecs_agent" {
  role       = aws_iam_role.ecs_agent.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_agent" {
  name = "terr-ecs-agent"
  role = aws_iam_role.ecs_agent.name
}
