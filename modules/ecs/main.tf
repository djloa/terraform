data "template_file" "ramp-api-container-definitions" {
  template = file("task-definitions/ramp-api-task-definition.json.tpl")
  vars     = {
    app-name                = "ramp-api"
    app-image               = "${var.ecr_url}/ramp-api"
    app-port                = var.ramp-api-app-port
    log-group-name          = "ramp-api-log-group"
    fargate-cpu             = var.ramp-api-fargate-cpu
    fargate-memory          = var.ramp-api-fargate-memory
    aws-region              = "us-east-1"
    network-mode            = "awsvpc"
    ramp-api-port           = var.ramp-api-app-port
    sender_wallet           = "0xfFc53ba77AA5FD6bA432Ae10f0b50d196fB89559"
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

resource "aws_security_group" "ramp-api-sg" {
  name        = "ramp-api-sg"
  description = "allow inbound access from everywhere only"
  vpc_id      = aws_default_vpc.default_vpc.id
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
    subnets          = ["${aws_default_subnet.default_subnet_a.id}", "${aws_default_subnet.default_subnet_b.id}", "${aws_default_subnet.default_subnet_c.id}"]
    assign_public_ip = true
  }
  lifecycle {
    ignore_changes = [desired_count]
  }  
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

###VPC AND SUBNETS

resource "aws_default_vpc" "default_vpc" {

}

resource "aws_default_subnet" "default_subnet_a" {
    availability_zone = "us-east-1a"
}

resource "aws_default_subnet" "default_subnet_b" {
    availability_zone = "us-east-1a"
}
resource "aws_default_subnet" "default_subnet_c" {
    availability_zone = "us-east-1a"
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