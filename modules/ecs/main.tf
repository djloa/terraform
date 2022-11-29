data "template_file" "ramp-api-container-definitions" {
  template = file("task-definitions/ramp-api-task-definition.json.tpl")
  vars     = {
    app-name                = "ramp-api"
    app-image               = "${var.ecr_url}:latest"
    app-port                = var.ramp-api-app-port
    log-group-name          = "ramp-api-log-group"
    fargate-cpu             = var.ramp-api-fargate-cpu
    fargate-memory          = var.ramp-api-fargate-memory
    aws-region              = "us-east-1"
    network-mode            = "awsvpc"
    ramp-api-port           = var.ramp-api-app-port
    sender_wallet           = "0xF7508d044d21169927dE87aa358E79b9E17561c9"
    sender_private_key_sec  = aws_ssm_parameter.private-key-sec.arn
  }
}

resource "aws_ecs_task_definition" "ramp-api-task-definition" {
  family             = "ramp-api-ecs-task"
  execution_role_arn = aws_iam_role.ramp-api-ecs-task-execution-role.arn
  task_role_arn      = aws_iam_role.ramp-api-ecs-task-execution-role.arn
  network_mode       = "awsvpc"
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
      aws_security_group.ramp_api_task.id
    ]
    subnets          = aws_subnet.private.*.id
    assign_public_ip = true
  }
    load_balancer {
    target_group_arn = aws_lb_target_group.ramp_api.id
    container_name   = "ramp-api"
    container_port   = 3000
  }
    depends_on = [aws_lb_listener.ramp_api]

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

resource "aws_iam_policy" "ramp-ssm-policy" {
  name        = "ramp-secret-read"
  description = "Access to secret manager HERE RC secret"
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ssm:DescribeParameters",
                "ssm:GetParameterHistory",
                "ssm:GetParametersByPath",
                "ssm:GetParameters",
                "ssm:GetParameter",
                "ssm:DeleteParameters"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
              "kms:Decrypt"
            ],
            "Resource": "*"
         }
    ]
}
EOF
}
resource "aws_iam_policy" "ramp-ecs-task-execution-policy" {
  name   = "ramp-ecs-task-execution-policy"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "cloudwatch:GetMetricStatistics",
                "cloudwatch:ListMetrics",
                "cloudwatch:PutMetricData",
                "s3:Get*",
                "s3:List*",
                "s3:PutObject",
                "sqs:List*",
                "sqs:Get*",
                "sqs:DeleteMessage*",
                "sqs:ReceiveMessage",
                "sqs:SendMessage"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}


resource "aws_iam_role_policy_attachment" "ramp-ecs-task-role-ssm" {
  role       = aws_iam_role.ramp-api-ecs-task-execution-role.name
  policy_arn = aws_iam_policy.ramp-ssm-policy.arn
}

resource "aws_iam_role_policy_attachment" "ramp-ecs-task-role-execution" {
  role       = aws_iam_role.ramp-api-ecs-task-execution-role.name
  policy_arn = aws_iam_policy.ramp-ecs-task-execution-policy.arn
}

###   VPC AND SUBNETS

resource "aws_vpc" "default" {
 cidr_block = "10.32.0.0/16"
 
 tags = {
   Name = "Project VPC"
 }
}

resource "aws_subnet" "public" {
  count                   = 2
  cidr_block              = cidrsubnet(aws_vpc.default.cidr_block, 8, 2 + count.index)
  availability_zone       = data.aws_availability_zones.available_zones.names[count.index]
  vpc_id                  = aws_vpc.default.id
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private" {
  count             = 2
  cidr_block        = cidrsubnet(aws_vpc.default.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available_zones.names[count.index]
  vpc_id            = aws_vpc.default.id
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.default.id
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.default.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gateway.id
}

resource "aws_eip" "gateway" {
  count      = 2
  vpc        = true
  depends_on = [aws_internet_gateway.gateway]
}

resource "aws_nat_gateway" "gateway" {
  count         = 2
  subnet_id     = element(aws_subnet.public.*.id, count.index)
  allocation_id = element(aws_eip.gateway.*.id, count.index)
}

resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.default.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.gateway.*.id, count.index)
  }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, count.index)
}

resource "aws_security_group" "lb" {
  name        = "ramp_api-alb-security-group"
  vpc_id      = aws_vpc.default.id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


###   SECURITY GROUP

resource "aws_security_group" "ramp_api_task" {
  name        = "allows only traffic in the 3000 port"
  vpc_id      = aws_vpc.default.id

  ingress {
    protocol        = "tcp"
    from_port       = 3000
    to_port         = 3000
    security_groups = [aws_security_group.lb.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "default" {
  name            = "ramp-api-lb"
  subnets         = aws_subnet.public.*.id
  security_groups = [aws_security_group.lb.id]
}

resource "aws_lb_target_group" "ramp_api" {
  name        = "ramp-api-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.default.id
  target_type = "ip"
}

resource "aws_lb_listener" "ramp_api" {
  load_balancer_arn = aws_lb.default.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.ramp_api.id
    type             = "forward"
  }
}

#SSM
resource "aws_ssm_parameter" "private-key-sec" {
  name        = "private-key-sec"
  description = "Sender Wallet Private Key"
  type        = "String"
  value       = "UPDATE_ME_IN_PARAMETER_STORE"
  overwrite   = true
  lifecycle {
    ignore_changes = [
      value
    ]
  }
}



# Set up CloudWatch group and log stream and retain logs for 30 days
resource "aws_cloudwatch_log_group" "rc-log-group" {
  name              = "ramp-api-log-group"
  retention_in_days = 30
}

