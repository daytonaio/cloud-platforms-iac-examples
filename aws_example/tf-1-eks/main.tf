terraform {

  required_version = "~> 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }

    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.2"
    }

    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }

    local = {
      source  = "hashicorp/local"
      version = "2.4"
    }
  }

}

provider "aws" {
  region = local.region

  default_tags {
    tags = local.common_tags
  }
}

data "aws_caller_identity" "current" {}

locals {
  common_tags = {
    Environment = "daytona"
    Managed-by  = "terraform"
    Team        = "daytona"
  }

  config = yamldecode(file("${path.module}/../config.yaml"))

  region   = local.config.region
  dns_zone = local.config.dns_zone


  vpcCidr        = local.config.vpc.cidr
  azs            = [for az in local.config.vpc.azs : az.id]
  privateSubnets = [for az in local.config.vpc.azs : az.subnets.private]
  publicSubnets  = [for az in local.config.vpc.azs : az.subnets.public]

  authorized_networks = [for key, value in local.config.authorized_networks : value]
  cluster_name        = local.config.cluster_name
  cluster_version     = local.config.cluster_version

}
