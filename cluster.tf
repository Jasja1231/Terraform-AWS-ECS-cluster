#=====================================================================
    #Cluster
#=====================================================================

resource "aws_ecs_cluster" "terr_cluster" {
  name = "terr-cluster"
}

#=====================================================================
    #Docker image resource
#=====================================================================

resource "docker_image" "ubuntu" {
  name = "wordpress:latest"
}


#=====================================================================
    #Task definition
    #Revision of an ECS task definition to be used in aws_ecs_service
#=====================================================================
# resource "aws_ecs_task_definition" "terr_task_definition" {
#     #A unique name for your task definition.
#     family = "terr-task-definition"


# }






#=====================================================================
    #Capasity provider 

# For Amazon ECS workloads hosted on Amazon EC2 instances, you must create
#  and maintain a capacity provider that consists of the following components:
# -A name
# -An Auto Scaling group
# -The settings for managed scaling and managed termination protection.(?)
    
#=====================================================================
resource "aws_ecs_cluster_capacity_providers" "terr_esc_capacity_providers" {
  cluster_name = aws_ecs_cluster.terr_cluster.name

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
  name               = "terr-autoscaling-group"

  desired_capacity   = 1
  max_size           = 1
  min_size           = 1

  #(Optional) List of subnet IDs to launch resources in.
  # Subnets automatically determine which avail. zones the group will reside.
  vpc_zone_identifier = [aws_subnet.terr_pub_subnet.id]

  health_check_grace_period = 300
  health_check_type         = "EC2"

  target_group_arns = aws_lb_target_group.terr_target_group.arn

   launch_configuration   = aws_launch_configuration.terr_ecs_launch_config.name
}


#Provides a resource to create a new launch configuration, used for autoscaling groups
resource "aws_launch_configuration" "terr_ecs_launch_config" {
    name = "terr-ecs-launch-config"
    #- (Required) The EC2 image ID to launch.
    image_id             = docker_image.ubuntu.id  # TO DO ,change <----------------------------
    iam_instance_profile = aws_iam_instance_profile.ecs_agent.name
    security_groups      = [aws_security_group.terr_public_sec_group.id]
    user_data            = "#!/bin/bash\necho ECS_CLUSTER=terr-cluster >> /etc/ecs/ecs.config"  #insert terr-cluster as var
    instance_type        = "t2.micro"

    #(Optional) The ID of a ClassicLink-enabled VPC. Only applies to EC2-Classic instances. 
    #vpc_classic_link_id  = 

    key_name = "ec2-demo-key"
}


#=====================================================================
    #Target group  
    #https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group
#=====================================================================
resource "aws_lb_target_group" "terr_target_group" {
  name        = "terr-target-group-instance"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.terr_vpc.id
}

#=====================================================================
    #Create an IAM role for instances to use when they are launched
    # ( but has to be created auto?)   
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
