resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location

  tags = merge(var.tags, {
    environment = var.environment
    managed_by  = "terraform"
  })
}

resource "azurerm_storage_account" "this" {
  name                = var.storage_account_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type

  min_tls_version                  = "TLS1_2"
  allow_nested_items_to_be_public  = false

  tags = merge(var.tags, {
    environment = var.environment
    managed_by  = "terraform"
  })
}

# resource "azurerm_storage_container" "this" {
#   name                  = var.container_name
#   storage_account_id    = azurerm_storage_account.this.id
#   container_access_type = "private"
# }
