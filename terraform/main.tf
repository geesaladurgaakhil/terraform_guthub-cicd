locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Mandatory tags are merged with any extra tags the caller provides, so
  # required keys can never be overridden away to nothing.
  common_tags = merge(var.tags, {
    ManagedBy = "Terraform"
  })
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.common_tags
}

# ---------------------------------------------------------------------------
# STORAGE ACCOUNT — secure-by-default configuration
# ---------------------------------------------------------------------------
resource "random_string" "sa_suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "azurerm_storage_account" "main" {
  name                = "st${replace(var.project_name, "-", "")}${var.environment}${random_string.sa_suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  account_tier             = "Standard"
  account_replication_type = "GRS"

  # --- Security guardrails ---
  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  allow_nested_items_to_be_public   = false # no anonymous/public blob access
  public_network_access_enabled     = true  # set false + private endpoint for prod-hardened setups
  shared_access_key_enabled         = false
  infrastructure_encryption_enabled = true

  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  network_rules {
    default_action = "Deny"
    ip_rules       = [var.allowed_ssh_source_cidr != "" ? split("/", var.allowed_ssh_source_cidr)[0] : "0.0.0.0"]
    bypass         = ["AzureServices"]
  }

  tags = local.common_tags
}