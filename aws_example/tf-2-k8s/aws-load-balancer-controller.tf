resource "helm_release" "aws_load_balancer_controller" {
  name            = "aws-load-balancer-controller"
  repository      = "https://aws.github.io/eks-charts"
  chart           = "aws-load-balancer-controller"
  version         = "1.7.0"
  namespace       = kubernetes_namespace.infrastructure.metadata[0].name
  atomic          = false
  cleanup_on_fail = true

  values = [<<YAML
region: ${local.region}
clusterName: ${local.cluster_name}
serviceAccount:
  name: "aws-load-balancer-controller"
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::${data.aws_caller_identity.current.id}:role/${local.cluster_name}-aws-load-balancer-controller"
YAML
  ]

}

data "aws_route53_zone" "zone" {
  name = local.dns_zone
}

resource "aws_acm_certificate" "cert" {
  domain_name               = "*.${local.dns_zone}"
  subject_alternative_names = ["${local.dns_zone}"]
  validation_method         = "DNS"
}

resource "aws_route53_record" "cert_record" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.zone.zone_id
}

resource "aws_acm_certificate_validation" "example" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_record : record.fqdn]
}
