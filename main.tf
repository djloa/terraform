terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
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
