output "daytona_access_instructions" {
  value = <<EOT
** Please be patient while the Daytona is being deployed, DNS records propagate and ingress is ready **

1. Daytona can be accessed through the following DNS name:

   https://${local.dns_zone}

2. To access the Administration Console use the following:

   URL:       https://admin.${local.dns_zone}
   Username:  admin
   Password:  $(kubectl get secret --namespace ${kubernetes_namespace.watkins.metadata[0].name} ${helm_release.daytona_workspace.name} -o jsonpath={.data.admin-password} | base64 --decode; echo)

3. To access Keycloak admin portal use the following:

   URL:       https://id.${local.dns_zone}
   Username:  admin
   Password:  $(kubectl get secret --namespace ${kubernetes_namespace.watkins.metadata[0].name} ${helm_release.daytona_workspace.name}-watkins-keycloak -o jsonpath={.data.admin-password} | base64 --decode; echo)
EOT
}
