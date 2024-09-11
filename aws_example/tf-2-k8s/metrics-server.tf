resource "helm_release" "metrics-server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server"
  chart      = "metrics-server"
  version    = "3.12.0"
  namespace  = kubernetes_namespace.infrastructure.metadata[0].name
  atomic     = false

}
