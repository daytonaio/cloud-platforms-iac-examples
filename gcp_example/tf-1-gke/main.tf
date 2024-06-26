terraform {
  required_version = "~> 1.5"

  required_providers {

    google = {
      source  = "hashicorp/google"
      version = "~> 5.8"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.8"
    }

  }
}

provider "google" {
  project = local.project
  region  = local.region
}

provider "google-beta" {
  project = local.project
  region  = local.region
}

locals {
  config = yamldecode(file("${path.module}/../config.yaml"))

  project              = local.config.project
  region               = local.config.region
  zones                = local.config.zones
  cluster_name         = local.config.cluster_name
  cluster_version      = local.config.cluster_version
  gke_region_subnet    = local.config.gke_network.region_subnet
  gke_service_subnet   = local.config.gke_network.service_subnet
  gke_pod_subnet       = local.config.gke_network.pod_subnet
  control_plane_subnet = local.config.gke_network.control_plane_subnet
  dns_zone             = local.config.dns_zone
  authorized_networks  = local.config.authorized_networks

  gpu = {
    enabled   = local.config.gpu.enabled
    node_type = local.config.gpu.node_type
    type      = local.config.gpu.type
    count     = local.config.gpu.count
    zones     = local.config.gpu.zones
  }
}
