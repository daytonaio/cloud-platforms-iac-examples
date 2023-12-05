resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "1.13.2"
  namespace        = "infrastructure"
  create_namespace = true
  atomic           = true

  values = [<<YAML
installCRDs: true
resources: {}
  # requests:
  #   cpu: 10m
  #   memory: 32Mi
webhook:
  resources: {}
    # requests:
    #   cpu: 10m
    #   memory: 32Mi
YAML
  ]

  depends_on = [kubernetes_namespace.namespace]
}

module "cert_manager_service_account" {
  source              = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  name                = "cert-manager"
  namespace           = "infrastructure"
  use_existing_k8s_sa = true
  annotate_k8s_sa     = true
  cluster_name        = local.cluster_name
  project_id          = local.project
  location            = local.region
  roles               = ["roles/dns.admin"]
  module_depends_on   = [helm_release.cert_manager]
}


resource "kubectl_manifest" "cluster_issuer_prod" {
  yaml_body     = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${local.email}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - dns01:
          cloudDNS:
            project: ${local.project}
YAML
  ignore_fields = ["metadata.annotations"]
  depends_on    = [helm_release.cert_manager]
}

resource "kubectl_manifest" "cluster_issuer_staging" {
  yaml_body     = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: ${local.email}
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
      - dns01:
          cnameStrategy: Follow
          cloudDNS:
            project: ${local.project}
YAML
  ignore_fields = ["metadata.annotations"]
  depends_on    = [helm_release.cert_manager]
}
