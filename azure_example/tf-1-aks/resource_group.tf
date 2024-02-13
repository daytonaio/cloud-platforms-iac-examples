resource "azurerm_resource_group" "rg" {
  name     = local.resource_group_name
  location = local.location

  tags = merge(
    local.common_tags,
  )

}
