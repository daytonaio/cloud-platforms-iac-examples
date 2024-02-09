resource "aws_eip" "nat" {
  count = length(local.azs)

  domain = "vpc"

  tags = {
    Name = "${local.cluster_name}-${count.index + 1}"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.cluster_name
  cidr = local.vpcCidr

  azs             = local.azs
  private_subnets = local.privateSubnets
  public_subnets  = local.publicSubnets

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true
  reuse_nat_ips          = true
  external_nat_ip_ids    = aws_eip.nat.*.id
  enable_vpn_gateway     = false

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}
