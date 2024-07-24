resource "aws_route53_zone" "zone" {
  name = local.dns_zone
}
