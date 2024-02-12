resource "kubectl_manifest" "kata_rbac" {
  for_each  = toset(split("---\n", file("kata-files/kata-rbac.yaml")))
  yaml_body = each.value
}

resource "kubectl_manifest" "kata_deploy" {
  for_each  = toset(split("---\n", file("kata-files/kata-deploy.yaml")))
  yaml_body = each.value
}

resource "kubectl_manifest" "kata_runtime_classes" {
  for_each  = toset(split("---\n", file("kata-files/kata-runtime.yaml")))
  yaml_body = each.value
}
