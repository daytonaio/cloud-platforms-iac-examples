resource "helm_release" "daytona_workspace" {
  name             = "watkins"
  namespace        = kubernetes_namespace.watkins.metadata[0].name
  repository       = "oci://ghcr.io/daytonaio/charts"
  chart            = "watkins"
  version          = "2.94.0"
  create_namespace = false
  timeout          = 720
  atomic           = true

  values = [<<YAML
image:
  registry: ghcr.io
  repository: daytonaio/workspace-service
namespaceOverride: "watkins"
fullnameOverride: "watkins"
configuration:
  defaultWorkspaceClassName: small
  workspaceRuntimeClassName: kata-clh
  workspaceStorageClass: longhorn
  workspaceNamespace:
    name: watkins-workspaces
    create: true
ingress:
  enabled: true
  hostname: ${data.azurerm_dns_zone.zone.name}
  ingressClassName: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/proxy-buffer-size: 128k
  tls: true
components:
  dashboard:
    workspaceTemplatesIndexUrl: https://raw.githubusercontent.com/daytonaio-templates/index/main/templates.json
  workspaceVolumeInit:
    excludeJetbrainsCodeEditors: false
  sshGateway:
    service:
      port: 30000
      type: LoadBalancer
      annotations:
        external-dns.alpha.kubernetes.io/hostname: "*.ssh.${data.azurerm_dns_zone.zone.name}"
  workspaceProvisioner:
    workspaces:
      runtimeClass: kata-clh
      tolerations: '[{"key": "workernode", "operator": "Equal", "value": "true", "effect": "NoSchedule"}]'
gitProviders:
  github:
    clientId: ${local.github_client_id}
    clientSecret: ${local.github_client_secret}
  postgresql:
    primary:
      persistence:
        storageClass: "default"
postgresql:
  enabled: true
  primary:
    persistence:
      storageClass: "default"
rabbitmq:
  enabled: true
  nameOverride: "watkins-rabbitmq"
  persistence:
    enabled: true
    storageClass: "default"
  auth:
    username: user
    password: pass
    erlangCookie: "secreterlangcookie"
redis:
  enabled: true
  global:
    storageClass: "default"
  nameOverride: "watkins-redis"
  auth:
    enabled: false
  architecture: standalone
YAML
  ]

  depends_on = [helm_release.longhorn]
}
