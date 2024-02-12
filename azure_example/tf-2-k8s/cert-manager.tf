resource "azurerm_user_assigned_identity" "aks_cert_manager_identity" {
  name                = "aks-cert-manager-identity"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_role_assignment" "aks_cert_manager_role_assignment" {
  scope                = data.azurerm_dns_zone.zone.id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_cert_manager_identity.principal_id
}

resource "azurerm_federated_identity_credential" "aks_cert_manager_credentials" {
  name                = "aks-cert-manager-credentials"
  resource_group_name = data.azurerm_resource_group.rg.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = data.azurerm_kubernetes_cluster.credentials.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.aks_cert_manager_identity.id
  subject             = "system:serviceaccount:${kubernetes_namespace.infrastructure.metadata[0].name}:cert-manager"
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "1.13.2"
  namespace        = kubernetes_namespace.infrastructure.metadata[0].name
  create_namespace = false
  atomic           = true

  values = [<<YAML
installCRDs: true
resources: {}
  # requests:
  #   cpu: 10m
  #   memory: 32Mi
webhook:
  resources: {}
    # requests:
    #   cpu: 10m
    #   memory: 32Mi
podLabels:
  azure.workload.identity/use: "true"
serviceAccount:
  create: true
  name: "cert-manager"
  labels:
    azure.workload.identity/use: "true"
YAML
  ]
  depends_on = [azurerm_federated_identity_credential.aks_cert_manager_credentials]
}

resource "kubectl_manifest" "cluster_issuer_prod" {
  yaml_body = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${local.email}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - dns01:
        azureDNS:
          hostedZoneName: ${data.azurerm_dns_zone.zone.name}
          resourceGroupName: ${data.azurerm_resource_group.rg.name}
          subscriptionID: ${data.azurerm_subscription.current.subscription_id}
          environment: AzurePublicCloud
          managedIdentity:
            clientID: ${azurerm_user_assigned_identity.aks_cert_manager_identity.client_id}
YAML
  #ignore_fields = ["metadata.annotations"]
  depends_on = [helm_release.cert_manager]
}

resource "kubectl_manifest" "cluster_issuer_staging" {
  yaml_body = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: ${local.email}
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - dns01:
        azureDNS:
          hostedZoneName: ${data.azurerm_dns_zone.zone.name}
          resourceGroupName: ${data.azurerm_resource_group.rg.name}
          subscriptionID: ${data.azurerm_subscription.current.subscription_id}
          environment: AzurePublicCloud
          managedIdentity:
            clientID: ${azurerm_user_assigned_identity.aks_cert_manager_identity.client_id}
YAML

  #ignore_fields = ["metadata.annotations"]
  depends_on = [helm_release.cert_manager]
}
