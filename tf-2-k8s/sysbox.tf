data "http" "sysbox_url" {
  url = "https://raw.githubusercontent.com/nestybox/sysbox/master/sysbox-k8s-manifests/sysbox-install.yaml"
}

data "kubectl_file_documents" "sysbox_doc" {
  content = data.http.sysbox_url.response_body
}

resource "kubectl_manifest" "sysbox" {
  for_each  = data.kubectl_file_documents.sysbox_doc.manifests
  yaml_body = each.value
}
