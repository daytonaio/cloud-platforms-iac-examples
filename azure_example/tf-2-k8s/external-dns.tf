resource "azurerm_user_assigned_identity" "aks_external_dns_identity" {
  name                = "aks-external-dns-identity"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_role_assignment" "aks_external_dns_role_assignment_contributor" {
  scope                = data.azurerm_dns_zone.zone.id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_external_dns_identity.principal_id
}

resource "azurerm_federated_identity_credential" "aks_external_dns_credentials" {
  name                = "aks-external-dns-credentials"
  resource_group_name = data.azurerm_resource_group.rg.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = data.azurerm_kubernetes_cluster.credentials.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.aks_external_dns_identity.id
  subject             = "system:serviceaccount:${kubernetes_namespace.infrastructure.metadata[0].name}:external-dns"
}

resource "helm_release" "external_dns" {
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns"
  chart            = "external-dns"
  version          = "1.13.1"
  namespace        = kubernetes_namespace.infrastructure.metadata[0].name
  create_namespace = false
  atomic           = true
  cleanup_on_fail  = true

  values = [<<YAML
txtOwnerId: external-dns-${data.azurerm_kubernetes_cluster.credentials.name}
domainFilters:
  - ${data.azurerm_dns_zone.zone.name}
serviceAccount:
  annotations:
    azure.workload.identity/client-id: ${azurerm_user_assigned_identity.aks_external_dns_identity.client_id}

podLabels:
  azure.workload.identity/use: "true"

provider: azure

secretConfiguration:
  enabled: true
  mountPath: "/etc/kubernetes/"
  data:
    azure.json: |
      {
        "tenantId": "${data.azurerm_subscription.current.tenant_id}",
        "subscriptionId": "${data.azurerm_subscription.current.subscription_id}",
        "resourceGroup": "${data.azurerm_resource_group.rg.name}",
        "useWorkloadIdentityExtension": true
      }
YAML
  ]

  depends_on = [azurerm_federated_identity_credential.aks_external_dns_credentials]
}
