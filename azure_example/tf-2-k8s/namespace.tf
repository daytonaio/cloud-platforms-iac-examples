resource "kubernetes_namespace" "infrastructure" {

  metadata {
    name = "infrastructure"
  }
}

resource "kubernetes_namespace" "monitoring" {
  count = local.config.prometheus_monitoring ? 1 : 0
  metadata {
    name = "monitoring"
  }
}

resource "kubernetes_namespace" "longhorn-system" {

  metadata {
    name = "longhorn-system"
  }
}

resource "kubernetes_namespace" "watkins" {

  metadata {
    name = "watkins"
  }
}
