terraform {
  required_version = "~> 1.5"

  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "daytonaio"

    workspaces {
      name = "algebra-app"
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.8"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }

  }
}

## data from tf-1-infra
data "azurerm_subscription" "current" {}

data "azurerm_kubernetes_cluster" "credentials" {
  name                = local.cluster_name
  resource_group_name = data.azurerm_resource_group.rg.name
}

data "azurerm_dns_zone" "zone" {
  name = local.dns_zone
}

data "azurerm_resource_group" "rg" {
  name = local.resource_group_name
}

provider "azurerm" {
  features {}
}

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.credentials.kube_admin_config.0.host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_admin_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_admin_config.0.client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_admin_config.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.credentials.kube_admin_config.0.host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_admin_config.0.client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_admin_config.0.client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_admin_config.0.cluster_ca_certificate)
  }
}

provider "kubectl" {
  host                   = data.azurerm_kubernetes_cluster.credentials.kube_admin_config.0.host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_admin_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_admin_config.0.client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_admin_config.0.cluster_ca_certificate)
  load_config_file       = false
}

locals {
  config = yamldecode(file("${path.module}/../config.yaml"))

  resource_group_name   = local.config.resource_group_name
  location              = local.config.location
  dns_zone              = local.config.dns_zone
  cluster_name          = local.config.cluster_name
  email                 = local.config.email_ca_issuer
  prometheus_monitoring = local.config.prometheus_monitoring

  common_tags = {
    client     = local.config.cluster_name
    managed-by = "terraform"
  }
}
