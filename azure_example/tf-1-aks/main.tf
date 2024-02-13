terraform {
  required_version = "~> 1.5"

  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "daytonaio"

    workspaces {
      name = "algebra-infra"
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.8"
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.15.0"
    }

    azapi = {
      source  = "Azure/azapi"
      version = "1.11.0"
    }

    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "4.0.5"
    }
  }
}

provider "azuread" {
}

provider "azurerm" {
  features {}
}

locals {
  config = yamldecode(file("${path.module}/../config.yaml"))

  resource_group_name         = local.config.resource_group_name
  location                    = local.config.location
  dns_zone                    = local.config.dns_zone
  zones                       = local.config.zones
  cluster_name                = local.config.cluster_name
  azure_network_region_subnet = local.config.azure_network.region_subnet
  authorized_networks         = local.config.authorized_networks

  common_tags = {
    client     = local.config.cluster_name
    managed-by = "terraform"
  }
}
