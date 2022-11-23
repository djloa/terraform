
variable "ramp-api-app-port" {
  default = "3000"
}

variable "ramp-api-fargate-cpu" {
  description = "Fargate CPU units to use by the container"
}

variable "ramp-api-fargate-memory" {
  description = "Fargate memory to use by the container"
}

variable "ramp-api-app-count" {
  default = 1
}

variable "ramp-api-health-path" {
  default = "/"
}

variable "ramp-api-app-secure-port" {
  default = "3000"
}

variable "ecr_url" {
  description = "ecrl url"
  type = string
}