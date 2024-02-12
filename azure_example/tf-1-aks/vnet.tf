module "vnet" {
  source              = "Azure/vnet/azurerm"
  version             = "4.1.0"
  resource_group_name = azurerm_resource_group.rg.name
  use_for_each        = true
  vnet_name           = local.cluster_name
  vnet_location       = azurerm_resource_group.rg.location
  address_space       = [local.azure_network_region_subnet]

  subnet_names    = [for k, v in local.config.azure_network : k if k != "region_subnet"]
  subnet_prefixes = [for k, v in local.config.azure_network : v if k != "region_subnet"]

  tags = merge(
    local.common_tags,
  )
}
