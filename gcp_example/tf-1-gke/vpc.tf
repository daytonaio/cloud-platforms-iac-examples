resource "google_compute_network" "daytona-vpc" {
  project                 = local.project
  name                    = "daytona-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "gke-subnet-1" {
  name                     = "gke-subnet-1"
  ip_cidr_range            = local.gke_region_subnet
  region                   = local.region
  network                  = google_compute_network.daytona-vpc.id
  private_ip_google_access = true
  secondary_ip_range = [
    {
      range_name    = "gke-service-subnet"
      ip_cidr_range = local.gke_service_subnet
    },
    {
      range_name    = "gke-pod-subnet"
      ip_cidr_range = local.gke_pod_subnet
    }
  ]

}

resource "google_compute_router" "router1" {
  name    = "daytona-vpc-router"
  region  = local.region
  network = google_compute_network.daytona-vpc.name
}

resource "google_compute_router_nat" "nat1" {
  name                               = "daytona-vpc-nat"
  router                             = google_compute_router.router1.name
  region                             = google_compute_router.router1.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = false
    filter = "ERRORS_ONLY"
  }
}
