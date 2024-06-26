resource "helm_release" "external_dns" {
  name            = "external-dns"
  repository      = "oci://registry-1.docker.io/bitnamicharts"
  chart           = "external-dns"
  version         = "6.28.5"
  namespace       = kubernetes_namespace.infrastructure.metadata[0].name
  atomic          = false
  cleanup_on_fail = true

  values = [<<YAML
provider: google
google:
  project: ${local.project}
domainFilters:
  - ${local.dns_zone}
serviceAccount:
  create: true
  name: "external-dns"
  annotations:
    iam.gke.io/gcp-service-account: ${module.external_dns_service_account.gcp_service_account_email}
YAML
  ]

}

module "external_dns_service_account" {
  source                          = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  name                            = "external-dns-${local.cluster_name}"
  k8s_sa_name                     = "external-dns"
  namespace                       = kubernetes_namespace.infrastructure.metadata[0].name
  use_existing_k8s_sa             = true
  annotate_k8s_sa                 = false
  cluster_name                    = local.cluster_name
  project_id                      = local.project
  location                        = local.region
  roles                           = ["roles/dns.admin"]
  automount_service_account_token = true
}
