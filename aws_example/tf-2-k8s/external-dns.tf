resource "helm_release" "external_dns" {
  name            = "external-dns"
  repository      = "oci://registry-1.docker.io/bitnamicharts"
  chart           = "external-dns"
  version         = "6.28.5"
  namespace       = kubernetes_namespace.infrastructure.metadata[0].name
  atomic          = false
  cleanup_on_fail = true

  values = [<<YAML
provider: aws
domainFilters:
  - ${local.dns_zone}
serviceAccount:
  create: true
  name: "external-dns"
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::${data.aws_caller_identity.current.id}:role/${local.cluster_name}-external-dns"
YAML
  ]

}
