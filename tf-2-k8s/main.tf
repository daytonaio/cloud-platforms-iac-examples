terraform {
  required_version = "~> 1.5"

  required_providers {

    google = {
      source  = "hashicorp/google"
      version = "~> 5.7"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.7"
    }
    kubectl = {
      source = "gavinbunney/kubectl"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}

provider "google" {
  project = local.project
  region  = local.region
  #credentials = var.google_credentials
}

provider "google-beta" {
  project = local.project
  region  = local.region
  #credentials = var.google_credentials
}

data "google_client_config" "provider" {}

data "google_container_cluster" "cluster" {
  name     = local.cluster_name
  location = local.region
}

provider "kubernetes" {
  host  = "https://${data.google_container_cluster.cluster.endpoint}"
  token = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.cluster.master_auth[0].cluster_ca_certificate,
  )
}

provider "kubectl" {
  host             = "https://${data.google_container_cluster.cluster.endpoint}"
  token            = data.google_client_config.provider.access_token
  load_config_file = false
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.cluster.master_auth[0].cluster_ca_certificate,
  )
}

provider "helm" {
  kubernetes {
    host  = "https://${data.google_container_cluster.cluster.endpoint}"
    token = data.google_client_config.provider.access_token
    cluster_ca_certificate = base64decode(
      data.google_container_cluster.cluster.master_auth[0].cluster_ca_certificate,
    )
  }
}

locals {
  config = yamldecode(file("${path.module}/../config.yaml"))

  project              = local.config.project
  region               = local.config.region
  zones                = local.config.zones
  cluster_name         = local.config.cluster_name
  dns_zone             = local.config.dns_zone
  email                = local.config.email_ca_issuer
  github_client_id     = local.config.gitProviders.github.clientId
  github_client_secret = local.config.gitProviders.github.clientSecret

}
