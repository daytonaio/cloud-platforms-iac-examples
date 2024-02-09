resource "helm_release" "kube_prometheus_stack" {
  count            = local.config.prometheus_monitoring ? 1 : 0
  name             = "prometheus-community"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "55.5.0"
  create_namespace = true
  namespace        = "monitoring"
  timeout          = 300
  atomic           = true
  wait             = true

  values = [<<YAML
nameOverride: "kube-prom"
fullnameOverride: "kube-prom"
coreDns:
  enabled: false
kubeDns:
  enabled: true
YAML
  ]
}

resource "kubectl_manifest" "longhorn_metrics" {
  count     = local.config.prometheus_monitoring ? 1 : 0
  yaml_body = <<YAML
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: longhorn-prometheus-servicemonitor
  namespace: longhorn-system
  labels:
    name: longhorn-prometheus-servicemonitor
spec:
  selector:
    matchLabels:
      app: longhorn-manager
  namespaceSelector:
    matchNames:
    - longhorn-system
  endpoints:
  - port: manager
YAML

  depends_on = [
    helm_release.kube_prometheus_stack,
  ]

}
