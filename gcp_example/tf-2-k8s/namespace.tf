resource "kubernetes_namespace" "infrastructure" {

  metadata {
    name = "infrastructure"
  }
}

resource "kubernetes_namespace" "monitoring" {

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

resource "kubernetes_namespace" "gpu-operator" {
  count = local.gpu.enabled ? 1 : 0

  metadata {
    name = "gpu-operator"
  }
}
