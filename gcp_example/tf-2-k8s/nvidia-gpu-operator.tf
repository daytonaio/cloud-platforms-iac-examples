resource "kubectl_manifest" "gpu_resource_quota" {
  count     = local.gpu.enabled ? 1 : 0
  yaml_body = <<YAML
apiVersion: v1
kind: ResourceQuota
metadata:
  name: gpu-operator-quota
  namespace: ${kubernetes_namespace.gpu-operator[0].metadata[0].name}
spec:
  hard:
    pods: 100
  scopeSelector:
    matchExpressions:
    - operator: In
      scopeName: PriorityClass
      values:
        - system-node-critical
        - system-cluster-critical
YAML

}

resource "helm_release" "gpu_operator" {
  count                      = local.gpu.enabled ? 1 : 0
  name                       = "gpu-operator"
  repository                 = "https://helm.ngc.nvidia.com/nvidia"
  chart                      = "gpu-operator"
  version                    = "v24.3.0"
  create_namespace           = false
  namespace                  = kubernetes_namespace.gpu-operator[0].metadata[0].name
  timeout                    = 300
  atomic                     = true
  wait                       = true
  disable_openapi_validation = true

  values = [<<YAML
operator:
  defaultRuntime: containerd
  upgradeCRD: true
toolkit:
  env:
  - name: CONTAINERD_RUNTIME_CLASS
    value: nvidia
  - name: CONTAINERD_SET_AS_DEFAULT
    value: "false"
YAML
  ]
}
