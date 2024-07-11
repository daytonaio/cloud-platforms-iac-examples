resource "helm_release" "daytona_workspace" {
  name       = "watkins"
  namespace  = kubernetes_namespace.watkins.metadata[0].name
  repository = "oci://ghcr.io/daytonaio/charts"
  chart      = "watkins"
  version    = "2.101.2"
  timeout    = 720
  atomic     = true

  values = [<<YAML
image:
  registry: ghcr.io
  repository: daytonaio/workspace-service
namespaceOverride: "watkins"
fullnameOverride: "watkins"
configuration:
  defaultWorkspaceClass:
    cpu: 2
    gpu: ""
    memory: 8
    name: Default
    storage: 50
    usageMultiplier: 1
    runtimeClass: sysbox-runc
    gpuResourceName: nvidia.com/gpu
  workspaceStorageClass: longhorn
  workspaceNamespace:
    name: watkins-workspaces
    create: true
ingress:
  enabled: true
  hostname: ${local.dns_zone}
  ingressClassName: alb
  annotations:
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/load-balancer-name: ${local.cluster_name}
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: 'ip'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    alb.ingress.kubernetes.io/healthcheck-path: "/health"
    cert-manager.io/cluster-issuer: letsencrypt-prod
  tls: true
components:
  dashboard:
    workspaceTemplatesIndexUrl: https://raw.githubusercontent.com/daytonaio-templates/index/main/templates.json
  sshGateway:
    service:
      port: 30000
      type: LoadBalancer
      annotations:
        external-dns.alpha.kubernetes.io/hostname: "*.ssh.${local.dns_zone}"
        service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
  workspaceProvisioner:
    workspaces:
      nodeSelector: '{"daytona.io/node-role" : "workload"}'
      tolerations: '[{"key": "daytona.io/node-role", "operator": "Equal", "value": "workload", "effect": "NoSchedule"}]'
  workspaceVolumeInit:
    storageInit:
      nodeSelector: '{"daytona.io/node-role" : "workload"}'
      tolerations: '[{"key": "daytona.io/node-role", "operator": "Equal", "value": "workload", "effect": "NoSchedule"}]'
    nodeSelector:
      daytona.io/node-role: "workload"
    podTolerations:
      - key: "daytona.io/node-role"
        operator: "Equal"
        value: "workload"
        effect: "NoSchedule"
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

  depends_on = [
    helm_release.longhorn,
    helm_release.aws_load_balancer_controller
  ]

}
