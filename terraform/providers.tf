terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Remote state — never use local state for shared/team infra.
  # Create this storage account once (see README "Bootstrap" section),
  # then uncomment and fill in the values below OR pass them via
  # `terraform init -backend-config=backend.hcl`.
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstateuniquea4k001"
    container_name       = "tfstate"
    key                  = "infra-automation.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }

  # Auth is done via OIDC federated credentials in GitHub Actions
  # (ARM_CLIENT_ID, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID, ARM_USE_OIDC=true)
  # No client secret is stored anywhere.
}
