# daemonset that runs on workload node pool in order to allow
resource "kubectl_manifest" "runtime_checker" {
  for_each  = toset(split("---\n", file("runtime-checker/runtime-checker.yaml")))
  yaml_body = each.value
}

resource "kubectl_manifest" "longhorn_priority_class" {
  yaml_body = <<YAML
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: custom-node-critical
value: 1000000000
globalDefault: false
description: "Custom PriorityClass for longhorn pods"
YAML
}

resource "helm_release" "longhorn" {
  name       = "longhorn"
  repository = "https://charts.longhorn.io"
  chart      = "longhorn"
  version    = "1.5.3"
  namespace  = kubernetes_namespace.longhorn-system.metadata[0].name
  timeout    = 300
  atomic     = false
  wait       = true

  values = [
    <<EOF
persistence:
  defaultClass: false
  defaultClassReplicaCount: 3
csi:
  kubeletRootDir: /var/lib/kubelet
defaultSettings:
  deletingConfirmationFlag: true
  createDefaultDiskLabeledNodes: true
  defaultDataPath: /data
  kubernetesClusterAutoscalerEnabled: true
  replicaAutoBalance: best-effort
  replica-replenishment-wait-interval: 0
  storageOverProvisioningPercentage: 500
  storageMinimalAvailablePercentage: 10
  storageReservedPercentageForDefaultDisk: 15
  systemManagedComponentsNodeSelector: "daytona.io/runtime-ready:true"
  taintToleration: "daytona.io/node-role=storage:NoSchedule;daytona.io/node-role=workload:NoSchedule"
  priorityClass: custom-node-critical
  guaranteedInstanceManagerCPU: 20
longhornManager:
  priorityClass: custom-node-critical
  nodeSelector:
    daytona.io/runtime-ready: "true"
  tolerations:
    - key: "daytona.io/node-role"
      operator: "Equal"
      value: "storage"
      effect: "NoSchedule"
    - key: "daytona.io/node-role"
      operator: "Equal"
      value: "workload"
      effect: "NoSchedule"
longhornDriver:
  priorityClass: custom-node-critical
  nodeSelector:
    daytona.io/runtime-ready: "true"
  tolerations:
    - key: "daytona.io/node-role"
      operator: "Equal"
      value: "storage"
      effect: "NoSchedule"
    - key: "daytona.io/node-role"
      operator: "Equal"
      value: "workload"
      effect: "NoSchedule"
  EOF
  ]

  depends_on = [
    kubectl_manifest.longhorn_priority_class,
    kubectl_manifest.sysbox,
    helm_release.aws_load_balancer_controller
  ]
}
