terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.15.1"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

module "ecr" {
  source = "./modules/ecr"
  ecr_name = local.env["ecr_name"]
}

module "ecs" {
  source = "./modules/ecs"
  ramp-api-fargate-memory = 512
  ramp-api-fargate-cpu = 256
  ecr_url = module.ecr.ecr_url

}
