resource "google_dns_managed_zone" "zone" {
  name        = replace(local.dns_zone, ".", "-")
  dns_name    = "${local.dns_zone}."
  description = "DNS zone for GKE daytona workspaces"
}
