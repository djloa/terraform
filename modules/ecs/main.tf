data "template_file" "ramp-api-container-definitions" {
  template = file("${path.module}/../task-definitions/ramp-api-container-definitions.json.tpl")
  vars     = {
    app-name                = "ramp-api"
    app-image               = "${var.ecr_url}/ramp-api"
    app-port                = var.ramp-api-app-port
    log-group-name          = "ramp-api-log-group"
    fargate-cpu             = var.ramp-api-fargate-cpu
    fargate-memory          = var.ramp-api-fargate-memory
    aws-region              = "eu-west-1"
    network-mode            = var.network-mode
    ramp-api-port           = var.ramp-api-app-port
  }
}

resource "aws_ecs_task_definition" "ramp-api-task-definition" {
  family             = "ramp-api-ecs-task"
  execution_role_arn = aws_iam_role.ramp-api-ecs-task-execution-role.arn
  task_role_arn      = aws_iam_role.ramp-api-ecs-task-execution-role.arn
  network_mode       = var.network-mode
  volume {
    name = "service-storage"
  }
  requires_compatibilities = [
    "FARGATE"
  ]
  cpu                   = var.ramp-api-fargate-cpu
  memory                = var.ramp-api-fargate-memory
  container_definitions = data.template_file.ramp-api-container-definitions.rendered
}

resource "aws_security_group" "ramp-api-sg" {
  name        = "ramp-api-sg"
  description = "allow inbound access from everywhere only"
  vpc_id      = data.aws_vpc.public-vpc.id
  ingress {
    protocol    = "tcp"
    from_port   = var.ramp-api-app-secure-port
    to_port     = var.ramp-api-app-secure-port
    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }
}

resource "aws_ecs_cluster" "fargate_cluster" {
  name = "ramp-api-cluster"
}

resource "aws_ecs_service" "ramp-api-service" {
  name            = "ramp-api"
  cluster         = aws_ecs_cluster.fargate_cluster.id
  task_definition = aws_ecs_task_definition.ramp-api-task-definition.arn
  desired_count   = var.ramp-api-app-count
  launch_type     = "FARGATE"
  network_configuration {
    security_groups  = [
      aws_security_group.ramp-api-sg.id
    ]
    //subnets          = data.aws_subnet_ids.public-vpc-private-subnet-all.ids
    assign_public_ip = true
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.ramp-api.id
    container_name   = "ramp-api"
    container_port   = var.ramp-api-app-port
  }
  lifecycle {
    ignore_changes = [desired_count]
  }  
  depends_on = [
    aws_lb-internal-lb,
    aws_lb_target_group.ramp-api
  ]
}

resource "aws_iam_role" "ramp-api-ecs-task-execution-role" {
  name                 = "ramp-api-ecs-task-execution-role"
  assume_role_policy   = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}