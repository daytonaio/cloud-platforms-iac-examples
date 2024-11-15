resource "helm_release" "daytona_workspace" {
  name             = "watkins"
  namespace        = kubernetes_namespace.watkins.metadata[0].name
  repository       = "oci://ghcr.io/daytonaio/charts"
  chart            = "watkins"
  version          = "2.114.1"
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
  defaultWorkspaceClass:
    cpu: 2
    gpu: ""
    memory: 8
    name: Default
    storage: 50
    usageMultiplier: 1
    runtimeClass: kata-clh
    gpuResourceName: nvidia.com/gpu
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
      ## The capacityReserve feature deploys a low-priority pod that reserves resources on the cluster.
      ## This pod can be quickly evicted when actual workloads need to be scheduled, ensuring that there's
      ## always capacity available for sudden spikes in demand. It helps maintain a buffer of resources,
      ## improving responsiveness and reducing potential scheduling delays. It also prepulls the workspace image.
      capacityReserve:
        enabled: true
        priorityValue: -10
        tolerations:
          - effect: NoSchedule
            operator: Exists
        affinity:
          nodeAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              nodeSelectorTerms:
                - matchExpressions:
                    - key: daytona.io/node-role
                      operator: In
                      values:
                        - workload
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
