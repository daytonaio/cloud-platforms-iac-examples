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
  name          = "watkins"
  namespace     = kubernetes_namespace.watkins.metadata[0].name
  repository    = "oci://ghcr.io/daytonaio/charts"
  chart         = "watkins"
  version       = "2.117.0"
  timeout       = 1800
  atomic        = false
  wait_for_jobs = true

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
  annotations:
    kubernetes.io/ingress.class: "gce"
    cert-manager.io/cluster-issuer: letsencrypt-prod
  tls: true
components:
  sshGateway:
    service:
      port: 30000
      type: LoadBalancer
      annotations:
        external-dns.alpha.kubernetes.io/hostname: "*.ssh.${local.dns_zone}"
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
  workspaceProvisioner:
    workspaces:
      nodeSelector: '{"daytona.io/node-role" : "workload"}'
      tolerations: '[{"key": "daytona.io/node-role", "operator": "Equal", "value": "workload", "effect": "NoSchedule"}]'
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
    kubectl_manifest.daytona_backend_config
  ]

}
