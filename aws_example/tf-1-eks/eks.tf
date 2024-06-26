data "aws_ami" "sysbox_compatible" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["ubuntu-eks/k8s_${local.cluster_version}*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name              = local.cluster_name
  cluster_version           = local.cluster_version
  cluster_enabled_log_types = []
  vpc_id                    = module.vpc.vpc_id

  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = local.authorized_networks
  cluster_endpoint_private_access      = true

  enable_cluster_creator_admin_permissions = true

  cluster_addons = {

    aws-ebs-csi-driver = {
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
      most_recent              = true
      configuration_values = jsonencode(
        { "controller" : {
          "tolerations" : [{
            "key" : "capacity",
            "operator" : "Equal",
            "value" : "on-demand",
            "effect" : "NoSchedule"
          }]
      } })
    }

    coredns = {
      most_recent = true
      configuration_values = jsonencode(
        { "tolerations" : [{
          "key" : "capacity",
          "operator" : "Equal",
          "value" : "on-demand",
          "effect" : "NoSchedule"
          }]
      })
    }

    vpc-cni = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
  }

  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }

    ingress_control_plane_prometheus = {
      description                   = "Control node to node prometheus port"
      protocol                      = "tcp"
      from_port                     = 9090
      to_port                       = 9090
      type                          = "ingress"
      source_cluster_security_group = true
    }

    ingress_control_plane_longhorn_webhook = {
      description                   = "Control node to longhorn webhook"
      protocol                      = "tcp"
      from_port                     = 9502
      to_port                       = 9502
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  eks_managed_node_group_defaults = {
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
  }

  eks_managed_node_groups = {
    app = {
      create_launch_template = true
      launch_template_name   = "${local.cluster_name}-app"
      launch_template_tags = merge(
        local.common_tags,
        {
          Name = "${local.cluster_name}-app"
        }
      )
      capacity_type           = "ON_DEMAND"
      desired_size            = 1
      min_size                = 1
      max_size                = 3
      instance_types          = ["m6a.4xlarge"]
      enable_monitoring       = true
      subnet_ids              = module.vpc.private_subnets
      pre_bootstrap_user_data = <<EOF
          #!/bin/bash
          yum install amazon-ssm-agent -y
          systemctl enable amazon-ssm-agent
          systemctl start amazon-ssm-agent
          EOF
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 100
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }
      labels = {
        "daytona.io/node-role" = "app"
      }
    },

    storage = {
      create_launch_template = true
      launch_template_name   = "${local.cluster_name}-storage"
      launch_template_tags = merge(
        local.common_tags,
        {
          Name = "${local.cluster_name}-storage"
        }
      )
      capacity_type           = "ON_DEMAND"
      desired_size            = 3
      min_size                = 3
      max_size                = 3
      instance_types          = ["i3.8xlarge"]
      enable_monitoring       = true
      subnet_ids              = module.vpc.private_subnets
      pre_bootstrap_user_data = <<EOF
          #!/bin/bash
          yum install amazon-ssm-agent -y
          systemctl enable amazon-ssm-agent
          systemctl start amazon-ssm-agent

          yum --setopt=tsflags=noscripts install iscsi-initiator-utils -y
          echo "InitiatorName=$(/sbin/iscsi-iname)" > /etc/iscsi/initiatorname.iscsi
          systemctl enable iscsid
          systemctl start iscsid
          modprobe iscsi_tcp

          yum install nvme-cli -y

          # Get list of NVMe Drives
          nvme_drives=$(nvme list | grep "Amazon EC2 NVMe Instance Storage" | cut -d " " -f 1 || true)
          readarray -t nvme_drives <<< "$nvme_drives"
          num_drives=$${#nvme_drives[@]}

          # Install software RAID utility
          yum install mdadm -y

          # Create RAID-0 array across the instance store NVMe SSDs
          mdadm --create /dev/md0 --level=0 --name=md0 --raid-devices=$num_drives "$${nvme_drives[@]}"

          # Format drive with Ext4
          mkfs.ext4 /dev/md0

          # Get RAID array's UUID
          uuid=$(blkid -o value -s UUID /dev/md0)

          #Create a filesystem path to mount the disk
          mount_location="/data"
          mkdir -p $mount_location

          # Mount RAID device
          mount /dev/md0 $mount_location

          # Have disk be mounted on reboot
          mdadm --detail --scan >> /etc/mdadm.conf
          echo /dev/md0 $mount_location ext4 defaults,noatime 0 2 >> /etc/fstab
          EOF

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 100
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }
      taints = {
        capacity = {
          key    = "daytona.io/node-role"
          value  = "storage"
          effect = "NO_SCHEDULE"
        }
      }
      labels = {
        "node.longhorn.io/create-default-disk" = true
        "aws.amazon.com/eks-local-ssd"         = "true"
        "daytona.io/node-role"                 = "storage"
        "daytona.io/runtime-ready"             = "true"
      }
    }

    workload = {
      create_launch_template = true
      ami_id                 = data.aws_ami.sysbox_compatible.id
      launch_template_name   = "${local.cluster_name}-workload"
      launch_template_tags = merge(
        local.common_tags,
        {
          Name = "${local.cluster_name}-workload"
        }
      )
      capacity_type              = "ON_DEMAND"
      desired_size               = 0
      min_size                   = 0
      max_size                   = 20
      instance_types             = ["c6a.4xlarge"]
      enable_monitoring          = true
      subnet_ids                 = module.vpc.private_subnets
      enable_bootstrap_user_data = true
      pre_bootstrap_user_data    = <<EOF
          #!/bin/bash
          snap install amazon-ssm-agent --classic
          snap start amazon-ssm-agent

          apt-get install open-iscsi -y
          systemctl -q enable iscsid
          systemctl start iscsid
          modprobe iscsi_tcp
          EOF
      block_device_mappings = {
        xvda = {
          device_name = "/dev/sda1"
          ebs = {
            volume_size           = 100
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }
      taints = {
        capacity = {
          key    = "daytona.io/node-role"
          value  = "workload"
          effect = "NO_SCHEDULE"
        }
      }
      labels = {
        "daytona.io/node-role" = "workload"
        "sysbox-install"       = "yes"
      }
    }
  }

  tags = local.common_tags
}

module "ebs_csi_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name             = "${module.eks.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    one = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

module "load_balancer_controller_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                              = "${module.eks.cluster_name}-aws-load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    one = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["infrastructure:aws-load-balancer-controller"]
    }
  }
}

module "cluster_autoscaler_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                        = "${module.eks.cluster_name}-cluster-autoscaler"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_ids   = [module.eks.cluster_name]

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["infrastructure:cluster-autoscaler"]
    }
  }
}

module "external_dns_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                  = "${module.eks.cluster_name}-external-dns"
  attach_external_dns_policy = true

  external_dns_hosted_zone_arns = [
    aws_route53_zone.zone.arn
  ]

  oidc_providers = {
    one = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["infrastructure:external-dns"]
    }
  }
}

# module "cert_manager_irsa_role" {
#   source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

#   role_name                  = "${module.eks.cluster_name}-cert-manager"
#   attach_cert_manager_policy = true

#   cert_manager_hosted_zone_arns = [
#     aws_route53_zone.zone.arn
#   ]

#   oidc_providers = {
#     one = {
#       provider_arn               = module.eks.oidc_provider_arn
#       namespace_service_accounts = ["infrastructure:cert-manager"]
#     }
#   }
# }
