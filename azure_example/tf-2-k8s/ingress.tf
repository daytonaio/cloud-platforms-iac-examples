resource "helm_release" "ingress_nginx" {
  repository       = "https://kubernetes.github.io/ingress-nginx"
  name             = "ingress-nginx"
  namespace        = kubernetes_namespace.infrastructure.metadata[0].name
  chart            = "ingress-nginx"
  version          = "4.9.0"
  create_namespace = false
  wait             = true
  atomic           = true
  cleanup_on_fail  = true

  values = [<<YAML
controller:
  replicaCount: 2
  service:
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /healthz
YAML
  ]
}
