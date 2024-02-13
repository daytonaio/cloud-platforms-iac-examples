resource "azurerm_dns_zone" "zone" {
  name                = local.dns_zone
  resource_group_name = azurerm_resource_group.rg.name

  tags = merge(
    local.common_tags,
  )
}
