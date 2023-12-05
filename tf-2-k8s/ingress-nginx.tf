resource "helm_release" "nginx-ingress" {
  repository      = "https://kubernetes.github.io/ingress-nginx"
  name            = "ingress-nginx"
  chart           = "ingress-nginx"
  version         = "4.8.3"
  namespace       = "infrastructure"
  timeout         = 180
  wait            = true
  atomic          = true
  cleanup_on_fail = true

  depends_on = [kubernetes_namespace.namespace]
}
