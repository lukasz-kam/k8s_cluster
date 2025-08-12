terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "awsinfra-tfstate-038462790533"
    key          = "terraform/test-kube-infra.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
    profile      = "terraform-user"

    assume_role = {
      role_arn     = "arn:aws:iam::038462790533:role/TerraformRole"
      session_name = "terraform-backend-kube-session"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "terraform-user"

  assume_role {
    role_arn     = "arn:aws:iam::038462790533:role/TerraformRole"
    session_name = "terraform-kube-infra-session"
  }
}