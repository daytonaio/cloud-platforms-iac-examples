data "google_project" "project" {
}

data "google_container_engine_versions" "get_gke_version" {
  provider       = google-beta
  location       = local.zones[0]
  version_prefix = "1.27."
}

resource "google_service_account" "gke-default" {
  account_id   = "gke-default"
  display_name = "GKE Service Account"
}

resource "google_project_iam_member" "gke-default" {
  for_each = toset([
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/compute.securityAdmin"
  ])
  role    = each.key
  member  = "serviceAccount:${google_service_account.gke-default.email}"
  project = data.google_project.project.id
}

resource "google_container_cluster" "cluster-1" {
  name                     = local.cluster_name
  location                 = local.region
  initial_node_count       = 1
  remove_default_node_pool = true
  min_master_version       = data.google_container_engine_versions.get_gke_version.release_channel_latest_version["REGULAR"]
  network                  = google_compute_network.daytona-vpc.name
  subnetwork               = google_compute_subnetwork.gke-subnet-1.name
  enable_shielded_nodes    = false
  deletion_protection      = false

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = local.control_plane_subnet
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pod-subnet"
    services_secondary_range_name = "gke-service-subnet"
  }

  # sysbox doens't work with calico at the moment
  # https://github.com/nestybox/sysbox/issues/680
  addons_config {
    network_policy_config {
      disabled = true
    }
  }

  network_policy {
    enabled  = false
    provider = "PROVIDER_UNSPECIFIED"
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]

    managed_prometheus {
      enabled = false
    }
  }

  master_authorized_networks_config {

    dynamic "cidr_blocks" {
      for_each = local.authorized_networks

      content {
        cidr_block   = cidr_blocks.value
        display_name = cidr_blocks.key
      }
    }
  }

  release_channel {
    channel = "UNSPECIFIED"
  }

  maintenance_policy {

    recurring_window {
      start_time = "2022-08-12T23:00:00Z"
      end_time   = "2022-08-13T15:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=MO,TU,WE"
    }
  }

  workload_identity_config {
    workload_pool = "${data.google_project.project.project_id}.svc.id.goog"
  }

}

resource "google_container_node_pool" "app-pool-1" {
  name               = "app-pool-1"
  cluster            = google_container_cluster.cluster-1.id
  node_locations     = local.zones
  initial_node_count = 1

  node_config {
    spot = false

    image_type   = "UBUNTU_CONTAINERD" # requirement for sysbox
    machine_type = "c3d-standard-8"
    disk_size_gb = 100
    disk_type    = "pd-ssd"

    service_account = google_service_account.gke-default.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    shielded_instance_config {
      enable_secure_boot = false # requirement for sysbox
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      "sysbox-install"           = "no" # requirement for sysbox
      "daytona.io/node-role"     = "app"
      "daytona.io/runtime-ready" = "true"
    }
  }

  autoscaling {
    total_min_node_count = 1
    total_max_node_count = 3
    location_policy      = "BALANCED"
  }

  upgrade_settings {
    max_unavailable = 1
    max_surge       = 1
  }

}

resource "google_container_node_pool" "workload-pool-1" {
  name           = "workload-pool-1"
  cluster        = google_container_cluster.cluster-1.id
  node_locations = local.zones

  node_config {
    spot = false

    image_type   = "UBUNTU_CONTAINERD" # requirement for sysbox
    machine_type = "c3d-standard-16"
    disk_size_gb = 100
    disk_type    = "pd-ssd"

    service_account = google_service_account.gke-default.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    shielded_instance_config {
      enable_secure_boot = false # requirement for sysbox
    }

    linux_node_config {
      sysctls = {
        "net.ipv6.conf.all.disable_ipv6"     = "1"
        "net.ipv6.conf.default.disable_ipv6" = "1"
      }
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    taint {
      effect = "NO_SCHEDULE"
      key    = "daytona.io/node-role"
      value  = "workload"
    }

    labels = {
      "sysbox-install"       = "yes" # requirement for sysbox
      "daytona.io/node-role" = "workload"
    }
  }

  autoscaling {
    total_min_node_count = 1
    total_max_node_count = 30
    location_policy      = "ANY"
  }

  upgrade_settings {
    max_unavailable = 1
    max_surge       = 1
  }

}

## Node pool that will hold all the longhorn volumes used by daytona workspaces
## It is setup via local-ssd on GKE nodes - https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/local-ssd-raw
resource "google_container_node_pool" "longhorn-pool-1" {
  name           = "longhorn-pool-1"
  cluster        = google_container_cluster.cluster-1.id
  node_locations = local.zones
  node_count     = 1

  node_config {
    image_type   = "UBUNTU_CONTAINERD" # requirement for iscsi
    machine_type = "c2-standard-8"
    disk_size_gb = 100
    disk_type    = "pd-ssd"

    service_account = google_service_account.gke-default.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    shielded_instance_config {
      enable_secure_boot = false
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    taint {
      effect = "NO_SCHEDULE"
      key    = "daytona.io/node-role"
      value  = "storage"
    }

    labels = {
      "sysbox-install"                       = "no" # no need for sysbox on longhorn volume nodes
      "node.longhorn.io/create-default-disk" = true
      "daytona.io/node-role"                 = "storage"
      "daytona.io/runtime-ready"             = "true"
    }

    # every SSD has 375GB. It will be setup in Raid 0. So total disk space for workspace volumes per node
    # will be `local_ssd_count x 375GB`
    local_nvme_ssd_block_config {
      local_ssd_count = 8
    }

  }

  management {
    auto_repair  = false
    auto_upgrade = false
  }

}

resource "google_compute_firewall" "master_to_nodes" {
  name      = "gke-custom-master-to-nodes"
  network   = google_compute_network.daytona-vpc.name
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["443", "8080", "8443", "9090", "9443", "9502", "9503"]
  }

  source_ranges           = [local.control_plane_subnet]
  target_service_accounts = [google_service_account.gke-default.email]
}

# this is to allow ssh into daytona workspaces
resource "google_compute_firewall" "ssh_gateway" {
  name      = "gke-custom-all-to-nodes-ssh"
  network   = google_compute_network.daytona-vpc.name
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["30000"]
  }

  source_ranges           = ["0.0.0.0/0"]
  target_service_accounts = [google_service_account.gke-default.email]
}
