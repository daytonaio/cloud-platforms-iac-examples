resource "helm_release" "daytona_workspace" {
  name             = "watkins"
  namespace        = "watkins"
  repository       = "oci://ghcr.io/daytonaio/charts"
  chart            = "watkins"
  version          = "2.73.0"
  create_namespace = true
  timeout          = 720
  atomic           = true

  values = [<<YAML
image:
  registry: ghcr.io
  repository: daytonaio/workspace-service
namespaceOverride: "watkins"
fullnameOverride: "watkins"
configuration:
  defaultWorkspaceClassName: sysbox
  workspaceNamespace:
    name: watkins-workspaces
    create: true
ingress:
  enabled: true
  ingressClassName: "nginx"
  hostname: ${local.dns_zone}
  annotations:
     nginx.ingress.kubernetes.io/proxy-buffer-size: 128k
     cert-manager.io/cluster-issuer: letsencrypt-prod
  tls: true
components:
  workspaceVolumeInit:
    pullImages:
      storageClassName: "longhorn"
  workspaceSshGateway:
    service:
      port: 30000
      type: LoadBalancer
      annotations:
        external-dns.alpha.kubernetes.io/hostname: "*.ssh.${local.dns_zone}"
gitProviders:
  github:
    clientId: ${local.github_client_id}
    clientSecret: ${local.github_client_secret}
keycloak:
  postgresql:
    primary:
      persistence:
        storageClass: "standard-rwo"
postgresql:
  enabled: true
  primary:
    persistence:
      storageClass: "standard-rwo"
rabbitmq:
  enabled: true
  nameOverride: "watkins-rabbitmq"
  persistence:
    enabled: true
    storageClass: "standard-rwo"
  auth:
    username: user
    password: pass
    erlangCookie: "secreterlangcookie"
redis:
  enabled: true
  global:
    storageClass: "standard-rwo"
  nameOverride: "watkins-redis"
  auth:
    enabled: false
  architecture: standalone
YAML
  ]

  depends_on = [helm_release.longhorn]

}
