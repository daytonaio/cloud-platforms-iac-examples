resource "kubectl_manifest" "daytona_backend_config" {
  yaml_body = <<YAML
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: daytona
  namespace: ${kubernetes_namespace.watkins.metadata[0].name}
spec:
  timeoutSec: 86400
YAML

}

resource "helm_release" "daytona_workspace" {
  name       = "watkins"
  namespace  = kubernetes_namespace.watkins.metadata[0].name
  repository = "oci://ghcr.io/daytonaio/charts"
  chart      = "watkins"
  version    = "2.91.2"
  timeout    = 720
  atomic     = true

  values = [<<YAML
image:
  registry: ghcr.io
  repository: daytonaio/workspace-service
namespaceOverride: "watkins"
fullnameOverride: "watkins"
configuration:
  defaultWorkspaceClassName: small
  workspaceRuntimeClassName: sysbox-runc
  workspaceStorageClass: longhorn
  workspaceNamespace:
    name: watkins-workspaces
    create: true
ingress:
  enabled: true
  hostname: ${local.dns_zone}
  annotations:
    kubernetes.io/ingress.class: "gce"
    cert-manager.io/cluster-issuer: letsencrypt-prod
  tls: true
components:
  dashboard:
    workspaceTemplatesIndexUrl: https://raw.githubusercontent.com/daytonaio/samples-index/main/index.json
  sshGateway:
    service:
      port: 30000
      type: LoadBalancer
      annotations:
        external-dns.alpha.kubernetes.io/hostname: "*.ssh.${local.dns_zone}"
  workspaceProvisioner:
    workspaces:
      tolerations: '[{"key": "daytona.io/node-role", "operator": "Equal", "value": "workload", "effect": "NoSchedule"}]'
  workspaceProxy:
    service:
      annotations:
        cloud.google.com/backend-config: '{"ports": {"80":"daytona"}}'
  dashboard:
    service:
      annotations:
        cloud.google.com/backend-config: '{"ports": {"3000":"daytona"}}'
  realtimeServer:
    service:
      annotations:
        cloud.google.com/backend-config: '{"ports": {"3000":"daytona"}}'
gitProviders:
  github:
    clientId: ${local.github_client_id}
    clientSecret: ${local.github_client_secret}
postgresql:
  enabled: true
rabbitmq:
  enabled: true
  nameOverride: "watkins-rabbitmq"
  persistence:
    enabled: true
  auth:
    username: user
    password: pass
    erlangCookie: "secreterlangcookie"
redis:
  enabled: true
  nameOverride: "watkins-redis"
  auth:
    enabled: false
  architecture: standalone
YAML
  ]

  depends_on = [helm_release.longhorn]

}
