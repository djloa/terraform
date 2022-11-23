[
  {
    "name": "${app-name}",
    "image": "${app-image}",
    "cpu": ${fargate-cpu},
    "memory": ${fargate-memory},
    "networkMode": "${network-mode}",
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${log-group-name}",
        "awslogs-region": "${aws-region}",
        "awslogs-stream-prefix": "${app-name}"
      }
    },
    "portMappings": [
      {
        "containerPort": ${app-port},
        "hostPort": ${app-port}
      }
    ],
    "environment": [
        {
        "name": "SENDER_WALLET",
        "valueFrom": "${sender_wallet}"
      }
    ],
    "secrets": [
      {
        "name": "SENDER_PRIVATE_KEY",
        "valueFrom": "${sender_private_key_sec}"
      }
    ]
  }
]
