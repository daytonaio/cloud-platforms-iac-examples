resource "google_dns_managed_zone" "zone" {
  name        = replace(local.dns_zone, ".", "-")
  dns_name    = local.dns_zone
  description = "Test zone for GKE daytona workspaces"
}
