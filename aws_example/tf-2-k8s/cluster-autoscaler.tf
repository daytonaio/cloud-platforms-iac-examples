resource "helm_release" "cluster-autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.37.0"
  namespace  = kubernetes_namespace.infrastructure.metadata[0].name
  atomic     = true

  values = [<<YAML
autoDiscovery:
  clusterName: ${local.cluster_name}
image:
  repository: registry.k8s.io/autoscaling/cluster-autoscaler
  tag: v1.29.3
rbac:
  serviceAccount:
    name: "cluster-autoscaler"
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::${data.aws_caller_identity.current.id}:role/${local.cluster_name}-cluster-autoscaler"
YAML
  ]

}
