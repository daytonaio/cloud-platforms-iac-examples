output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = local.cluster_name
}

output "daytona_url" {
  description = "Daytona dashboard URL"
  value       = "https://${local.dns_zone}"
}

output "keycloak_url" {
  description = "Keycloak URL"
  value       = "https://id.${local.dns_zone}"
}

data "kubernetes_secret" "keycloak_admin" {
  metadata {
    name      = "watkins-watkins-keycloak"
    namespace = kubernetes_namespace.watkins.metadata[0].name
  }

  depends_on = [helm_release.daytona_workspace]
}

output "keycloak_admin_password" {
  description = "Keycloak user/password"
  value       = "admin / ${nonsensitive(data.kubernetes_secret.keycloak_admin.data["admin-password"])}"
}
