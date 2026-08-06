terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }

  # --- Remote state backend (recommended once you move past local practice) ---
  # Leave this block empty here and pass values at init time so the same code
  # works across environments without hardcoding a state file location.
  #
  #   terraform init \
  #     -backend-config="resource_group_name=rg-tfstate" \
  #     -backend-config="storage_account_name=sttfstateunique001" \
  #     -backend-config="container_name=tfstate" \
  #     -backend-config="key=storage-account/dev.terraform.tfstate"
  #
  # For your very first local practice run, you can comment this whole
  # "backend" block out and Terraform will just use a local terraform.tfstate
  # file instead.
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}
