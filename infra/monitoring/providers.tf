terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "awsinfra-tfstate-038462790533"
    key          = "terraform/kube-cluster.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "helm" {
  kubernetes = {
    config_path = var.config_path
  }
}

provider "kubernetes" {
  config_path = var.config_path
}