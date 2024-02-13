data "azuread_client_config" "current" {}

resource "azuread_group" "aks_cluster_admins" {
  display_name     = "${local.cluster_name}-aks-admin"
  owners           = [data.azuread_client_config.current.object_id]
  security_enabled = true
}

resource "azurerm_role_assignment" "aks_cluster_admin" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = azuread_group.aks_cluster_admins.object_id
}

resource "azurerm_user_assigned_identity" "aks_identity" {
  location            = azurerm_resource_group.rg.location
  name                = "${local.cluster_name}-aks"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
}

module "aks" {
  source                    = "Azure/aks/azurerm"
  version                   = "7.5.0"
  resource_group_name       = azurerm_resource_group.rg.name
  kubernetes_version        = "1.27"
  automatic_channel_upgrade = "patch"
  prefix                    = local.cluster_name
  cluster_name              = local.cluster_name

  identity_ids  = [azurerm_user_assigned_identity.aks_identity.id]
  identity_type = "UserAssigned"

  vnet_subnet_id = lookup(module.vnet.vnet_subnets_name_id, "aks_subnet")

  role_based_access_control_enabled = true
  rbac_aad_admin_group_object_ids   = [azuread_group.aks_cluster_admins.id]
  rbac_aad_managed                  = true
  workload_identity_enabled         = true
  oidc_issuer_enabled               = true

  log_analytics_workspace_enabled = false
  private_cluster_enabled         = false

  api_server_authorized_ip_ranges = values(local.authorized_networks)

  agents_pool_name          = "system"
  agents_count              = 1
  agents_availability_zones = local.zones
  agents_size               = "Standard_D8ads_v5"
  agents_max_pods           = "60"
  agents_labels = {
    "app-node" = "yes"
  }
  os_disk_type        = "Ephemeral"
  os_disk_size_gb     = "100"
  enable_auto_scaling = true
  agents_max_count    = "6"
  agents_min_count    = "3"
  network_policy      = "azure"
  network_plugin      = "azure"

  net_profile_dns_service_ip  = "192.168.0.10"
  net_profile_service_cidr    = "192.168.0.0/16"
  temporary_name_for_rotation = "systemtemp"

  maintenance_window = {
    allowed = [
      {
        day   = "Saturday"
        hours = [21, 22, 23, 0]
      },
      {
        day   = "Sunday"
        hours = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23]
      }
    ]
    not_allowed = []
  }

  node_pools = {
    "storage" = {
      node_labels = {
        "node.longhorn.io/create-default-disk" = true
        "aks-local-ssd"                        = "true"
        "longhorn-components"                  = "yes"
        "longhorn-volumes"                     = "yes"
      }
      node_taints = ["longhorn-node=true:NoSchedule"]

      name            = "storage"
      node_count      = 3
      zones           = ["1", "2", "3"]
      os_type         = "Linux"
      os_sku          = "Ubuntu"
      os_disk_size_gb = "50"
      os_disk_type    = "Ephemeral"
      vm_size         = "standard_l8s_v3"
      vnet_subnet_id  = lookup(module.vnet.vnet_subnets_name_id, "aks_subnet")
    }

    "workload" = {
      node_labels = {
        "longhorn-components" = "yes"
        "workload-node"       = "yes"
      }
      node_taints = ["workernode=true:NoSchedule"]

      name                = "workload"
      min_count           = 1
      max_count           = 30
      enable_auto_scaling = true
      os_type             = "Linux"
      os_sku              = "Ubuntu"
      os_disk_size_gb     = "100"
      os_disk_type        = "Ephemeral"
      vm_size             = "Standard_D16ads_v5"
      vnet_subnet_id      = lookup(module.vnet.vnet_subnets_name_id, "aks_subnet")
    }
  }

  tags = merge(
    local.common_tags,
  )

  depends_on = [azurerm_resource_group.rg]
}
