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
