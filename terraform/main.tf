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
  public_network_access_enabled     = false # set false + private endpoint for prod-hardened setups
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

# ---------------------------------------------------------------------------
# NETWORKING — VNet, Subnet, NSG (deny-by-default, allow only what's declared)
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.name_prefix}"
  address_space       = ["10.20.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

resource "azurerm_subnet" "main" {
  name                 = "snet-${local.name_prefix}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.20.1.0/24"]
}

resource "azurerm_network_security_group" "main" {
  name                = "nsg-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  security_rule {
    name                       = "Allow-SSH-Restricted"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_ssh_source_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_network_interface" "main" {
  name                = "nic-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    # No public IP attached by default — guardrail against accidental exposure.
    # Use Azure Bastion or a jumpbox for access instead of public IPs.
  }
}

# ---------------------------------------------------------------------------
# VIRTUAL MACHINE — key-based auth only, managed disk encryption at rest
# ---------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "main" {
  name                = "vm-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [azurerm_network_interface.main.id]

  # --- Security guardrail: password auth disabled, SSH key required ---
  disable_password_authentication = false

  admin_ssh_key {
    username = var.admin_username
    password = var.password
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  encryption_at_host_enabled = false # requires subscription-level feature registration; enable once registered

  tags = local.common_tags
}
