
variable "namespace_names" {
  type    = list(string)
  default = ["infrastructure", "longhorn-system"]
}

resource "kubernetes_namespace" "namespace" {
  for_each = { for idx, name in var.namespace_names : idx => name }

  metadata {
    name = each.value
  }
}
