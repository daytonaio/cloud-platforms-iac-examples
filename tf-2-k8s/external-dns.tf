resource "helm_release" "external_dns" {
  name             = "external-dns"
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "external-dns"
  version          = "6.28.5"
  namespace        = "infrastructure"
  create_namespace = true
  atomic           = false
  cleanup_on_fail  = true

  values = [<<YAML
provider: google
google:
  project: ${local.project}
domainFilters:
  - ${local.dns_zone}
serviceAccount:
  create: false
  name: "external-dns"
  annotations: {}
YAML
  ]

  depends_on = [kubernetes_namespace.namespace, module.external_dns_service_account]
}

module "external_dns_service_account" {
  source                          = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  name                            = "external-dns"
  namespace                       = "infrastructure"
  use_existing_k8s_sa             = false
  annotate_k8s_sa                 = true
  cluster_name                    = local.cluster_name
  project_id                      = local.project
  location                        = local.region
  roles                           = ["roles/dns.admin"]
  automount_service_account_token = true
}
